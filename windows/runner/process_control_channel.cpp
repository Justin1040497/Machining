#include "process_control_channel.h"

#include <windows.h>
#include <tlhelp32.h>
#include <exdisp.h>
#include <shldisp.h>
#include <shlobj.h>

#include <cstdint>
#include <limits>
#include <memory>
#include <string>
#include <variant>
#include <vector>

#include <flutter/encodable_value.h>
#include <flutter/method_call.h>
#include <flutter/method_channel.h>
#include <flutter/method_result.h>
#include <flutter/standard_method_codec.h>

namespace {

struct ProcessControlResult {
  bool succeeded;
  std::string message;
};

bool ReadPid(const flutter::EncodableValue* arguments, DWORD* pid) {
  if (arguments == nullptr) {
    return false;
  }

  const auto* map = std::get_if<flutter::EncodableMap>(arguments);
  if (map == nullptr) {
    return false;
  }

  auto pid_it = map->find(flutter::EncodableValue("pid"));
  if (pid_it == map->end()) {
    return false;
  }

  const auto& value = pid_it->second;
  if (const auto* pid32 = std::get_if<int32_t>(&value)) {
    if (*pid32 <= 0) {
      return false;
    }
    *pid = static_cast<DWORD>(*pid32);
    return true;
  }

  if (const auto* pid64 = std::get_if<int64_t>(&value)) {
    if (*pid64 <= 0 ||
        *pid64 > static_cast<int64_t>(std::numeric_limits<DWORD>::max())) {
      return false;
    }
    *pid = static_cast<DWORD>(*pid64);
    return true;
  }

  return false;
}

ProcessControlResult SuspendOrResumeProcessThreads(DWORD pid, bool suspend) {
  HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
  if (snapshot == INVALID_HANDLE_VALUE) {
    return {false, "Unable to inspect process threads"};
  }

  THREADENTRY32 entry;
  entry.dwSize = sizeof(THREADENTRY32);

  bool found_thread = false;
  bool failed_thread = false;
  if (Thread32First(snapshot, &entry)) {
    do {
      if (entry.th32OwnerProcessID != pid) {
        continue;
      }

      found_thread = true;
      HANDLE thread =
          OpenThread(THREAD_SUSPEND_RESUME, FALSE, entry.th32ThreadID);
      if (thread == nullptr) {
        failed_thread = true;
        continue;
      }

      const DWORD result =
          suspend ? SuspendThread(thread) : ResumeThread(thread);
      if (result == static_cast<DWORD>(-1)) {
        failed_thread = true;
      }

      CloseHandle(thread);
    } while (Thread32Next(snapshot, &entry));
  }

  CloseHandle(snapshot);

  if (!found_thread) {
    return {false, "No threads found for FFmpeg process"};
  }

  if (failed_thread) {
    return {false, "One or more FFmpeg process threads could not be controlled"};
  }

  return {true, ""};
}

ProcessControlResult TerminateProcessByPid(DWORD pid) {
  HANDLE process = OpenProcess(PROCESS_TERMINATE, FALSE, pid);
  if (process == nullptr) {
    return {false, "Unable to open FFmpeg process for termination"};
  }

  const BOOL succeeded = TerminateProcess(process, 1);
  CloseHandle(process);

  if (!succeeded) {
    return {false, "Unable to terminate FFmpeg process"};
  }

  return {true, ""};
}

bool IsCurrentProcessElevated() {
  HANDLE token = nullptr;
  if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) {
    return false;
  }

  TOKEN_ELEVATION elevation;
  DWORD returned_size = 0;
  const BOOL succeeded =
      GetTokenInformation(token, TokenElevation, &elevation,
                          sizeof(elevation), &returned_size);
  CloseHandle(token);

  return succeeded && elevation.TokenIsElevated != 0;
}

std::wstring CurrentExecutablePath() {
  std::vector<wchar_t> buffer(MAX_PATH);

  while (true) {
    const DWORD length =
        GetModuleFileNameW(nullptr, buffer.data(),
                           static_cast<DWORD>(buffer.size()));
    if (length == 0) {
      return L"";
    }

    if (length < buffer.size() - 1) {
      return std::wstring(buffer.data(), length);
    }

    buffer.resize(buffer.size() * 2);
  }
}

