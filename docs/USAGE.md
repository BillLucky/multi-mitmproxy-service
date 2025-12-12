# 使用说明

## 一、配置多代理
1. 打开 `proxies.json`，按需添加多个条目（见 README 示例）
2. 端口必须唯一；每个条目一个独立日志目录与容器名
3. 如需保护 Web UI，设置 `web_password`，推荐使用 Argon2 哈希
4. 如需挂载额外目录或文件，使用 `volumes` 字段；如需注入环境变量，使用 `env` 字段

## 二、生成与启动
```bash
make up          # 生成并启动
make restart     # 生成、重建并启动
make ps          # 查看状态
make logs        # 跟随日志
make down        # 停止并删除

# 使用发布镜像而非本地构建
export IMAGE_REPO=billlucky/multi-mitmproxy-service
make up

# 直接运行单容器
docker run -p 8080:48080 -p 8081:48081 \
  -e MITM_REVERSE_TARGET=http://host.docker.internal:11434 \
  -e MITM_WEB_PASSWORD=5555.5555 \
  luckybill/multi-mitmproxy-service:latest

# 典型示例：两个服务
cat > proxies.json <<'JSON'
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
      "volumes": ["./captures:/app/logs:rw", "./mitmproxy-conf:/root/.mitmproxy:rw"]
    },
    {
      "name": "apiA",
      "target": "http://host.docker.internal:9000",
      "host_proxy_port": 49080,
      "host_web_port": 49081,
      "flow_log": "/app/logs/flows/apiA.flow",
      "web_log": "/app/logs/web/apiA.log",
      "env": { "SSLKEYLOGFILE": "/app/logs/sslkeylog.txt", "STREAM_TO_STDOUT": "1" },
      "volumes": ["./captures:/app/logs:rw", "./mitmproxy-conf:/root/.mitmproxy:rw"]
    }
  ]
}
JSON
make up
open http://localhost:48085/?token=<password>
open http://localhost:49081/?token=<password>
```

## 三、访问方式
- 代理地址：`http://localhost:<host_proxy_port>/`
- Web UI：`http://localhost:<host_web_port>/`
- 首次登录：
  - 直接访问 `http://localhost:<host_web_port>/?token=<web_password>`
  - 或在请求头加入 `Authorization: Bearer <web_password>`

## 四、目录结构
- `docker-compose.yml`：基础 Compose（通用设置）
- `docker-compose.generated.yml`：生成的服务清单（勿手改）
- `tools/gen_compose.py`：生成器脚本
- `proxies.json`：你的多服务配置
- `mitmproxy-logs/<port>/`：各服务日志目录
 - `mitmproxy-conf/`：示例的证书与配置目录（需要你自行创建）

## 配置优先级与来源
- 真实启动的服务与端口以 `docker-compose.generated.yml` 为准
- 基础 `docker-compose.yml` 不包含具体服务（`services: {}`）
- `.env` 不参与服务端口配置；所有端口与目标地址以 `proxies.json` 为唯一真相源
- 容器命名：`mitmproxy-reverse-<host_proxy_port>`
- 容器命名：`mitmproxy-reverse-to-<host_proxy_port>-web-<host_web_port>`
- 健康检查：对 Web 端口发起 HTTP 请求，403/405 不视为失败（表示 UI 需要认证，但服务可达）

## 链接与指引
- Docker Hub：`https://hub.docker.com/r/luckybill/multi-mitmproxy-service`
- GitHub Repo：`https://github.com/BillLucky/multi-mitmproxy-service`

## 日志捕获与查看
- 每个服务默认写入：`/app/logs/log_<proxy>.flow`（HTTP flows）与 `/app/logs/mitmweb_<proxy>.log`（mitmweb 输出）
- 可通过 `flow_log`/`web_log` 自定义路径，并统一挂载到宿主 `./captures:/app/logs:rw`
- 标准输出：在 `env` 中设置 `"STREAM_TO_STDOUT": "1"`，容器会把 `web_log` 与 `flow_log` 同步打印到 stdout
- 日志滚动：默认每次启动为日志文件添加时间戳后缀，避免覆盖历史；如需使用固定文件名，设置 `ROLL_ON_START=0`
- 内存优化：`STREAM_LARGE_BODIES`（默认 `1m`）启用流式传递避免保留大体；`BODY_SIZE_LIMIT` 控制最大请求/响应体积
 - 纯录制模式：设置 `"MITM_UI_ENABLED": "0"` 使用后端无 UI 模式（`mitmdump`），降低内存与资源占用
- 查看命令：
```bash
make logs                      # 跟随所有容器日志（stdout）
tail -f captures/web/ollama.log captures/flows/ollama.flow
```

## Bilingual Overview（English）
- Quick Start:
```bash
docker run -p 8080:48080 -p 8081:48081 \
  -e MITM_REVERSE_TARGET=http://host.docker.internal:11434 \
  -e MITM_WEB_PASSWORD=yourpass \
  luckybill/multi-mitmproxy-service:latest
```
- Multiple services:
```bash
export IMAGE_REPO=luckybill/multi-mitmproxy-service
make up
```
- Links:
  - Hub: https://hub.docker.com/r/luckybill/multi-mitmproxy-service
  - Repo: https://github.com/BillLucky/multi-mitmproxy-service

## 五、构建与缓存
- 构建使用 BuildKit 特性缓存 pip 包
- 如 Docker Desktop 已启用 BuildKit，重复构建会显著加速
- 若你启用了国内镜像源，可通过环境变量覆盖 `PIP_INDEX_URL`

## 六、故障排查
- 端口占用：`lsof -iTCP:<port> -sTCP:LISTEN -n -P`
- 健康状态：`make ps`，等待 `(healthy)` 状态
- UI 403：确认是否使用了 `/?token=<password>` 或 Authorization 头
- 反向目标不可达：用宿主机验证 `curl -v http://host.docker.internal:<target_port>/`。若返回 `Empty reply` 或连接失败，请检查目标服务是否在宿主机监听。

## 七、挂载示例
- 挂载证书与配置：
  - 在宿主创建 `mitmproxy-conf/`，将 CA 或配置文件置于其中
  - 在 `proxies.json` 对应条目的 `volumes` 添加：`"./mitmproxy-conf:/root/.mitmproxy:rw"`
  - 说明：mitmproxy 会写入 CA 与私钥文件到 `~/.mitmproxy`，因此建议 `rw`；如需 `ro`，必须预先完整放置所需文件。
- 挂载脚本或资源文件：
  - `volumes`: `["./scripts/flow.py:/app/flow.py:ro"]`
  - 结合 `env`: `{"MITM_EXTRA_SCRIPT": "/app/flow.py"}`，并在 Dockerfile 或启动命令中消费该变量
- 环境变量常见项：
  - `SSLKEYLOGFILE=/app/logs/sslkeylog.txt` 用于导出 TLS Key 以便 Wireshark 解密
  - `HTTP_PROXY` / `HTTPS_PROXY` / `NO_PROXY` 以控制容器的外部访问

## 八、推送到 Docker Hub
```bash
make dockerhub-login
make dockerhub-build DOCKER_REPO=yourname/mitmproxy-service
make dockerhub-push  DOCKER_REPO=yourname/mitmproxy-service
```
说明：
- 以上构建使用顶层 `Dockerfile`，与 Compose 无关
- 你也可以在 CI 中执行同样命令推送公共镜像
