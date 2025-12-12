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

## 五、构建与缓存
- 构建使用 BuildKit 特性缓存 pip 包
- 如 Docker Desktop 已启用 BuildKit，重复构建会显著加速
- 若你启用了国内镜像源，可通过环境变量覆盖 `PIP_INDEX_URL`

## 六、故障排查
- 端口占用：`lsof -iTCP:<port> -sTCP:LISTEN -n -P`
- 健康状态：`make ps`，等待 `(healthy)` 状态
- UI 403：确认是否使用了 `/?token=<password>` 或 Authorization 头

## 七、挂载示例
- 挂载证书与配置：
  - 在宿主创建 `mitmproxy-conf/`，将 CA 或配置文件置于其中
  - 在 `proxies.json` 对应条目的 `volumes` 添加：`"./mitmproxy-conf:/root/.mitmproxy:ro"`
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
