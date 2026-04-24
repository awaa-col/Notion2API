# Notion2API

一个基于 Go 的 Notion AI OpenAI 兼容桥接服务，提供标准 API、WebUI 管理面、多账号池和本地 SQLite 持久化，方便本地部署、调试和统一接入。

## 功能概览

- OpenAI 兼容接口：`/v1/models`、`/v1/chat/completions`、`/v1/responses`
- 支持流式响应
- 支持多账号池、账号切换、登录态刷新
- 支持图片、PDF、CSV 等附件请求
- 自带 WebUI 管理面：`/admin`
- 使用 SQLite 持久化账号、会话和运行状态

## 快速开始

### 本地运行

```powershell
Set-Location 'E:\WorkSpace\sub2api\chatgpt_register\Nation2API'
& 'D:\Go\bin\go.exe' run .\cmd\notion2api --config .\config.example.json
```

### 本地构建

```powershell
Set-Location 'E:\WorkSpace\sub2api\chatgpt_register\Nation2API'
& 'D:\Go\bin\go.exe' build .\cmd\notion2api
```

### Windows 长期运行

建议先在项目根目录放一份你自己的 `config.json`，再用 `deploy/windows` 里的脚本管理：

```powershell
Set-Location 'E:\WorkSpace\sub2api\chatgpt_register\Nation2API'

# 单脚本入口
.\deploy\windows\notion2api.ps1 build
.\deploy\windows\notion2api.ps1 start -BuildIfMissing
.\deploy\windows\notion2api.ps1 status
.\deploy\windows\notion2api.ps1 stop
```

说明：

- 如果你更习惯双击或 `cmd`，也可以用 `deploy\windows\notion2api.cmd`
- 默认二进制路径是项目根目录下的 `notion2api.exe`
- 默认配置优先读取项目根目录的 `config.json`，不存在时回退到 `config.example.json`
- 运行状态文件写入 `runtime/notion2api.pid` 和 `runtime/notion2api.state.json`
- 日志写入 `runtime/logs/notion2api.stdout.log` 与 `runtime/logs/notion2api.stderr.log`
- WebUI 静态资源仍然从 `static/admin` 目录读取，部署时不要只复制 exe

## Docker 部署

先按实际环境修改 `config.docker.json`，再启动：

```bash
docker compose up -d --build
```

如果使用偏生产配置：

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

## 默认入口

- API：`http://127.0.0.1:8787/v1/*`
- Health：`http://127.0.0.1:8787/healthz`
- WebUI：`http://127.0.0.1:8787/admin`

## 配置说明

建议优先检查这些字段：

- `api_key`：OpenAI 兼容接口密钥
- `admin.password`：WebUI 登录密码
- `upstream_base_url`：上游站点地址
- `upstream_origin`：上游请求 `Origin`
- `accounts`：账号池配置
- `active_account`：默认激活账号
- `storage.sqlite_path`：SQLite 数据库路径

可直接参考：

- `config.example.json`
- `config.docker.json`

## 使用建议

- 首次启动后先访问 `/admin`，确认账号、配置和连通性是否正常
- 常规本地使用直接运行二进制或 `go run` 即可
- 需要容器化部署时优先使用 Docker Compose

## 开源协议

MIT License

## 致谢

本项目已在 [LINUX DO 社区](https://linux.do) 发布，感谢社区的支持与反馈。
