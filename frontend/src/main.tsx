import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import App from './App.tsx'
import './styles/base.css'
import './styles/header.css'
import './styles/article.css'
import './styles/home.css'
import './styles/about.css'
import './styles/articles-list.css'
import './styles/article-page.css'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
