import { Link } from "react-router-dom";

function Navbar() {
  return (
    <nav style={{ padding: "15px", background: "#2c003e", color: "white" }}>
      <h2>RV Astro Vastu</h2>

      <div>
        <Link to="/">Home</Link> |
        <Link to="/kundali">Kundali</Link> |
        <Link to="/panchang">Panchang</Link> |
        <Link to="/matching">Matching</Link> |
        <Link to="/muhurat">Muhurat</Link> |
        <Link to="/vastu">Vastu</Link> |
        <Link to="/gemstone">Gemstone</Link>
      </div>
    </nav>
  );
}

export default Navbar;