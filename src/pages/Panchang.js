import React, { useState } from "react";
import { getPanchang } from "../api/astrologyApi";

function Panchang() {
  const [birthDetails, setBirthDetails] = useState({ date: "", time: "", place: "" });
  const [panchangData, setPanchangData] = useState(null);

  const handleSubmit = async () => {
    const data = await getPanchang(birthDetails);
    setPanchangData(data);
  };

  return (
    <div>
      <h1>Panchang</h1>
      <input placeholder="Date (YYYY-MM-DD)" onChange={e => setBirthDetails({ ...birthDetails, date: e.target.value })} />
      <input placeholder="Time (HH:MM)" onChange={e => setBirthDetails({ ...birthDetails, time: e.target.value })} />
      <input placeholder="Place" onChange={e => setBirthDetails({ ...birthDetails, place: e.target.value })} />
      <button onClick={handleSubmit}>Get Panchang</button>

      {panchangData && (
        <pre>{JSON.stringify(panchangData, null, 2)}</pre>
      )}
    </div>
  );
}

export default Panchang;