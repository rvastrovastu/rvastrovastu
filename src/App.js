import { BrowserRouter, Routes, Route } from "react-router-dom";

import Navbar from "./components/Navbar";
import Home from "./pages/Home";
import Kundali from "./pages/Kundali";
import Panchang from "./pages/Panchang";
import Matching from "./pages/Matching";
import Muhurat from "./pages/Muhurat";
import Vastu from "./pages/Vastu";
import Gemstone from "./pages/Gemstone";

function App() {
  return (
    <BrowserRouter>
      <Navbar />
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/kundali" element={<Kundali />} />
        <Route path="/panchang" element={<Panchang />} />
        <Route path="/matching" element={<Matching />} />
        <Route path="/muhurat" element={<Muhurat />} />
        <Route path="/vastu" element={<Vastu />} />
        <Route path="/gemstone" element={<Gemstone />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;