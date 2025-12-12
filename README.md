# mitmproxy-service

一个可配置的多端口反向代理套件，基于 mitmproxy/mitmweb，支持：
- 通过 `proxies.json` 一次性定义多个反向代理目标
- 自动生成并启动对应容器，端口与日志独立
- 健康检查、日志滚动、快速重启与查看
- 可选 Web UI 密码（支持明文或 Argon2 哈希）
- 启用 Docker BuildKit 的 pip 缓存快速构建

## 快速开始
```bash
make up        # 生成 docker-compose.generated.yml 并启动
make ps        # 查看容器状态
make logs      # 跟随日志
make restart   # 变更后重建并启动
make down      # 停止并删除容器
```

访问：
- 代理端口：见 `proxies.json` 的 `host_proxy_port`
- Web UI：见 `proxies.json` 的 `host_web_port`
- 若配置了 `web_password`，可用 `http://localhost:<web_port>/?token=<web_password>` 首次登录

## 配置多个代理
编辑 `proxies.json`：
```json
{
  "proxies": [
    {
      "name": "11434",
      "target": "http://host.docker.internal:11434",
      "host_proxy_port": 48084,
      "host_web_port": 48085,
      "web_password": "$argon2id$v=19$m=4096,t=3,p=1$UJkTjY9A73NJo7QdAeSJhQ$iqqkhTvomJhA/IO33n4P/a9BLS548QaxTj4mTbBEshE",
      "volumes": ["./mitmproxy-conf:/root/.mitmproxy:ro"],
      "env": { "SSLKEYLOGFILE": "/app/logs/sslkeylog.txt" }
    },
    {
      "name": "11435",
      "target": "http://host.docker.internal:11435",
      "host_proxy_port": 48082,
      "host_web_port": 48083
    }
  ]
}
```
- `name`：用于服务名区分与容器命名
- `target`：反向代理目标（宿主端口可用 `host.docker.internal:<port>`）
- `host_proxy_port`：宿主机暴露的 HTTP(S) 代理端口（容器内固定使用 `48080`）
- `host_web_port`：宿主机暴露的 Web UI 端口（容器内固定使用 `48081`）
- `web_password`：可选，支持明文或 Argon2 哈希。首次登录可直接访问 `/?token=<password>`
- `volumes`：可选，挂载额外目录或文件。示例将宿主机 `./mitmproxy-conf` 挂载为容器内 `~/.mitmproxy`，以加载自定义证书与配置。
- `env`：可选，额外环境变量。例如 `SSLKEYLOGFILE` 输出 TLS 密钥日志，便于 Wireshark 解密。

修改完成后执行：
```bash
make up
```

## 设计说明
- 生成器：`tools/gen_compose.py` 读取 `proxies.json`，生成 `docker-compose.generated.yml`
- Compose：基础文件 `docker-compose.yml` 仅包含通用锚点与空 `services`，具体服务放在生成文件
- 容器端口：所有容器内部统一使用 `48080/48081`，宿主映射端口由 `proxies.json` 决定
- 健康检查：每个容器对 `127.0.0.1:<web_port>` 进行 HTTP 检查，保证 UI 可达
- 日志：`driver=local`，`max-size=100m`，`max-file=3`，各服务单独目录

## Web UI 密码
- 明文：`"web_password": "yourpass"`
- Argon2 哈希：`"web_password": "$argon2id$...."`
  - 生成方式：`make hash PASSWORD=yourpass`（返回哈希，直接粘贴进 `proxies.json`）
  - 说明：生成器自动转义 `$`，避免 Compose 变量展开破坏哈希
- 登录方式：
  - 浏览器直接访问：`http://localhost:<web_port>/?token=<web_password>`
  - 或添加请求头：`Authorization: Bearer <web_password>`

## 构建加速
- Dockerfile 顶部使用 `# syntax=docker/dockerfile:1.7-labs`
- pip 下载缓存通过 BuildKit `RUN --mount=type=cache,target=/root/.cache/pip` 持久化
- 只要 Dockerfile 与依赖版本不变，重复构建会跳过下载阶段
- 如需手动启用 BuildKit：`export DOCKER_BUILDKIT=1`

## 常用命令
```bash
make generate   # 仅生成 compose 文件
make up         # 生成 + 启动
make restart    # 生成 + 重建 + 启动
make ps         # 查看
make logs       # 跟随日志
make down       # 停止
make clean      # 清理生成的 compose 文件
make hash PASSWORD=yourpass   # 生成 Argon2 哈希

# 推送到 Docker Hub
make dockerhub-login
make dockerhub-build DOCKER_REPO=yourname/mitmproxy-service VERSION=1.0.0
make dockerhub-push  DOCKER_REPO=yourname/mitmproxy-service VERSION=1.0.0
```

## 约束与提示
- 端口不可重复：生成器会检查 `host_proxy_port` 与 `host_web_port` 重复并报错
- 如你本机已有进程占用某端口，请调整 `proxies.json` 中对应端口避免冲突
- 首次登录建议用 `/?token=` 方式自动建立会话，后续靠 Cookie 维持

## 挂载与文件说明
- 自定义证书与配置：在宿主机创建 `./mitmproxy-conf`，生成器示例将其挂载到容器内 `~/.mitmproxy`，mitmproxy 会自动读取。
- 日志目录：每个服务自动挂载 `./mitmproxy-logs/<proxy_port>:/app/logs`，滚动策略为 `100m * 3`。
- 挂载单个文件：可在 `volumes` 中写入 `"./path/to/file:/container/path:ro"`；适合注入脚本或额外资源。
- 环境变量扩展：通过 `env` 字段注入，例如启用 `SSLKEYLOGFILE` 或调整 `PIP_INDEX_URL`、`HTTP_PROXY` 等。

## CI/CD（GitHub Actions）
- 已提供工作流：`.github/workflows/docker.yml`
- 需要在仓库设置 Secrets：
  - `DOCKERHUB_USERNAME`：你的 Docker Hub 用户名
  - `DOCKERHUB_TOKEN`：你的 Docker Hub Access Token
  - `DOCKER_REPO`：`yourname/mitmproxy-service`
- 触发策略：
  - 对 `main/master` 推送：构建并推送 `latest`
  - 打标签 `vX.Y.Z`：构建并推送 `X.Y.Z` 版本标签
- 多架构：`linux/amd64, linux/arm64`
- 缓存：使用远端 registry 缓存加速重复构建
