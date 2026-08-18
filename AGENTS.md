# AGENTS.md

本文件记录长期不变的开发约定，供 AI agent 参考。具体任务细节见 `simple_task/` 下各 task 文件。

## 环境与角色分工

- 开发环境是 **Windows**，部署目标是 **Debian 云服务器**。
- **本地只负责让代码编译通过，不运行服务**。编译检查命令统一走 `bash scripts/build.sh`（frontend 执行 `pnpm build` 含 TS 类型检查，backend 执行 `go build ./...`）。
- 本地没有 Docker，也不运行前后端服务，不要尝试在本地启动容器或服务。
- **部署与线上验证由人负责**：代码提交并 push 到 GitHub 后，由人在服务器上 `git pull` 并执行 `./scripts/deploy.sh` 完成更新与测试。agent 不负责部署，也不要求 agent 在服务器上验证。

## 技术栈（稳定部分）

- 前端：vite + react + typescript + react-compiler(所以不用写 useMemo 和 useCallback)，包管理用 pnpm（固定 `pnpm@11.18.0`，见 frontend 的 `packageManager` 字段）。
  - 前端样式约定：每个组件或页面需要写 css 时，单独创建同名小写开头的 css（如 `header.css`）；组件和页面的 css 统一放在 `/src/styles` 下，并在 `main.tsx` 中引用。保持极简，目前只做黑白色调。
- 后端：gin + postgres。
- 部署：docker compose，共 3 个服务 nginx / backend / db；nginx 镜像内多阶段构建前端 dist 并托管，`/api/*` 反代到 backend。
- 后端端口为 `6713`，反代目标为 `backend:6713`。

## 通用约定

- 后端端口统一为 `6713`。
- 本地编译产物（如 `backend.exe`）不要提交；`.dockerignore` 已排除 `*.exe`。
- 修改前后端代码后，先跑 `bash scripts/build.sh` 确认编译通过，再交给人去服务器部署。
- 不要擅自删除文件，不要扩展与当前任务无关的范围。
