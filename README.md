# mitmproxy-service

[![Docker Hub](https://img.shields.io/docker/pulls/luckybill/multi-mitmproxy-service.svg)](https://hub.docker.com/r/luckybill/multi-mitmproxy-service)
[![Image](https://img.shields.io/badge/Docker-image-blue)](https://hub.docker.com/r/luckybill/multi-mitmproxy-service/tags)
[![CI](https://github.com/BillLucky/multi-mitmproxy-service/actions/workflows/docker.yml/badge.svg)](https://github.com/BillLucky/multi-mitmproxy-service/actions/workflows/docker.yml)
[![Repo](https://img.shields.io/badge/GitHub-BillLucky%2Fmulti--mitmproxy--service-black)](https://github.com/BillLucky/multi-mitmproxy-service)

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

### 使用已发布镜像（无需本地构建）
```bash
export IMAGE_REPO=luckybill/multi-mitmproxy-service
make up
```
- 或直接运行：
```bash
docker run -p 8080:48080 -p 8081:48081 \
  -e MITM_REVERSE_TARGET=http://host.docker.internal:11434 \
  -e MITM_WEB_PASSWORD=5555.5555 \
  luckybill/multi-mitmproxy-service:latest
```

### 快速指向
- Docker Hub：`https://hub.docker.com/r/luckybill/multi-mitmproxy-service`
- GitHub Repo：`https://github.com/BillLucky/multi-mitmproxy-service`

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
      "volumes": ["./mitmproxy-conf:/root/.mitmproxy:rw"],
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

### 高级示例（一次性定义多个端口）
```json
{
  "proxies": [
    {
      "name": "ollama",
      "target": "http://host.docker.internal:11434",
      "host_proxy_port": 48084,
      "host_web_port": 48085,
      "flow_log": "/app/logs/flows/ollama.flow",
      "web_log": "/app/logs/web/ollama.log",
      "env": { "STREAM_TO_STDOUT": "1" },
      "volumes": [
        "./captures:/app/logs:rw",
        "./mitmproxy-conf:/root/.mitmproxy:rw"
      ]
    },
    {
      "name": "apiA",
      "target": "http://host.docker.internal:9000",
      "host_proxy_port": 49080,
      "host_web_port": 49081,
      "flow_log": "/app/logs/flows/apiA.flow",
      "web_log": "/app/logs/web/apiA.log",
      "env": { "SSLKEYLOGFILE": "/app/logs/sslkeylog.txt", "STREAM_TO_STDOUT": "1" },
      "volumes": [
        "./captures:/app/logs:rw",
        "./mitmproxy-conf:/root/.mitmproxy:rw"
      ]
    }
  ]
}
```
```bash
make up
open http://localhost:48085/?token=<password>
open http://localhost:49081/?token=<password>
```

> 说明
- `flow_log`/`web_log`：按服务自定义日志文件路径（默认分别为 `/app/logs/log_<proxy>.flow` 与 `/app/logs/mitmweb_<proxy>.log`）
- `STREAM_TO_STDOUT=1`：同时将 `web_log` 与 `flow_log` 流式输出到容器标准输出，配合 `docker compose logs -f` 观察
- `./captures:/app/logs:rw`：统一挂载日志根目录到宿主机，保存所有服务的捕获内容

## 设计说明
- 生成器：`tools/gen_compose.py` 读取 `proxies.json`，生成 `docker-compose.generated.yml`
- Compose：基础文件 `docker-compose.yml` 仅包含通用锚点与空 `services`，具体服务全部来自生成文件
- 容器端口：所有容器内部统一使用 `48080/48081`，宿主映射端口由 `proxies.json` 决定
- 健康检查：每个容器对 `127.0.0.1:<web_port>` 进行 HTTP 检查，保证 UI 可达
- 日志：`driver=local`，`max-size=100m`，`max-file=3`，各服务单独目录

### 配置生效关系（优先级）
- 实际启动的服务与端口以 `docker-compose.generated.yml` 为准
- `docker-compose.yml` 的 `services: {}` 不启动任何服务，仅提供通用配置
- `.env` 文件不再参与服务端口配置（可用于你自定义环境，不影响生成器输出）
- 容器命名规则：`mitmproxy-reverse-to-<host_proxy_port>-web-<host_web_port>`
- Web UI 端口：`<host_web_port>`；代理端口：`<host_proxy_port>`

## 场景故事：为 AI/后端开发者打造的“端口观察哨”
- 问题：当你在本机调试 Ollama 的 `11434` 端口，或调用任意后端 API，常常需要同时“看见”请求与响应，以便迭代提示词、参数与返回内容。传统做法要么在代码埋日志，要么开抓包工具，既费力又不易分享上下文。
- 方案：用本项目为目标端口启动一个反向代理容器。代理端口对外提供稳定入口、Web UI 可视化流量，日志与 CA/配置可挂载到宿主机持久化。
- 收益：
  - 一键为多个端口生成“观测点”，代理复用容器内固定端口（48080/48081），宿主机端口自定义；
  - `mitmweb` 提供请求/响应体、Header、时间线等信息，帮助你快速洞察哪一步造成延迟或错误；
  - 挂载 `SSLKEYLOGFILE` 可配合 Wireshark 解密 TLS，定位更隐蔽的问题；
  - 文档与 Makefile 统一操作，团队共享镜像即可复用，无需每人手动构建。
- 示例：为 Ollama `11434` 启服务，宿主代理端口设为 `48084`，Web 端口 `48085`：
  - `proxies.json` 设置 `target=http://host.docker.internal:11434`，`host_proxy_port=48084`，`host_web_port=48085`
  - `make up` 后访问 `http://localhost:48084/` 与 `http://localhost:48085/?token=<密码>`，即可观察请求与响应

## Bilingual Overview（English）
- What: A configurable multi-port reverse proxy suite built on mitmproxy/mitmweb.
- Why: Give API/AI/backend developers a “port observatory” to visualize requests/responses while iterating prompts and parameters.
- How:
  - Define multiple targets in `proxies.json`, auto-generate services with isolated proxy/UI/log directories.
  - Web UI visualizes headers, bodies, and timelines. Mount logs/certs to persist context. Optional `SSLKEYLOGFILE` for TLS decryption (Wireshark).
- Quick Start:
```bash
docker run -p 8080:48080 -p 8081:48081 \
  -e MITM_REVERSE_TARGET=http://host.docker.internal:11434 \
  -e MITM_WEB_PASSWORD=yourpass \
  luckybill/multi-mitmproxy-service:latest
```
- Multiple Services:
```bash
export IMAGE_REPO=luckybill/multi-mitmproxy-service
make up
```
- Links:
  - Hub: https://hub.docker.com/r/luckybill/multi-mitmproxy-service
  - Repo: https://github.com/BillLucky/multi-mitmproxy-service

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
make dockerhub-build DOCKER_REPO=luckybill/multi-mitmproxy-service VERSION=1.0.0
make dockerhub-push  DOCKER_REPO=luckybill/multi-mitmproxy-service VERSION=1.0.0
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
- 标准输出日志：设置 `STREAM_TO_STDOUT=1` 后，容器会把 `web_log` 与 `flow_log` 同步到 stdout；查看 `make logs` 或 `docker compose logs -f`
- 日志滚动：默认每次启动为日志文件添加时间戳后缀，避免覆盖历史（可通过 `ROLL_ON_START=0` 禁用，使用固定文件名）

## CI/CD（GitHub Actions）
- 已提供工作流：`.github/workflows/docker.yml`
- 需要在仓库设置 Secrets：
  - `DOCKERHUB_USERNAME`：你的 Docker Hub 用户名
  - `DOCKERHUB_TOKEN`：你的 Docker Hub Access Token
  - `DOCKER_REPO`：`luckybill/multi-mitmproxy-service`
- 触发策略：
  - 对 `main/master` 推送：构建并推送 `latest`
  - 打标签 `vX.Y.Z`：构建并推送 `X.Y.Z` 版本标签
- 多架构：`linux/amd64, linux/arm64`
- 缓存：使用远端 registry 缓存加速重复构建
