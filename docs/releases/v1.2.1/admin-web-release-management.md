# v1.2.1 Admin Web 版本管理

## 版本事实

FrameLean server v1.0.0 内置 Admin Web。React + Vite + Ant Design 构建产物由 Spring Boot 托管在 `/web`，用于下载统计、检查更新审计、下载 IP 记录、IP 屏蔽和版本制品管理。

管理端首次打开需要用 `FRAMELEAN_API_KEY` 完成初始化，并设置唯一管理员主密码。主密码只在浏览器本地用于派生密钥、加密本地私钥和签名登录 challenge；服务端保存的是 Argon2id 参数、加密私钥信封和 ECDSA 公钥，不保存主密码或主密码哈希。

## 版本管理边界

- 管理端支持创建 draft release，一次拖拽上传 Windows x64、macOS Universal、版本日志 md 和可选 Windows 直装版留存包。
- 大文件上传通过服务端 COS 分片上传接口完成，前端只拿预签名 URL，不持有 COS 密钥。
- 草稿确认页展示基础信息、必填制品完成度、版本日志和架构支持标签。
- 发布动作只支持将草稿切换为 `published`；已发布版本的日志和制品不在页面内编辑。
- 删除登记版本会先删除该版本日志和所有登记 package 对应的 COS 对象，再删除下载事件、package、requirements 和 release 记录；如果 COS 删除失败，数据库记录保留，便于重试。

## 审计和风控边界

- 下载统计页展示总下载、检查更新、下载 IP、检查 IP 和当前封禁 IP。
- 检查更新和下载 ticket 创建都读取反代后的真实 IP，并写入审计记录。
- IP 屏蔽规则用于阻断检查更新和下载 ticket 创建；已签发但尚未过期的 COS 预签名 URL 仍受其自身过期时间约束。
- `/api/v1/admin/*` 同时支持脚本用 `X-Api-Key` 和 Admin Web Cookie 会话；Admin Web 的非 GET 请求需要 CSRF token。

## 验证范围

- Admin Web 登录初始化、challenge 签名登录、Cookie 会话和 CSRF。
- 创建草稿、分片上传、注册 package、保存日志、发布和删除登记版本。
- 版本删除时的 COS object key 安全校验、对象去重删除和数据库依赖行删除顺序。
- 下载统计、检查更新审计、下载审计和 IP 屏蔽分页查询。

