---
created_at: 2026-08-17T18:20:32+08:00
status: todo # done | todo
---

> 人下达task，你执行task并记录执行过程，人验收后记录验收看到的东西判断是否完成，你继续执行task，直到人认为结束了再手动修改status

# 说明

目前是完成了 mvp，可以实现 http 域名访问了，但是我现在需要 https 的访问，要依靠 lets encrypto，应该是要修改 nginx/前端 这个容器？如何修改？而且感觉是要放在外部，要不然每次修改前端代码就重新申请一次也不合理

# 方案（已与人确认）

- 证书彻底从 nginx 镜像中剥离，存独立 named volume（certbot-etc / certbot-www）
- 新增第 4 个服务 certbot：证书不存在则首次 webroot 申请；之后每 12h `certbot renew`（仅剩 <=30 天才真正续期，90 天有效期约 60 天自动换新）
- nginx 启动时按证书是否存在选择 http/https 两套配置模板；后台每 60s 轮询证书文件 md5，首次出现或续期换新（内容变化）时切换模板并 `nginx -s reload`，新证书自动生效
- 因此「改前端 → 重建 nginx 镜像」完全不碰证书，不会重复申请；续期全自动无需人工
- 证书覆盖 sleeponthegrass.com 与 www.sleeponthegrass.com 两个域名
- 邮箱由人在服务器 .env 中配置 CERTBOT_EMAIL（不写死进仓库）

# 执行记录

### 2026-08-17 实现 https（certbot + nginx 轮询切换）

> 背景：首次部署时 https 失败，根因是 **www.sleeponthegrass.com 的 DNS 记录不存在**（nslookup 实测 NXDOMAIN），Let's Encrypt 无法验证 www 域名，连续失败 5 次触发 rate limit（封 1 小时到 11:27 UTC）。
> 教训：certbot 申请失败立即退出 → docker 快速重启 → 反复失败刷爆 rate limit 窗口。已改为失败后每 15 分钟重试（任意 1 小时窗口最多 4 次失败，不触发 5 次上限）。

新增文件：
- `certbot/Dockerfile`：基于官方 certbot/certbot 镜像，覆盖 entrypoint
- `certbot/entrypoint.sh`：
  1. 校验 CERTBOT_EMAIL 是否配置
  2. 等待 nginx 就绪（最多 60s，探测 /.well-known/acme-challenge/ 返回 200/404 即认为 nginx 在响应）
  3. 证书不存在时 `certbot certonly --webroot` 一次性申请两个域名；**失败不退出**，每 15 分钟重试（防刷爆 rate limit），成功后才进入续期循环
  4. 循环每 12h `certbot renew --quiet`
- `nginx/templates/default.conf.http`：无证书阶段的 80 配置 = 现状 + `/.well-known/acme-challenge/` 指向 /var/www/certbot
- `nginx/templates/default.conf.https`：有证书阶段；80 仅保留 acme-challenge + 其余 301 到 https；443 挂 ssl 证书、TLSv1.2/1.3、http2、静态托管、/api 反代
- `nginx/entrypoint.sh`：按证书 md5 有无选择 http/https 模板 → 后台启动 nginx → 每 60s 轮询证书 md5，变化则重新 apply 模板 + `nginx -s reload`；nginx master 意外退出则结束容器由 restart 拉起

修改文件：
- `nginx/Dockerfile`：不再 COPY 单一 default.conf 到 conf.d；改为 COPY `nginx/templates/` → `/etc/nginx/sites/` + `entrypoint.sh`；EXPOSE 80 443；ENTRYPOINT 接管（避开官方 /docker-entrypoint.d 的 envsubst，防止误替换 `$uri` 等 nginx 变量）
- `docker-compose.yml`：nginx 加 `443:443`，挂载 certbot-etc(:ro)/certbot-www；新增 certbot 服务（挂载同一两个 volume，CERTBOT_EMAIL 读 .env）；新增 volumes certbot-etc / certbot-www
- `.env.example`：新增 `CERTBOT_EMAIL=change_me@example.com`
- `scripts/deploy.sh`：.env 准备后新增 CERTBOT_EMAIL 检查——值缺失**或仍为占位符** `change_me@example.com` 时提示并退出（避免 certbot 拿无效邮箱去申请失败）

验证结果（本地）：
- `bash -n` 通过：nginx/entrypoint.sh、certbot/entrypoint.sh、scripts/deploy.sh
- `bash scripts/build.sh` 通过（frontend vite 构建成功 446ms，backend go build 无错误）
- docker-compose.yml YAML 语法校验通过（pyyaml），服务 nginx/certbot/backend/db，volumes pgdata/certbot-etc/certbot-www
- 本地无 docker，容器行为与首次 https 生效需在服务器验证

## 待人在服务器验证

1. `git pull` + `./scripts/deploy.sh`（确保 .env 已配置 CERTBOT_EMAIL）
2. 首次部署：nginx 先以 http 启动 → certbot 申请证书（约几十秒）→ nginx 约 1 分钟内轮询到证书自动切 https
3. 验证 `curl -I https://sleeponthegrass.com` 返回 200，`http://` 301 到 https，`/about` 正常，`/api/health` 正常
4. 之后可验证：改前端代码重新 deploy，证书不重新申请（certbot 容器日志无 certonly，nginx 直接 https）
