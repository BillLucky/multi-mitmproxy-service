# multi-mitmproxy-service / 多端口反向代理套件

## 中文（CN）
一个可配置的多端口反向代理套件，基于 mitmproxy/mitmweb。为后端/API/AI 开发者提供“端口观察哨”，可视化请求/响应、Header、时间线。

- 一次性定义多个反向代理目标（`proxies.json`），自动生成并启动多个容器
- 每个服务拥有独立代理端口 + Web UI + 日志目录，支持挂载证书与配置
- 支持明文或 Argon2 哈希密码；可挂载 `SSLKEYLOGFILE` 配合 Wireshark 解密 TLS

快速开始（单容器）：
```bash
docker run -p 8080:48080 -p 8081:48081 \
  -e MITM_REVERSE_TARGET=http://host.docker.internal:11434 \
  -e MITM_WEB_PASSWORD=yourpass \
  luckybill/multi-mitmproxy-service:latest
```

多服务（配合生成器）：
```bash
export IMAGE_REPO=luckybill/multi-mitmproxy-service
make up
```

典型场景：Ollama 11434 调试
```json
{
  "proxies": [
    { "name": "ollama", "target": "http://host.docker.internal:11434", "host_proxy_port": 48084, "host_web_port": 48085 }
  ]
}
```
访问：`http://localhost:48084/` 与 `http://localhost:48085/?token=<password>`

链接：
- Hub: https://hub.docker.com/r/luckybill/multi-mitmproxy-service
- Repo: https://github.com/BillLucky/multi-mitmproxy-service

---

## English (EN)
A configurable multi-port reverse proxy suite built on mitmproxy/mitmweb. It gives API/AI/backend developers a “port observatory” to visualize requests/responses, headers, and timelines.

- Define multiple reverse targets in `proxies.json`, auto-generate and run multiple services
- Each service has isolated proxy port + Web UI + log directory; mount certs/config easily
- Supports plaintext or Argon2 password; optionally mount `SSLKEYLOGFILE` for TLS decryption with Wireshark

Quick Start (single container):
```bash
docker run -p 8080:48080 -p 8081:48081 \
  -e MITM_REVERSE_TARGET=http://host.docker.internal:11434 \
  -e MITM_WEB_PASSWORD=yourpass \
  luckybill/multi-mitmproxy-service:latest
```

Multiple services (with generator):
```bash
export IMAGE_REPO=luckybill/multi-mitmproxy-service
make up
```

Typical use case: debugging Ollama 11434
```json
{
  "proxies": [
    { "name": "ollama", "target": "http://host.docker.internal:11434", "host_proxy_port": 48084, "host_web_port": 48085 }
  ]
}
```
Access: `http://localhost:48084/` and `http://localhost:48085/?token=<password>`

Links:
- Hub: https://hub.docker.com/r/luckybill/multi-mitmproxy-service
- Repo: https://github.com/BillLucky/multi-mitmproxy-service
