import { useEffect, useState } from 'react'
import { useParams } from 'react-router-dom'
import axios from 'axios'
import Header from '../components/Header'
import Article from '../components/Article'
import type { ArticleData } from '../types'

type Status = 'loading' | 'error' | 'done'

function ArticlePage() {
  const { slug } = useParams<{ slug: string }>()
  const [article, setArticle] = useState<ArticleData | null>(null)
  const [status, setStatus] = useState<Status>('loading')

  useEffect(() => {
    let cancelled = false
    setStatus('loading')
    axios
      .get<ArticleData>(`/api/articles/${slug}`)
      .then((res) => {
        if (cancelled) return
        setArticle(res.data)
        setStatus('done')
      })
      .catch(() => {
        if (cancelled) return
        setStatus('error')
      })
    return () => {
      cancelled = true
    }
  }, [slug])

  return (
    <div className="article-page">
      <Header />
      {status === 'done' && article ? (
        <main className="article-page-main">
          <Article article={article} />
        </main>
      ) : (
        <main className="article-page-status">
          {status === 'loading' ? 'loading…' : '加载失败'}
        </main>
      )}
    </div>
  )
}

export default ArticlePage
