import { NavLink } from 'react-router-dom'

function Header() {
  return (
    <header className="header">
      <nav className="header-nav">
        <NavLink to="/" end className="header-link">
          Home
        </NavLink>
        <NavLink to="/about" className="header-link">
          About
        </NavLink>
      </nav>
    </header>
  )
}

export default Header
