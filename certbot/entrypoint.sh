#!/bin/sh
# certbot 容器入口：证书不存在则首次申请；之后每 12h 检查续期（仅剩 <=30 天时真正续期）。
# 证书写入 /etc/letsencrypt（volume certbot-etc），nginx 通过轮询自动 reload 加载。
set -e

DOMAINS="-d sleeponthegrass.com -d www.sleeponthegrass.com"
CERT_DIR="/etc/letsencrypt/live/sleeponthegrass.com"
WEBROOT="/var/www/certbot"
EMAIL="${CERTBOT_EMAIL:-}"

if [ -z "$EMAIL" ]; then
  echo "错误：未设置 CERTBOT_EMAIL（请在 .env 中配置，Let's Encrypt 用邮箱接收到期提醒）"
  exit 1
fi

# 等待 nginx 就绪（最多 60s），确保 80 端口能响应 acme-challenge
i=0
while [ "$i" -lt 30 ]; do
  code="$(wget -q -O /dev/null --server-response "http://nginx/.well-known/acme-challenge/ping" 2>&1 | grep "HTTP/" | tail -1 | awk '{print $2}')"
  case "$code" in
    200|404) break ;;
  esac
  i=$((i + 1))
  sleep 2
done
echo "certbot: nginx 就绪（HTTP $code）"

# 首次申请：证书目录不存在时执行
if [ ! -d "$CERT_DIR" ]; then
  echo "certbot: 首次申请证书 ..."
  certbot certonly --webroot -w "$WEBROOT" --email "$EMAIL" \
    --agree-tos --no-eff-email \
    $DOMAINS
fi

# 续期循环：每 12h 检查一次
while true; do
  echo "certbot: 检查续期 $(date)"
  certbot renew --quiet
  sleep 12h
done
