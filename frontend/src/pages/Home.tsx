import { useEffect, useState } from 'react'
import axios from 'axios'
import Header from '../components/Header'
import ArticlesList from '../components/ArticlesList'
import type { ArticleMeta } from '../types'

type Status = 'loading' | 'error' | 'done'

// 模块级缓存：整页刷新后失效，从文章页返回首页时直接复用
let cachedArticles: ArticleMeta[] | null = null

function Home() {
  const [articles, setArticles] = useState<ArticleMeta[]>(cachedArticles ?? [])
  const [status, setStatus] = useState<Status>(cachedArticles ? 'done' : 'loading')

  useEffect(() => {
    if (cachedArticles) return
    let cancelled = false
    axios
      .get<ArticleMeta[]>('/api/article_metainfo')
      .then((res) => {
        if (cancelled) return
        cachedArticles = res.data
        setArticles(res.data)
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
    <div className="home">
      <Header />
      {status === 'done' ? (
        <main className="home-main">
          <ArticlesList articles={articles} />
        </main>
      ) : (
        <main className="home-status">
          {status === 'loading' ? 'loading…' : '加载失败'}
        </main>
      )}
    </div>
  )
}

export default Home
