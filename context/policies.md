# Repository Policies

- 根 `LICENSE` 是 FrameLean 主许可证；上游组件许可证和第三方合规资料分别保留。
- `dependencies/` 只保存第三方源码、许可证与构建输入。
- `build/dependencies/` 只保存本地生成二进制和构建信息，并由根 `.gitignore` 忽略。
- `.workspace/` 是唯一根级本地资料目录，不跟踪、不打包、不由 CI 上传。
- 正式发布记录位于 `docs/releases/`；开发过程与技术变更位于 `changelog/`。
