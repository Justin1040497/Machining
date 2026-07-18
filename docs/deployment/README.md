# Deployment

桌面安装器、第三方运行时打包和 Backend 部署入口分别位于 `installer/`、`scripts/` 与 `backend/`。第三方生成二进制从 `build/dependencies/` 读取，不从 `dependencies/` 读取。
