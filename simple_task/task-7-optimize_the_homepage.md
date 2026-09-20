---
created_at: 2026-09-20T18:23:53+08:00
status: todo # done | todo
---

> 人下达task，你执行task并记录执行过程，人验收后记录验收看到的东西判断是否完成，你继续执行task，直到人认为结束了再手动修改status

# 说明

现在访问前端的 Home 的时候会向后端请求文章列表，一开始请求确实可以，但是阅读文章返回后又会请求一次，这个不是我想要的，我希望前端缓存好，返回 HomePage 的时候直接使用已有的文章列表，除非刷新网页才重新请求。

# 执行记录

### 2026-09-20 首个版本：模块级缓存文章列表（agent）

原因：`Home.tsx` 每次挂载都无条件请求 `/api/article_metainfo`，从文章页返回时 Home 重新挂载，于是又请求一次。

修改 `frontend/src/pages/Home.tsx`：
- 新增模块级变量 `let cachedArticles: ArticleMeta[] | null = null`，放在组件外
- `useState` 初始值直接用缓存：有缓存则 `articles = cachedArticles`、`status = 'done'`（首帧就渲染列表，无 loading 闪烁）
- `useEffect` 首行 `if (cachedArticles) return`，命中缓存不再发请求
- 请求成功后写入 `cachedArticles`

效果：整页刷新时模块状态重置 → 重新请求；站内路由切回首页（含浏览器前进/后退）复用缓存，不再请求。

验证：`bash scripts/build.sh` 通过（pnpm build 含 TS 类型检查 + go build）。

待部署后人工验收：首页 → 点进文章 → 返回首页，Network 面板不应再出现 `/api/article_metainfo` 请求；刷新页面应重新请求。

### 2026-09-20 部署受阻：修 deploy.sh 的端口判断（agent）

部署时 coexist 模式报「端口 18080 已被其他进程/其他 docker 容器占用」，但从 `ss`/`lsof` 看占用者就是本项目自己的 `blog-nginx-1`（`docker-proxy` 监听 `127.0.0.1:18080`）。

排查过程（服务器上实测）：
1. `sh scripts/deploy.sh` → Debian 的 sh 是 dash，不支持 `${BASH_SOURCE[0]}` → `Bad substitution`，`ROOT` 为空导致 `cd` 切到家目录，`.env.example` 找不到。**该脚本必须用 bash 执行**（`bash scripts/deploy.sh coexist` 或给执行权限后 `./scripts/deploy.sh`）。
2. weihu 跑时报「已被其他进程占用」是**误导**：weihu 无 docker 权限 → `docker ps` 失败 → `cid` 为空 → 退到 ss 分支，看到 docker-proxy 就报了「其他进程占用」。
   - 补充：该函数是在 `if check_port_free ...` 里调用的，bash 中 `if` 条件内的函数体会让 `set -e` 失效，所以 docker 失败不会中止脚本，才会继续走到 ss 分支。
3. root 跑时报「已被其他 docker 容器占用（非本 compose 项目）」，是**真 bug**：
   - `docker ps --format '{{.ID}}'` 输出 **12 位短 ID**，`docker compose ps -q` 输出 **64 位完整 ID**
   - 原代码 `grep -qx "$cid"` 做整行相等比较 → 永远匹配不上 → 把自己的容器误判成别的项目
   - 该逻辑是 task-6 第三轮加的，当时只在本地跑了 `bash -n`，没在服务器验证，所以一直没暴露

修改 `scripts/deploy.sh` 的 `check_port_free`：
- docker 查询失败时明确报「无法访问 docker daemon，请确认当前用户有 docker 权限」，不再伪装成端口被占
- `docker compose ps -q` 失败时明确报 compose/.env 配置问题，不再误报成「其他项目占用」
- ID 比较改为前缀匹配：`printf '%s\n' "$own" | grep -q "^${cid}"`（短 ID 唯一，不会误配），兼容两端 ID 长度不一致

验证：`bash -n scripts/deploy.sh` 通过；本地模拟了「docker 不可用 → 报权限错误」「短 ID 前缀匹配完整 ID → 判定为本项目」「他项目 ID → 不匹配」三种情况，结果符合预期。服务器需 `git pull` 后重新执行（用 bash、建议 sudo）。

附带环境结论（与 task-6 不同）：weihu 已 `usermod -aG docker`，但组变更需重新登录才生效；生效后 weihu 可以不用 root 直接跑部署（`git pull` 用自己的身份也不会有 dubious ownership 问题）。
