---
created_at: 2026-08-17T10:01:18+08:00
status: todo # done | todo
---

> 人下达task，你执行task并记录执行过程，人验收后记录验收看到的东西判断是否完成，你继续执行task，直到人认为结束了再手动修改status

# 说明

这是我的个人博客项目，我在windows上开发，但是部署到debian云服务器上

# 大概的技术栈与基本信息

ip地址： 66.245.220.13

domain： sleeponthegrass.com， A type @.sleeponthegrass.com 指向了服务器ip地址，CNAME type www.sleeponthegrass.com 指向了 sleeponthegrass.com

前端：vite + react + typescript + react-compiler（这样不用写 useCallback和 useMemo），自己写组件和页面，使用pnpm进行包管理

使用：Let’s Encrypt获得https

Nginx 部署编译好的前端

后端：使用gin+postgres（存储记录的访问数据而已）

使用docker编排容器

目前这个仓库上传到 github 公开仓库：https://github.com/anaouse/blog

只保留根部的 .gitignore

在服务器上我会在 `/home/blog` `git clone` 代码然后运行 `./scripts/deploy.sh`

# 开发流程

本地只能确保前后端编译通过，但是不运行，上传到github，服务器拉取后使用docker更新

# 具体规划细节

## 总体架构

浏览器 → Nginx(80/443) → 静态页面由 Nginx 托管；/api/* 反代到 backend；backend 访问 db

容器编排（docker compose）共 3 个服务：
- nginx：对外暴露 80/443，镜像内多阶段构建（node 编译前端 dist + nginx 托管），负责静态页面、/api 反代、SPA fallback、http→https 重定向
- backend：Gin，提供 /api 接口
- db：postgres:16，named volume（pgdata）持久化

## 仓库结构

blog/
├── frontend/              # vite + react + ts
│   ├── src/
│   │   ├── pages/Home.tsx
│   │   ├── pages/About.tsx
│   │   └── main.tsx
│   └── package.json
├── backend/
│   ├── main.go
│   └── Dockerfile
├── nginx/
│   ├── Dockerfile         # 多阶段：node 构建完毕后就丢掉， frontend → nginx 托管
│   └── default.conf
├── docker-compose.yml
├── deploy.sh              # 服务器更新脚本
├── .env.example
└── .gitignore

## 迭代流程（每次更新）

本地（Windows，只编译不运行）：
1. 改代码
2. 编译检查：frontend 执行 pnpm build（含 TS 类型检查），backend 执行 go build ./...
3. git add / commit / push

服务器（Debian）：
1. ssh 登录，cd 部署目录
2. git pull
3. ./deploy.sh，即 docker compose up -d --build
4. 浏览器验证

## MVP 大概规划

1. 服务器一次性准备
   - 安装 docker + compose 插件
   - 防火墙放行 80/443
   - dig 确认 DNS 解析生效

2. 仓库初始化：按上面的目录结构建好骨架，.gitignore 忽略 node_modules / dist / .env

3. 前端 MVP
   - vite 初始化 react-ts 项目，启用 react-compiler（免写 useCallback / useMemo）
   - 两个页面：/（hello world）、/about
   - 路由用 react-router-dom；Home 里调用后端 /api/hello 验证前后端打通

4. 后端 MVP
   - gin 最小服务：GET /api/hello 返回 JSON
   - GET /api/health 检查 db 连接（验证 postgres 编排完整）

5. nginx 配置
   - 托管前端 dist，location / 用 try_files fallback 到 index.html（SPA 刷新不 404）
   - 前端的 /api/ 发送到 nginx，反代到 backend:6713

6. docker-compose 编排
   - nginx / backend / db 三个服务
   - db 不映射端口到宿主机，仅容器网络内可达
   - pgdata named volume 持久化

7. HTTPS（Let's Encrypt）
   - certbot 容器 webroot 方式申请证书，证书写入 letsencrypt volume
   - nginx 挂载证书，开启 443 + 80→443 重定向
   - 配置自动续期（certbot renew + cron）

8. deploy.sh：git pull + docker compose up -d --build

## 执行记录

### 2026-08-17 第一步：build.sh 本地编译通过

初始状态：
- frontend：vite react-ts 模板，但 `src/App.tsx` 引用了不存在的 `./assets/*` 和 `./App.css`，TS 编译会失败
- backend：只有 go.mod / go.sum，无 `main.go`
- `.gitignore` 已存在（忽略 node_modules / dist / *.exe），符合"只保留根部"要求
本次改动：
- `frontend/src/App.tsx`：重写为最小 hello world（去掉对不存在资源的引用），暂不做页面/路由
- `backend/main.go`：新增 gin 最小服务，`GET /api/hello` 返回 JSON
- `scripts/build.sh`：新增，frontend 执行 `pnpm build`（含 tsc 类型检查），backend 执行 `go build ./...`

验证结果：`bash scripts/build.sh` 通过（frontend dist 构建成功 358ms，backend go build 无错误）。

### 2026-08-17 第二步：deploy.sh + docker 编排文件

新增文件：
- `scripts/deploy.sh`：服务器部署脚本
  1. 检查 docker 是否存在，没有则提示自行安装并退出（不代装）
  2. 检查 docker compose 插件，没有则提示并退出
  3. 检查 80/443 端口未被占用（优先 ss，回退 netstat），被占用则提示并退出
  4. 检查防火墙：ufw 若激活则确认已放行 80/443，未放行则提示并退出；无 ufw 则提示自行确认
  5. `.env` 不存在则从 `.env.example` 复制
  6. 确认是 git 仓库后 `git pull`
  7. `docker compose up -d --build`
- `docker-compose.yml`：nginx / backend / db 三个服务；db 不映射端口，pgdata named volume 持久化
- `nginx/Dockerfile`：多阶段（node:22 编译前端 dist → nginx:1.27-alpine 托管）
- `nginx/default.conf`：托管 dist，`location /` try_files SPA fallback，`location /api/` 反代到 `backend:8080`
- `backend/Dockerfile`：多阶段（golang:1.25-alpine 编译 → alpine 运行，非 root 用户）
- `.env.example`：POSTGRES_USER / POSTGRES_PASSWORD / POSTGRES_DB
- `.dockerignore`：排除 .git / node_modules / dist / .env，避免构建上下文过大

修改：
- `frontend/package.json`：加 `"packageManager": "pnpm@11.18.0"`，保证 docker 构建（corepack）与本地 pnpm 版本一致

说明：
- 反代目标用 `backend:6713`（后端端口为 6713）
- 本地无 docker，无法验证 docker build / compose 启动，需在服务器上跑 `./scripts/deploy.sh` 验证

关于"前端更新重建 nginx 镜像，https 是否会重复申请"的疑问：
- 不会。后续 HTTPS 步骤用 certbot 容器 webroot 方式申请证书，证书写入独立 named volume，不放进 nginx 镜像；重建 nginx 镜像只重新打包前端 dist + nginx 配置，证书不受影响
- 且证书按有效期（90 天）由 certbot renew 定时续期，与部署频率无关。本步骤暂不实现 https

验证结果（本地）：
- `bash -n scripts/deploy.sh` 通过
- `bash scripts/build.sh` 通过（package.json 改动不影响构建）
- `docker-compose.yml` YAML 语法校验通过

### 2026-08-17 第二步修正：后端端口统一为 6713

用户确认后端端口是 6713，修正：
- `backend/main.go`：`r.Run(":8080")` → `r.Run(":6713")`
- `nginx/default.conf`：`proxy_pass http://backend:8080` → `http://backend:6713`
- `backend/Dockerfile`：`EXPOSE 8080` → `EXPOSE 6713`
- 本文件执行记录同步更正

## MVP 验收与具体任务执行

### 写好基本的代码 

`./scripts/build.sh` 本地运行通过

### 写好 `./scripts/deploy.sh`

我要git clone 到服务器的 `/home/blog` 然后执行 `./scripts/deploy.sh`

我要：先识别是否有docker和compose，没有的话就提示要求先自己安装好，同时识别 443 和 80 端口是否开启，如果没有开启也提示然后退出，因为机器不同可能命令不同，所以不要自己安装

如果两个都有了那就开始搞docker了，这个我不太懂，nginx/前端 后端 postgres 3个对吧，要compose好，然后现在先不追求https，以及疑问是第一次肯定是安装镜像部署，那之后呢？前端更新，nginx/前端镜像新部署那https申请岂不是会重复？postgres这个问题还不大，因为还涉及不到。

最后我要的目标是访问 http://sleeponthegrass.com 成功显示 hello world 界面

- [ ] https://sleeponthegrass.com/about 显示 about 页面
- [ ] 直接访问 /about 刷新不 404（SPA fallback 生效）
- [ ] http://sleeponthegrass.com 自动跳转 https
- [ ] /api/hello 返回正常（前后端打通）
- [ ] docker compose down 后重新 up，pgdata 数据仍在（volume 持久化验证）
- [ ] 改一行代码重新部署后，数据库数据不丢
