#!/usr/bin/env python3
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG_JSON = ROOT / "proxies.json"
OUTPUT_YML = ROOT / "docker-compose.generated.yml"

def load_config():
    if not CONFIG_JSON.exists():
        return {"proxies": []}
    with CONFIG_JSON.open("r", encoding="utf-8") as f:
        data = json.load(f)
    proxies = data.get("proxies", [])
    # basic validation
    for i, p in enumerate(proxies):
        for k in ("name", "target", "host_proxy_port", "host_web_port"):
            if k not in p:
                raise ValueError(f"proxies[{i}] missing '{k}'")
    return {"proxies": proxies}

def gen_service_block(p):
    name = str(p["name"]).strip()
    target = p["target"]
    hpp = int(p["host_proxy_port"])
    hwp = int(p["host_web_port"])
    web_password = p.get("web_password", "")

    flow_log = f"/app/logs/log_{hpp}.flow"
    web_log = f"/app/logs/mitmweb_{hpp}.log"
    vol_path = f"./mitmproxy-logs/{hpp}:/app/logs"
    container_name = f"mitmproxy-reverse-{hpp}"

    env_lines = [
        f"      - MITM_REVERSE_TARGET={target}",
        "      - MITM_PROXY_PORT=48080",
        "      - MITM_WEB_PORT=48081",
        f"      - MITM_FLOW_LOG={flow_log}",
        f"      - MITM_WEB_LOG={web_log}",
    ]
    if web_password:
        # escape '$' for docker compose variable substitution
        wp = web_password.replace("$", "$$")
        env_lines.append(f"      - MITM_WEB_PASSWORD={wp}")
    # extra env from config
    extra_env = p.get("env", {})
    if isinstance(extra_env, dict):
        for k, v in extra_env.items():
            env_lines.append(f"      - {k}={v}")

    block = []
    block.append(f"  mitmproxy-{name}:")
    block.append(f"    build: .")
    block.append(f"    container_name: {container_name}")
    block.append(f"    restart: always")
    block.append(f"    init: true")
    block.append(f"    ports:")
    block.append(f"      - \"{hpp}:48080\"")
    block.append(f"      - \"{hwp}:48081\"")
    block.append(f"    environment:")
    block.extend(env_lines)
    block.append(f"    volumes:")
    block.append(f"      - {vol_path}")
    # extra volumes from config
    extra_vols = p.get("volumes", [])
    if isinstance(extra_vols, list):
        for v in extra_vols:
            block.append(f"      - {v}")
    block.append(f"    logging:")
    block.append(f"      driver: \"local\"")
    block.append(f"      options:")
    block.append(f"        max-size: \"100m\"")
    block.append(f"        max-file: \"3\"")
    block.append(f"    healthcheck:")
    block.append(f"      test: [\"CMD\", \"python3\", \"-c\", \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:48081/', timeout=2)\"]")
    block.append(f"      interval: 10s")
    block.append(f"      timeout: 3s")
    block.append(f"      retries: 5")
    block.append(f"      start_period: 10s")
    return "\n".join(block)

def main():
    cfg = load_config()
    proxies = cfg["proxies"]
    if not proxies:
        OUTPUT_YML.write_text("services:\n", encoding="utf-8")
        return
    # detect duplicate host ports
    used = set()
    for p in proxies:
        pair = (int(p["host_proxy_port"]), int(p["host_web_port"]))
        if pair in used:
            raise ValueError(f"Duplicate host ports detected: {pair}")
        used.add(pair)
    parts = ["services:"]
    for p in proxies:
        parts.append(gen_service_block(p))
    OUTPUT_YML.write_text("\n".join(parts) + "\n", encoding="utf-8")

if __name__ == "__main__":
    main()
