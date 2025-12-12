# 基础镜像：选择与mitmproxy兼容的Python版本（3.12+）
ARG VERSION=dev
ARG VCS_REF=unknown
ARG BUILD_DATE=unknown
FROM python:3.12-slim

# 维护者信息（可选）
LABEL org.opencontainers.image.title="mitmproxy-service" \
      org.opencontainers.image.description="Config-driven multi-port reverse proxy with mitmproxy/mitmweb" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.source="https://github.com/yourname/mitmproxy-service" \
      maintainer="your-name <your-email>"

# 设置工作目录
WORKDIR /app

# 安装mitmproxy（指定版本更稳定，推荐最新版），使用层缓存加速
RUN pip install mitmproxy==12.2.1

# 创建日志目录（避免权限问题）
RUN mkdir -p /app/logs && chmod 777 /app/logs

# 环境变量默认值（可被docker-compose覆盖）
ENV MITM_REVERSE_TARGET="http://127.0.0.1:11434" \
    MITM_PROXY_PORT=48080 \
    MITM_WEB_PORT=48081 \
    MITM_FLOW_LOG="/app/logs/log_48080.flow"

RUN echo '#!/bin/sh' > /app/start.sh && \
    echo 'ARGS="--mode reverse:${MITM_REVERSE_TARGET} -p ${MITM_PROXY_PORT} --web-port ${MITM_WEB_PORT} -w ${MITM_FLOW_LOG} --set web_host=0.0.0.0 --set listen_host=0.0.0.0 --set block_global=false --quiet"' >> /app/start.sh && \
    echo 'if [ -n "${MITM_WEB_PASSWORD}" ]; then ARGS="$ARGS --set web_password=${MITM_WEB_PASSWORD}"; fi' >> /app/start.sh && \
    echo 'exec mitmweb $ARGS' >> /app/start.sh && \
    chmod +x /app/start.sh

# 暴露端口（代理端口 + Web界面端口）
EXPOSE ${MITM_PROXY_PORT} ${MITM_WEB_PORT}

# 启动命令：前台运行mitmweb（容器主进程）
CMD ["/app/start.sh"]