HRESULT GetDesktopShellDispatch(IShellDispatch2** shell_dispatch) {
  if (shell_dispatch == nullptr) {
    return E_POINTER;
  }
  *shell_dispatch = nullptr;

  IShellWindows* shell_windows = nullptr;
  HRESULT result = CoCreateInstance(CLSID_ShellWindows, nullptr,
                                   CLSCTX_LOCAL_SERVER,
                                   IID_PPV_ARGS(&shell_windows));
  if (FAILED(result)) {
    return result;
  }

  VARIANT desktop;
  VARIANT empty;
  VariantInit(&desktop);
  VariantInit(&empty);
  desktop.vt = VT_I4;
  desktop.lVal = CSIDL_DESKTOP;

  long hwnd = 0;
  IDispatch* dispatch = nullptr;
  result = shell_windows->FindWindowSW(
      &desktop, &empty, SWC_DESKTOP, &hwnd, SWFO_NEEDDISPATCH, &dispatch);
  shell_windows->Release();
  if (FAILED(result)) {
    return result;
  }

  IServiceProvider* service_provider = nullptr;
  result = dispatch->QueryInterface(IID_PPV_ARGS(&service_provider));
  dispatch->Release();
  if (FAILED(result)) {
    return result;
  }

  IShellBrowser* browser = nullptr;
  result = service_provider->QueryService(SID_STopLevelBrowser,
                                          IID_PPV_ARGS(&browser));
  service_provider->Release();
  if (FAILED(result)) {
    return result;
  }

  IShellView* shell_view = nullptr;
  result = browser->QueryActiveShellView(&shell_view);
  browser->Release();
  if (FAILED(result)) {
    return result;
  }

  IDispatch* background_dispatch = nullptr;
  result = shell_view->GetItemObject(SVGIO_BACKGROUND,
                                     IID_PPV_ARGS(&background_dispatch));
  shell_view->Release();
  if (FAILED(result)) {
    return result;
  }

  IShellFolderViewDual* folder_view = nullptr;
  result = background_dispatch->QueryInterface(IID_PPV_ARGS(&folder_view));
  background_dispatch->Release();
  if (FAILED(result)) {
    return result;
  }

  IDispatch* application_dispatch = nullptr;
  result = folder_view->get_Application(&application_dispatch);
  folder_view->Release();
  if (FAILED(result)) {
    return result;
  }

  result = application_dispatch->QueryInterface(IID_PPV_ARGS(shell_dispatch));
  application_dispatch->Release();
  return result;
}

ProcessControlResult RestartCurrentProcessUnelevated() {
  const std::wstring executable_path = CurrentExecutablePath();
  if (executable_path.empty()) {
    return {false, "Unable to resolve current executable path"};
  }

  IShellDispatch2* shell_dispatch = nullptr;
  HRESULT result = GetDesktopShellDispatch(&shell_dispatch);
  if (FAILED(result)) {
    return {false, "Unable to access unelevated shell"};
  }

  BSTR file = SysAllocString(executable_path.c_str());
  if (file == nullptr) {
    shell_dispatch->Release();
    return {false, "Unable to allocate restart command"};
  }

  VARIANT empty;
  VARIANT operation;
  VARIANT show;
  VariantInit(&empty);
  VariantInit(&operation);
  VariantInit(&show);

  operation.vt = VT_BSTR;
  operation.bstrVal = SysAllocString(L"open");
  show.vt = VT_I4;
  show.lVal = SW_SHOWNORMAL;

  if (operation.bstrVal == nullptr) {
    SysFreeString(file);
    shell_dispatch->Release();
    return {false, "Unable to allocate restart operation"};
  }

  result = shell_dispatch->ShellExecute(file, empty, empty, operation, show);
  VariantClear(&operation);
  SysFreeString(file);
  shell_dispatch->Release();

  if (FAILED(result)) {
    return {false, "Unable to restart FrameLean in normal mode"};
  }

  return {true, ""};
}

void CompleteProcessControlCall(
    const ProcessControlResult& control_result,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (control_result.succeeded) {
    result->Success();
    return;
  }

  result->Error("process_control_failed", control_result.message);
}

}  // namespace

void RegisterProcessControlChannel(flutter::BinaryMessenger* messenger) {
  static std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel;
  channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "framelean/process_control",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const std::string& method = call.method_name();
        if (method == "isElevated") {
          result->Success(flutter::EncodableValue(IsCurrentProcessElevated()));
          return;
        }

        if (method == "restartUnelevated") {
          CompleteProcessControlCall(
              RestartCurrentProcessUnelevated(), std::move(result));
          return;
        }

        DWORD pid = 0;
        if (!ReadPid(call.arguments(), &pid)) {
          result->Error("invalid_arguments", "A positive pid argument is required");
          return;
        }

        if (method == "pause") {
          CompleteProcessControlCall(
              SuspendOrResumeProcessThreads(pid, true), std::move(result));
          return;
        }

        if (method == "resume") {
          CompleteProcessControlCall(
              SuspendOrResumeProcessThreads(pid, false), std::move(result));
          return;
        }

        if (method == "terminate") {
          CompleteProcessControlCall(
              TerminateProcessByPid(pid), std::move(result));
          return;
        }

        result->NotImplemented();
      });
}
