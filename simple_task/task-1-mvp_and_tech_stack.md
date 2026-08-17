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

## 仓库初代版本的结构

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

## mvp 的迭代流程（每次更新）

本地（Windows，只编译不运行）：
1. 改代码
2. 编译检查：frontend 执行 pnpm build（含 TS 类型检查），backend 执行 go build ./...
3. git add / commit / push

服务器（Debian）：
1. ssh 登录，cd 部署目录
2. git pull
3. ./deploy.sh，即 docker compose up -d --build
4. 浏览器验证

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

### 2026-08-17 第三步：确认开发流程顺畅（about 页面 + /api/health）

用户已删除前端 `index.css`，但 `main.tsx` 仍引用它会导致编译失败，本次一并修复。

本次改动：
- 前端：`pnpm add react-router-dom`（7.18.2）
  - 新建 `src/pages/Home.tsx`：`/` 显示 hello world
  - 新建 `src/pages/About.tsx`：`/about` 简单界面
  - `src/App.tsx`：改为 BrowserRouter + Routes（`/` → Home，`/about` → About）
  - `src/main.tsx`：移除对已删除的 `index.css` 的引用
- 后端 `main.go`：新增 `GET /api/health` 返回 `{"status":"ok"}`（暂不查 db，postgres 还没涉及；MVP 规划中 health 设计为检查 db 连接，等用到 postgres 时再升级）

验证结果：`bash scripts/build.sh` 通过（frontend 27 modules 构建成功，backend go build 无错误）。

SPA fallback（刷新不 404）由 nginx `try_files` 配置保证，部署后需在服务器验证 `/about` 直接访问。

### 2026-08-17 第三步修正：deploy.sh 端口检查放行 docker 容器占用

问题：服务器上旧版 nginx 容器（docker-proxy）占用 80 端口，deploy.sh 误判为"其他进程占用"而退出。

修改 `scripts/deploy.sh` 的 `check_port_free`：
- 占用进程为 docker-proxy（docker 容器）时放行，提示"将由 docker compose 接管"并继续
- 其他进程占用时才报错退出
- 报错提示补充：若端口由本项目 docker 容器占用，需以 root 运行脚本（ss 需 root 才能识别进程名）

验证：`bash -n scripts/deploy.sh` 通过。服务器上需先 `git pull` 拿到新版 deploy.sh 再执行。

### 2026-08-17 第四步：后端编译过慢优化

问题：服务器部署时 `go build` 耗时 170.6s，且每次部署（哪怕只改一行 Go 代码）都全量重编译。

原因：
- 首次要编译 gin 全部依赖（sonic、quic-go、validator 等），VPS CPU 核数少，纯 CPU 密集
- Docker 每次构建环境全新，Go 编译缓存（GOCACHE）不持久化，导致每次部署都重编译所有依赖

修改：
- `backend/Dockerfile`：`go build` 加 `--mount=type=cache,target=/root/.cache/go-build`，用 BuildKit 缓存持久化 Go 编译缓存；之后只重编译改动的包，未改动依赖命中缓存（首次部署仍慢，之后秒级）
- `.dockerignore`：加 `*.exe`，排除本地 `go build` 产物 backend.exe，减小构建上下文

注意：cache mount 依赖 BuildKit（Docker 23+ 默认启用，`docker compose build` 即用），服务器 docker 版本应支持。

## MVP 验收与具体任务执行

### 写好基本的代码 

`./scripts/build.sh` 本地运行通过

### 写好 `./scripts/deploy.sh`

我要git clone 到服务器的 `/home/blog` 然后执行 `./scripts/deploy.sh`

我要：先识别是否有docker和compose，没有的话就提示要求先自己安装好，同时识别 443 和 80 端口是否开启，如果没有开启也提示然后退出，因为机器不同可能命令不同，所以不要自己安装

如果两个都有了那就开始搞docker了，这个我不太懂，nginx/前端 后端 postgres 3个对吧，要compose好，然后现在先不追求https，以及疑问是第一次肯定是安装镜像部署，那之后呢？前端更新，nginx/前端镜像新部署那https申请岂不是会重复？postgres这个问题还不大，因为还涉及不到。

最后我要的目标是访问 http://sleeponthegrass.com 成功显示 hello world 界面

结果：

```
curl -I http://sleeponthegrass.com
HTTP/1.1 200 OK
Content-Length: 458
Accept-Ranges: bytes
Connection: keep-alive
Content-Type: text/html
Date: Mon, 17 Aug 2026 03:53:01 GMT
Etag: "6a8284ca-1ca"
Keep-Alive: timeout=4
Last-Modified: Mon, 17 Aug 2026 03:49:30 GMT
Proxy-Connection: keep-alive
Server: nginx/1.27.5

docker compose ps                                                                                                                                                   
NAME             IMAGE                COMMAND                  SERVICE   CREATED         STATUS         PORTS                                                                              
blog-backend-1   blog-backend         "/blog-backend"          backend   2 minutes ago   Up 2 minutes   6713/tcp                                                                           
blog-db-1        postgres:16-alpine   "docker-entrypoint.s…"   db        2 minutes ago   Up 2 minutes   5432/tcp                                                                           
blog-nginx-1     blog-nginx           "/docker-entrypoint.…"   nginx     2 minutes ago   Up 2 minutes   0.0.0.0:80->80/tcp, [::]:80->80/tcp 
```

访问前端页面成功展示

### 确认开发流程顺畅

我删除前端界面的 index.css，现在只有简单的hello wolrd

然后前端新加入 /pages/About.tsx 让我访问 /about 的时候可以有简单的界面，而且刷新不会有异常，后端加入一个 /api/health 确保后端也能正常加入端口

成功修改前后端后，直接到服务器运行那个deploy就行 https://sleeponthegrass.com/about 显示 about 页面

### 后端编译过慢

```
 => [backend build 1/6] FROM docker.io/library/golang:1.25-alpine@sha256:1e0126852075c9c60731c8ba49088448b91f63e2aed97ca9d1a9791622a05946                                             0.0s 
 => => resolve docker.io/library/golang:1.25-alpine@sha256:1e0126852075c9c60731c8ba49088448b91f63e2aed97ca9d1a9791622a05946                                                           0.0s 
 => [backend stage-1 1/3] FROM docker.io/library/alpine:3.20@sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc                                                  0.0s 
 => => resolve docker.io/library/alpine:3.20@sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc                                                                  0.0s 
 => [backend internal] load build context                                                                                                                                             0.0s 
 => => transferring context: 555B                                                                                                                                                     0.0s 
 => CACHED [backend build 2/6] WORKDIR /app                                                                                                                                           0.0s 
 => CACHED [backend build 3/6] COPY backend/go.mod backend/go.sum ./                                                                                                                  0.0s 
 => CACHED [backend build 4/6] RUN go mod download                                                                                                                                    0.0s 
 => [backend build 5/6] COPY backend/ ./                                                                                                                                              0.0s 
 => [backend build 6/6] RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -o /blog-backend .                                                                                          170.6s 
 => [nginx frontend-build 5/6] COPY frontend/ ./                                                                                                                                      0.4s 
 => [nginx frontend-build 6/6] RUN pnpm build                                                                                                                                        17.5s 
```

并行进行，这个后端最后才编译好，而且太慢了，我知道总时长肯定不会这么长，但是也要了30多秒，为什么？

就是编译的时候比较久，现在加入使用外部实体机缓存，但是还没测试，之后测试了再来写，mvp 就此差不多构建完成