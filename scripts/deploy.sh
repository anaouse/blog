#!/usr/bin/env bash
# 服务器部署脚本：git pull + docker compose up -d --build
# 用法：在 git clone 的仓库根目录执行
#   ./scripts/deploy.sh             # 独立模式（默认）：nginx 占用宿主 80/443，项目 certbot 自行管理 TLS
#   ./scripts/deploy.sh coexist     # 共存模式：与服务器已有 nginx 共用，nginx 只监听 127.0.0.1:COEXIST_HTTP_PORT，TLS 由外部 nginx 终结
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MODE="${1:-standalone}"
case "$MODE" in
  standalone|coexist) ;;
  *)
    echo "错误：未知模式 $MODE"
    echo "用法：./scripts/deploy.sh [standalone|coexist]"
    echo "  standalone  独立模式（默认）：nginx 直接占用宿主 80/443，项目 certbot 自行申请/续期证书"
    echo "  coexist     共存模式：与服务器已有 nginx 共用 80/443，项目 nginx 只监听 127.0.0.1:COEXIST_HTTP_PORT（纯 http），TLS 由外部 nginx 终结"
    exit 1
    ;;
esac

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

check_port_free() {
  local port="$1"

  # 端口由 docker 容器发布时放行：docker compose up 会重建容器并接管端口
  # （直接用 docker 查询，不依赖 ss 需 root 才能识别进程名）
  if docker ps --format '{{.Names}}' --filter "publish=$port" 2>/dev/null | grep -q .; then
    echo "  端口 $port 由 docker 容器发布，将由 docker compose 接管，继续"
    return 0
  fi

  local out
  if command -v ss >/dev/null 2>&1; then
    out="$(ss -tlnp 2>/dev/null | grep -E "[:.]${port}[[:space:]]")" || return 0
  elif command -v netstat >/dev/null 2>&1; then
    out="$(netstat -tlnp 2>/dev/null | grep -E "[:.]${port}[[:space:]]")" || return 0
  else
    echo "  警告：未找到 ss 或 netstat，跳过端口占用检查"
    return 0
  fi

  echo "错误：端口 $port 已被其他进程占用，请先释放后再运行"
  return 1
}

echo "==> 准备 .env"
if [ ! -f .env ]; then
  cp .env.example .env
  echo "  已从 .env.example 创建 .env，请检查其中的 POSTGRES_PASSWORD 和 CERTBOT_EMAIL"
fi

COMPOSE_FILES="-f docker-compose.yml"

if [ "$MODE" = "standalone" ]; then
  COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.standalone.yml"

  echo "==> 检查端口 80 / 443"
  for p in 80 443; do
    if check_port_free "$p"; then
      echo "  端口 $p 未被占用"
    else
      exit 1
    fi
  done

  echo "==> 检查 CERTBOT_EMAIL"
  if ! grep -q "^CERTBOT_EMAIL=." .env || grep -q "^CERTBOT_EMAIL=change_me@example.com" .env; then
    echo "错误：.env 未配置 CERTBOT_EMAIL 或仍为占位符（Let's Encrypt 需要真实邮箱接收到期提醒）"
    echo "      请在 .env 中修改：CERTBOT_EMAIL=your_email@example.com"
    exit 1
  fi
else
  COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.coexist.yml"

  echo "==> 检查共存模式端口 COEXIST_HTTP_PORT"
  if ! grep -q "^COEXIST_HTTP_PORT=." .env; then
    echo "错误：.env 未配置 COEXIST_HTTP_PORT（共存模式下 nginx 需要监听一个未被占用的本机端口）"
    echo "      请在 .env 中设置，例如：COEXIST_HTTP_PORT=18080"
    exit 1
  fi
  COEXIST_PORT="$(grep "^COEXIST_HTTP_PORT=" .env | cut -d= -f2)"
  if check_port_free "$COEXIST_PORT"; then
    echo "  端口 $COEXIST_PORT 未被占用"
  else
    echo "      提示：可在 .env 中换一个 COEXIST_HTTP_PORT 后重试"
    exit 1
  fi
fi

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

echo "==> 检查 git 仓库并拉取最新代码"
if [ ! -d .git ]; then
  echo "错误：当前目录不是 git 仓库，请先 git clone 本仓库"
  exit 1
fi
git pull

echo "==> 构建并启动容器（模式：$MODE）"
docker compose $COMPOSE_FILES up -d --build

echo "==> 部署完成"
if [ "$MODE" = "standalone" ]; then
  echo "    验证：curl -I http://sleeponthegrass.com"
  echo "    查看状态：docker compose $COMPOSE_FILES ps"
  echo "    查看日志：docker compose $COMPOSE_FILES logs -f"
else
  echo "    共存模式：请确认外部 nginx 已把 sleeponthegrass.com 反代到 127.0.0.1:$COEXIST_PORT"
  echo "    验证：curl -I http://127.0.0.1:$COEXIST_PORT（应返回 200）"
  echo "    查看状态：docker compose $COMPOSE_FILES ps"
  echo "    查看日志：docker compose $COMPOSE_FILES logs -f"
fi
