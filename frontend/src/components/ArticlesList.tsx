import { Link } from 'react-router-dom'
import type { ArticleMeta } from '../types'

function formatDate(iso: string): string {
  // "2026-08-18T13:13:08+08:00" -> "2026-08-18 13:13:08"
  return iso.replace('T', ' ').replace(/\+08:00$/, '')
}

function ArticlesList({ articles }: { articles: ArticleMeta[] }) {
  return (
    <ul className="articles-list">
      {articles.map((a) => (
        <li key={a.slug} className="articles-list-item">
          <Link to={`/article/${a.slug}`} className="articles-list-title">
            {a.title}
          </Link>
          <p className="articles-list-date">{formatDate(a.created_at)}</p>
        </li>
      ))}
    </ul>
  )
}

export default ArticlesList
