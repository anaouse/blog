import { useEffect, useState } from 'react'
import axios from 'axios'
import Header from '../components/Header'
import Article, { type ArticleData } from '../components/Article'

type Status = 'loading' | 'error' | 'done'

function About() {
  const [article, setArticle] = useState<ArticleData | null>(null)
  const [status, setStatus] = useState<Status>('loading')

  useEffect(() => {
    let cancelled = false
    axios
      .get<ArticleData>('/api/articles/about')
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
  }, [])

  return (
    <div className="about">
      <Header />
      {status === 'done' && article ? (
        <main className="about-main">
          <Article article={article} />
        </main>
      ) : (
        <main className="about-status">
          {status === 'loading' ? 'loading…' : '加载失败'}
        </main>
      )}
    </div>
  )
}

export default About
