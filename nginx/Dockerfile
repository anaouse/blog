# syntax=docker/dockerfile:1

# ---- stage 1: build frontend ----
FROM node:22-alpine AS frontend-build
WORKDIR /app
COPY frontend/package.json frontend/pnpm-lock.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile
COPY frontend/ ./
RUN pnpm build

# ---- stage 2: nginx ----
FROM nginx:1.27-alpine
COPY --from=frontend-build /app/dist /usr/share/nginx/html
# 证书相关：http/https 两套模板 + 轮询切换脚本
# 注意不用 /etc/nginx/templates/（官方 entrypoint 会 envsubst 误替换 $uri 等 nginx 变量）
COPY nginx/templates/ /etc/nginx/sites/
COPY nginx/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
EXPOSE 80 443
ENTRYPOINT ["/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
