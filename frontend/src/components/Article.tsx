import Markdown from 'react-markdown'
import remarkMath from 'remark-math'
import remarkGfm from 'remark-gfm'
import rehypeKatex from 'rehype-katex'
import 'katex/dist/katex.min.css'

export interface ArticleData {
  title: string
  created_at: string
  content: string
}

function formatDate(iso: string): string {
  // "2026-08-18T13:13:08+08:00" -> "2026-08-18 13:13:08"
  return iso.replace('T', ' ').replace(/\+08:00$/, '')
}

function Article({ article }: { article: ArticleData }) {
  return (
    <article className="article">
      <header className="article-header">
        <h1 className="article-title">{article.title}</h1>
        <p className="article-date">发布于 {formatDate(article.created_at)}（UTC+8）</p>
      </header>
      <div className="article-content">
        <Markdown
          remarkPlugins={[remarkMath, remarkGfm]}
          rehypePlugins={[rehypeKatex]}
        >
          {article.content}
        </Markdown>
      </div>
    </article>
  )
}

export default Article
