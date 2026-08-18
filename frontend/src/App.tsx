import { BrowserRouter, Routes, Route } from 'react-router-dom'
import Home from './pages/Home'
import About from './pages/About'
import ArticlePage from './pages/ArticlePage'

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/about" element={<About />} />
        <Route path="/article/:slug" element={<ArticlePage />} />
      </Routes>
    </BrowserRouter>
  )
}

export default App
