#include "process_control_channel.h"

#include <windows.h>
#include <tlhelp32.h>

#include <cstdint>
#include <limits>
#include <memory>
#include <string>
#include <variant>

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
        DWORD pid = 0;
        if (!ReadPid(call.arguments(), &pid)) {
          result->Error("invalid_arguments", "A positive pid argument is required");
          return;
        }

        const std::string& method = call.method_name();
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
