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