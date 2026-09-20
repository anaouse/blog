---
created_at: 2026-08-25T11:42:20+08:00
status: done # done | todo
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

### 2026-08-25 第二轮部署：非 root 仍失败，最终定 root + safe.directory（agent）

push 后服务器 `git pull` 拉到第一版修复，重新部署仍失败，这次看清了两层问题：

**问题 1：weihu（非 root）跑 `docker ps` 无权限**
- `docker ps` 要连 docker daemon（`/var/run/docker.sock`），weihu 不在 docker 组 → 命令失败，但 stderr 被 `2>/dev/null` 吞掉 → 匹配不到容器 → 落到 `ss` 检查 → `ss` 无 root 也拿不到进程名 → 误报「被占用」
- 之前 `docker compose version` 能过只是检查插件二进制，不需要连 daemon
- 结论：第一版「改用 docker 查询」逻辑本身没错，但前提是当前用户能访问 docker daemon；weihu 连 daemon 都访问不了，这不是 deploy.sh 能修的

**问题 2：root 跑检查全过，但挂在 `git pull`**
- 报 `fatal: detected dubious ownership in repository at '/home/weihu/blog'`：目录属主是 weihu，root 跑 git 出于安全机制拒绝
- 解决：root 下一次性执行 `git config --global --add safe.directory /home/weihu/blog`（写入 root 的 `~/.gitconfig`，之后永久生效）

**最终方案（采用）**：root 用户部署
```bash
git config --global --add safe.directory /home/weihu/blog
bash ./scripts/deploy.sh coexist
```
root 下 `docker ps` 正常 → 端口检查放行 → git pull 通过 → 部署成功。

**备选方案（未采用）**：让 weihu 跑，需给它 docker 权限并重新登录生效：
```bash
sudo usermod -aG docker weihu
```
属于服务器系统配置，且要退出重登，不如 root 一条命令省事。root 部署不影响之前 chown 过的文章目录权限（容器内进程 uid 由镜像决定，与宿主机谁跑 docker 无关）。

### 2026-08-25 第三轮：docker 判断收窄到「本 compose 项目」（agent）

人验收时提出：`docker ps --filter publish=$port` 只判断「端口是否被 docker 容器发布」，不区分是谁的容器。若 18080 被朋友服务器上其他 docker 项目占用，脚本会放行，最后 `docker compose up` 才报端口冲突，错误不直观。要求只放行我们自己的容器。

修改 `scripts/deploy.sh` 的 `check_port_free`：
- 先用 `docker ps --format '{{.ID}}' --filter "publish=$port"` 拿到占用端口的容器 id
- 再用 `docker compose $COMPOSE_FILES ps -q` 列出本 compose 项目运行中的容器，`grep -qx` 比对
  - 是本项目容器 → 放行（docker compose up 会重建接管）
  - 是其他 docker 项目容器 → 明确报错「非本 compose 项目」，退出
  - 非 docker 进程占用 → 走原 ss/netstat 分支报错
- compose 文件无顶层 `name:`，项目名即目录名（blog），`docker compose ps` 自动匹配，无需手动算项目名
- 注意 `$COMPOSE_FILES` 是全局变量，函数定义在前、调用在后（调用时已赋值）

验证：`bash -n scripts/deploy.sh` 通过。需 push 后服务器 `git pull`，root 下重跑 `bash ./scripts/deploy.sh coexist`。

# 验证

总之之后要先sudo到root然后再执行就好。算解决了。