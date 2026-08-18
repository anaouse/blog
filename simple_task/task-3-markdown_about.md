---
created_at: 2026-08-18T12:44:05+08:00
status: todo # done | todo
---

> 人下达task，你执行task并记录执行过程，人验收后记录验收看到的东西判断是否完成，你继续执行task，直到人认为结束了再手动修改status

# 说明

后端我打算博客文章和代码一起上传

结构是：

```
/backend
    /articles
        about.md
        xx.md
```

然后我现在要实现

使用的 markdown 渲染技术栈（已经安装）：react-markdown remark-math rehype-katex katex remark-gfm

使用的网络请求技术栈：axios

用法示例：

```tsx
import Markdown from 'react-markdown'
import remarkMath from 'remark-math'
import remarkGfm from 'remark-gfm'
import rehypeKatex from 'rehype-katex'
import 'katex/dist/katex.min.css' // 一定要单独引入这个 CSS

const content = `
行内公式 $E = mc^2$ 直接写在句子里。

块级公式:

$$
\\int_0^\\infty x^2 dx
$$
`

export default function BlogPost() {
  return (
    <Markdown
      remarkPlugins={[remarkMath, remarkGfm]}
      rehypePlugins={[rehypeKatex]}
    >
      {content}
    </Markdown>
  )
}
```

## 博客的大概内容

```markdown
---
title: About
created_at: 2026-08-18T13:04:32+08:00
---

# About

介绍一下自己：......

```

# 我的实现过程的规划

写一个 Header.tsx 组件，展示 Home 和 About，并且两个可以点击，点击后分别跳转到 `/` `/about` 路由

写一个 Article.tsx 组件，专门用来展示文章和标题，创建日期（标明是utc+8）的元数据

访问 https://sleeponthegrass.com/about 的时候前端使用 axios 访问接口 https://sleeponthegrass.com/api/about 获得文章数据，然后 pages/About.tsx 其实就是获取数据，展示一下 Header 和 Article 组件，把数据给Article组件（所以感觉这里要创建一个变量名称到什么配置当中？对应我的域名这样之后就可以复用了）

每个组件或者页面要写css就单独创建一个同名但是小写开头的css比如 `header.css` 组件的和页面的都统一放到 /src/styles 下，在 `main.tsx` 当中引用，先保持极简，只要黑白色调的

# 想要达到的效果

访问后有header和简单的hello界面，header上点击访问 about 进入 /about，后端返回 /articles/about.md 数据并展示出好看美观的文章

# 执行记录（agent）

## 确认的方案

1. 后端解析 frontmatter，返回 JSON：`{ title, created_at, content }`
2. 后端做通用路由 `/api/articles/:slug`（读取 `articles/{slug}.md`），About 导航指向 `/about` 这一篇
3. Header 在 Home / About 两个页面都展示
4. loading / 加载失败文字显示在页面正中间
5. created_at 格式问题由人自行修正

## 改动

### 后端
- `backend/main.go`：新增 `GET /api/articles/:slug`，读取 `articles/{slug}.md`，手写解析 frontmatter（title / created_at）返回 JSON；文件不存在或格式非法返回 404
- `backend/Dockerfile`：stage 2 增加 `COPY --from=build /app/articles /articles`（原来没把 articles 目录拷进镜像，会导致线上 404）

### 前端
- 新增 `src/components/Header.tsx`：Home / About 导航，NavLink 高亮当前页
- 新增 `src/components/Article.tsx`：展示标题、创建日期（UTC+8）、正文（react-markdown + remark-math + remark-gfm + rehype-katex，引入 katex.css）
- 重写 `src/pages/About.tsx`：axios 请求 `/api/articles/about`，loading / 加载失败 居中显示，成功后渲染 Header + Article
- 重写 `src/pages/Home.tsx`：Header + 居中的 hello world
- `src/main.tsx`：引入各样式文件
- 新增样式：`src/styles/base.css`（全局黑白基础）、`header.css`、`article.css`、`home.css`、`about.css`，黑白色调

## 验证

- `bash scripts/build.sh` 通过：frontend（tsc + vite build）与 backend（go build）均 OK
- 本地未运行服务，部署与线上验证由人负责：push 后服务器 `git pull && ./scripts/deploy.sh`
- 线上验证建议：`curl https://sleeponthegrass.com/api/articles/about` 应返回 JSON；浏览器访问 `/` 和 `/about` 查看 header、文章展示