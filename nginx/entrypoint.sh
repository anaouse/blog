#!/bin/sh
# nginx 启动入口：根据证书是否存在选择 http/https 配置，
# 并轮询证书文件指纹，首次出现或续期换新时自动 reload 加载。
set -e

CERT_DIR="/etc/letsencrypt/live/sleeponthegrass.com"
SRC_DIR="/etc/nginx/sites"
DEST="/etc/nginx/conf.d/default.conf"

# 证书指纹：文件不存在则为空字符串
cert_md5() {
  if [ -f "$CERT_DIR/fullchain.pem" ]; then
    md5sum "$CERT_DIR/fullchain.pem" | awk '{print $1}'
  else
    echo ""
  fi
}

apply_config() {
  if [ -n "$(cert_md5)" ]; then
    cp "$SRC_DIR/default.conf.https" "$DEST"
    echo "certbot: 应用 https 配置"
  else
    cp "$SRC_DIR/default.conf.http" "$DEST"
    echo "certbot: 应用 http 配置（等待证书）"
  fi
}

apply_config

# 后台启动 nginx（daemon off 保持前台进程）
nginx -g "daemon off;" &
NGINX_PID=$!

last_md5="$(cert_md5)"

# 轮询证书变化：首次出现或内容变化（续期）时切换配置并 reload
while true; do
  sleep 60
  current="$(cert_md5)"
  if [ "$current" != "$last_md5" ]; then
    echo "certbot: 检测到证书变化，重新加载 nginx"
    last_md5="$current"
    apply_config
    nginx -s reload
  fi
  # nginx master 意外退出时结束容器，交由 restart 策略拉起
  if ! kill -0 "$NGINX_PID" 2>/dev/null; then
    echo "certbot: nginx 已退出，结束容器"
    exit 1
  fi
done
