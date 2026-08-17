#!/usr/bin/env bash
# 服务器部署脚本：git pull + docker compose up -d --build
# 用法：在 git clone 的仓库根目录执行 ./scripts/deploy.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> 检查 docker"
if ! command -v docker >/dev/null 2>&1; then
  echo "错误：未检测到 docker，请先在服务器上自行安装 docker（不同系统安装方式不同，脚本不代为安装）"
  exit 1
fi

echo "==> 检查 docker compose 插件"
if ! docker compose version >/dev/null 2>&1; then
  echo "错误：未检测到 docker compose 插件，请先自行安装 docker compose 插件"
  exit 1
fi

echo "==> 检查端口 80 / 443"

check_port_free() {
  local port="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -tln | grep -qE "[:.]${port}[[:space:]]" && return 1 || return 0
  elif command -v netstat >/dev/null 2>&1; then
    netstat -tln | grep -qE "[:.]${port}[[:space:]]" && return 1 || return 0
  else
    echo "  警告：未找到 ss 或 netstat，跳过端口占用检查"
    return 0
  fi
}

for p in 80 443; do
  if check_port_free "$p"; then
    echo "  端口 $p 未被占用"
  else
    echo "错误：端口 $p 已被其他进程占用，请先释放后再运行"
    exit 1
  fi
done

echo "==> 检查防火墙是否放行 80 / 443"
if command -v ufw >/dev/null 2>&1; then
  if ufw status | grep -q "Status: active"; then
    for p in 80 443; do
      if ufw status | grep -E "^${p}/tcp" | grep -q "ALLOW"; then
        echo "  ufw 已放行 $p/tcp"
      else
        echo "错误：ufw 防火墙未放行 $p/tcp，请先执行：sudo ufw allow $p/tcp"
        exit 1
      fi
    done
  else
    echo "  ufw 未激活，跳过防火墙检查"
  fi
else
  echo "  未检测到 ufw（可能使用 iptables/nftables 等其他防火墙），请自行确认 80/443 已放行"
fi

echo "==> 准备 .env"
if [ ! -f .env ]; then
  cp .env.example .env
  echo "  已从 .env.example 创建 .env，请检查其中的 POSTGRES_PASSWORD"
fi

echo "==> 检查 git 仓库并拉取最新代码"
if [ ! -d .git ]; then
  echo "错误：当前目录不是 git 仓库，请先 git clone 本仓库"
  exit 1
fi
git pull

echo "==> 构建并启动容器"
docker compose up -d --build

echo "==> 部署完成"
echo "    验证：curl -I http://sleeponthegrass.com"
echo "    查看状态：docker compose ps"
echo "    查看日志：docker compose logs -f"
