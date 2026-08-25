---
created_at: 2026-08-23T18:30:00+08:00
status: todo # done | todo
---

> 人下达task，你执行task并记录执行过程，人验收后记录验收看到的东西判断是否完成，你继续执行task，直到人认为结束了再手动修改status

# 说明

旧服务器（独立部署 https 成功）准备关闭，博客要迁移到朋友服务器。但朋友服务器上已有系统 nginx 占用 80/443，且跑着多个 57d02.cn 站点（bot/ddns/openlist/proxy/token 等，共用一套 acme.sh 管理的通配符证书），不能停。要求：与朋友 nginx **共存**，同时**不破坏项目原有的独立部署能力**。

# 方案（已与人确认）

- 共存架构：系统 nginx 是唯一 80/443 入口，TLS 由它终结；项目 nginx 容器退化为纯 http 内部服务，只监听 `127.0.0.1:COEXIST_HTTP_PORT`，由系统 nginx 反代
- 证书：与朋友一致用 **acme.sh**（webroot 方式）在宿主机申请 `sleeponthegrass.com` + `www.sleeponthegrass.com`，安装到 `/etc/ssl/acme/sleeponthegrass.com/`，续期后 `systemctl reload nginx`；项目内 certbot 容器在共存模式下不启动
- deploy.sh 接受参数区分模式，独立部署行为完全不变：
  - `./scripts/deploy.sh`（默认 standalone）：nginx 占用宿主 80/443，项目 certbot 自行管理 TLS
  - `./scripts/deploy.sh coexist`：只映射 `127.0.0.1:COEXIST_HTTP_PORT:80`，纯 http
- 端口不用 8080（服务器上已被占用），用 `COEXIST_HTTP_PORT`（默认 18080），deploy.sh 增加占用检查
- 项目 nginx 共存模式必须固定 http 模板，否则系统 nginx 反代过来会遇到 `301 https` 死循环

# 执行记录

### 2026-08-23 项目侧：实现共存模式（agent）

新增/修改文件：
- `docker-compose.yml`：nginx 端口映射移出到模式文件，只留公共配置（backend/db/certbot 不变）
- `docker-compose.standalone.yml`（新增）：独立模式端口 `80:80` `443:443`，与原来行为一致
- `docker-compose.coexist.yml`（新增）：`127.0.0.1:${COEXIST_HTTP_PORT}:80` + `NGINX_MODE=coexist` + `certbot scale: 0`
- `scripts/deploy.sh`：接受 `standalone|coexist` 参数；coexist 模式检查 `COEXIST_HTTP_PORT` 未被占用、跳过 CERTBOT_EMAIL 检查；按模式拼接 compose 文件
- `nginx/entrypoint.sh`：`NGINX_MODE=coexist` 时固定 `default.conf.http` 并 `exec nginx`（不轮询证书）
- `.env.example`：新增 `COEXIST_HTTP_PORT=18080`

本地验证：`bash -n` deploy.sh / entrypoint.sh 通过；`bash scripts/build.sh` 通过（frontend pnpm build + backend go build）

### 2026-08-23 服务器侧（人执行）

- 系统 nginx 新增 `/etc/nginx/sites-available/sleeponthegrass.com`：
  - 80 块：`location /.well-known/acme-challenge/ { root /var/www/acme-challenge; }` + 其余 301 到 https（**注意不能用 server 级 return 301**，会把 acme 验证也 301 走）
  - 443 块：`ssl_certificate` 指向 `/etc/ssl/acme/sleeponthegrass.com/`，反代 `127.0.0.1:18080`，带 Host/X-Real-IP/X-Forwarded-* 头
- acme.sh 申请证书成功：`sleeponthegrass.com` + `www.sleeponthegrass.com`（webroot `/var/www/acme-challenge`，CA Let's Encrypt）
- 坑 1：`--install-cert` 首次失败 `No such file or directory`——acme.sh 不会自动创建目标目录，`mkdir -p /etc/ssl/acme/sleeponthegrass.com` 后重试成功
- 坑 2：文章上传 `Permission denied`——`/home/weihu/blog` 是 root 创建，weihu 账号无写权限；`sudo chown -R weihu:weihu /home/weihu/blog` 解决（此前 ssh 命令还出现过 `weihu@@host` 双 @ 笔误导致认证失败）
- 部署：`./scripts/deploy.sh coexist`

# 待验证

1. `curl -I https://sleeponthegrass.com` 返回 200
2. `http://sleeponthegrass.com` 301 到 https
3. `/api/health` 正常
4. 上传的文章在页面正常展示
5. 朋友的 57d02.cn 各站点不受影响
6. 以后独立部署：`./scripts/deploy.sh`（不带参数）行为与原来一致
