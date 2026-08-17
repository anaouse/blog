import { Link } from 'react-router-dom'

function Home() {
  return (
    <main>
      <h1>hello world</h1>
      <Link to="/about">About</Link>
    </main>
  )
}

export default Home
