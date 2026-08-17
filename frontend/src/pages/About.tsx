import { Link } from 'react-router-dom'

function About() {
  return (
    <main>
      <h1>About</h1>
      <p>This is the about page.</p>
      <Link to="/">Home</Link>
    </main>
  )
}

export default About
