# Gitee Release 同步上传进度不可见

## 背景

GitHub Actions 的 Gitee Release 镜像同步流程会先删除 Gitee 现有 Release，再按 GitHub Release 顺序重建 Release 和附件。

实际运行时，如果第一个 Release 的附件较大或 Gitee 上传速度较慢，旧脚本会在附件上传阶段使用 `curl --silent`，Action 日志只停留在“正在上传”之前，无法判断是仍在传输、网络卡住，还是已经停止。

## 原因

- 附件上传命令隐藏了 curl 进度输出。
- Python 日志没有统一强制刷新。
- 附件下载和上传缺少连接超时、低速中断和重试参数。
- 日志没有按 Release / 附件打印编号和文件大小，无法定位当前卡在哪个产物。

## 修复

- 每个 Release 打印 `Release x/y`，每个附件打印 `Asset x/y`、文件名和大小。
- 下载和上传都显示 curl 进度条，并在完成后打印完成状态。
- 附件传输增加重试、连接超时、总时长限制和低速中断保护。
- GitHub Actions 设置 `PYTHONUNBUFFERED=1`，避免日志缓冲导致进度延迟显示。

## 验证

- 通过 Python 语法检查。
- 通过 workflow YAML 解析检查。
- 通过 Git diff 空白检查。
