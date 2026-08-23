---
created_at: 2026-08-18T14:04:15+08:00
status: done # done | todo
---

> 人下达task，你执行task并记录执行过程，人验收后记录验收看到的东西判断是否完成，你继续执行task，直到人认为结束了再手动修改status

# 说明

我要新加入一个组件，ArticlesList.tsx 就是展示所有文章的 title 和 创建日期并展示，出来，并且点击一个文章标题后就进入到类似现在 About 界面，展示 header 和文章内容，依旧保持极简。

然后后端多一个端口 /api/article_metainfo 返回文章的标题和日期（注意不是每次都扫描，运行的时候扫描获取一次元信息，之后使用fsnotify监控）

后端加入 fsnotify 这个监控库，如果 /articles 有变化就扫描新加入的或更新的 markdown 文章，更新索引（可能是新文章，可能是删除文章，可能是老文章更新，处理好这3种状态）

pages/Home 不显示 Hello 了，而是 axios 获取数据后展示 ArticlesList

# 执行记录（agent）

## 确认的方案

1. 新增后端接口 `GET /api/article_metainfo`：返回文章元信息数组 `[{slug, title, created_at}]`，**带 slug 字段**（前端跳转必需），按 created_at 倒序（新文章在前）
2. 后端启动时扫描一次 `articles/*.md` 建立索引，之后用 fsnotify 监控 `articles/` 目录，目录内文件有 Create/Write/Remove/Rename 事件时**整体重扫重建索引**（数据量小、可靠，天然覆盖新增/删除/更新三种状态），索引用 `sync.RWMutex` 保护
3. `fsnotify` 从 indirect 依赖提升为直接依赖（go.mod 已是直接 require）
4. 新增 `components/ArticlesList.tsx`：极简列表，标题 + `> 日期` 样式（日期前用 CSS `::before` 加 `> `），点击标题跳转 `/article/:slug`
5. 新增 `pages/ArticlePage.tsx` 路由 `/article/:slug`：逻辑同 About（Header + Article）
6. 原 `/about` 路由保留不动，About 仍是独立页面
7. `Home.tsx`：axios 拉 `/api/article_metainfo`，loading/error 处理参照 About，成功后渲染 Header + ArticlesList
8. 新样式 `articles-list.css` / `article-page.css`，`home.css` 改为列表页布局，均在 `main.tsx` 引入

## 改动

### 后端 `backend/main.go`
- 新增 `ArticleMeta` 结构体（slug / title / created_at）
- `main()`：启动时 `refreshIndex` 扫描一次；`fsnotify.NewWatcher()` + `watcher.Add("articles")`（与 `loadArticle` 相同的相对路径），启动监控 goroutine
- 新增 `GET /api/article_metainfo`：加锁读索引，返回按 created_at 倒序的元信息数组
- 新增 `watchArticles`：监听 Create/Write/Remove/Rename 事件，触发 `refreshIndex`
- 新增 `refreshIndex`：重扫 `articles/*.md` 重建索引（复用 `loadArticle` 解析 frontmatter），加锁替换
- `backend/go.mod`：`fsnotify v1.10.1` 变为直接依赖（`go mod tidy` 自动调整）

### 前端
- `src/types.ts`：新增 `ArticleMeta` 接口
- 新增 `src/components/ArticlesList.tsx`：展示每篇 title + created_at，标题为 `Link` 跳转 `/article/:slug`
- 新增 `src/styles/articles-list.css`：极简列表样式，日期行 `::before` 显示 `> `
- 新增 `src/pages/ArticlePage.tsx`：从 `useParams` 取 slug，axios 拉 `/api/articles/:slug`，Header + Article 展示，loading/加载失败居中
- 新增 `src/styles/article-page.css`
- 重写 `src/pages/Home.tsx`：axios 拉 `/api/article_metainfo` 展示 ArticlesList，不再显示 hello world
- `src/styles/home.css`：`home-main` 改为顶部对齐的文章列表容器（不再垂直居中），新增 `home-status`
- `src/App.tsx`：新增 `/article/:slug` 路由
- `src/main.tsx`：引入 `articles-list.css`、`article-page.css`

## 验证

- `bash scripts/build.sh` 通过：frontend（tsc + vite build）与 backend（go build）均 OK
- 本地未运行服务，部署与线上验证由人负责：push 后服务器 `git pull && ./scripts/deploy.sh`
- 线上验证建议：
  - `curl https://sleeponthegrass.com/api/article_metainfo` 应返回 `[{slug, title, created_at}]`
  - 浏览器访问 `/` 应看到文章列表（含 About），点击标题进入 `/article/:slug` 展示文章
  - 服务器上往 `backend/articles/` 新增/删除/修改 md 后，刷新首页列表应自动更新（fsnotify）

# 验证

基本没问题，上传新文章后刷新就可以看到，然后现在的markdown基本达到预期，就是图片还没有测试，现在文章不使用git管理，而是自己用别的方式上传，避免冲突

`cd /d/projects/blog && tar czf - backend/articles/ | ssh my_server "tar xzf - -C /home/blog/"` 使用 tar 上传，rsync 有bug，但是这个问题就是无法删除服务器的文件