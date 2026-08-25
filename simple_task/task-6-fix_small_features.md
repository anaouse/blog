---
created_at: 2026-08-25T11:42:20+08:00
status: todo # done | todo
---

> 人下达task，你执行task并记录执行过程，人验收后记录验收看到的东西判断是否完成，你继续执行task，直到人认为结束了再手动修改status

# 说明

前端当中有一个 favicon svg 我希望别人访问这个博客的时候浏览器的tab展示我这个svg

现在别人访问我这个网站的时候浏览器的tab展示的名称是frontend，我希望是sleeponthegrass

# 执行记录

### 2026-08-25 修改 index.html（agent）

问题定位（都在 `frontend/index.html`）：
1. favicon 不显示：`<link rel="icon" href="/favicon.svg">` 指向的文件不存在，实际文件叫 `favicon-grass.svg`
2. tab 名称错误：`<title>frontend</title>`，期望 `sleeponthegrass`

修改 `frontend/index.html`：
- `href="/favicon.svg"` → `href="/favicon-grass.svg"`
- `<title>frontend</title>` → `<title>sleeponthegrass</title>`

验证：
- `bash scripts/build.sh` 通过（frontend pnpm build + backend go build）
- Vite 将 `favicon-grass.svg` 作为源码资源打包：构建后 `dist/index.html` 的 href 自动改写为 `/assets/favicon-grass-BhFUa824.svg`，文件存在于 `dist/assets/`，favicon 可正常加载

待部署后人工验收：浏览器 tab 显示草图标 + 标题 sleeponthegrass

### 2026-08-25 修复 deploy.sh 端口检查误报（agent）

部署时执行 `./scripts/deploy.sh coexist` 报错：
```
错误：端口 18080 已被其他进程占用，请在 .env 中换一个 COEXIST_HTTP_PORT
```
但 `sudo lsof -i :18080` 显示占用者就是本项目博客容器的 docker-proxy（`docker-pr`）。

根因：`check_port_free` 里已有 docker-proxy 放行逻辑，但它是靠 `ss -tlnp` 输出中 grep 进程名 `docker-proxy` 识别；普通用户无 root 权限时 `ss` 拿不到进程名（`lsof` 才需要 sudo），匹配不上就误判占用。standalone 和 coexist 用的同一个函数，并非模式差异。

修改 `scripts/deploy.sh`：
- `check_port_free` 开头改为直接查 docker：`docker ps --format '{{.Names}}' --filter "publish=$port"`，端口由 docker 容器发布即放行（docker compose up 会重建并接管），不再依赖 ss 的 root 权限
- 清理两处调用点重复的错误输出（错误主信息统一由函数输出）

验证：`bash -n scripts/deploy.sh` 通过。注意该修改需 push 到 GitHub 后由服务器 `git pull` 才能生效，然后重新执行 `./scripts/deploy.sh coexist`。
