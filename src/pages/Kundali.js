import React, { useState } from "react";
import { getKundali } from "../api/astrologyApi";

function Kundali() {
  const [birthDetails, setBirthDetails] = useState({ date: "", time: "", place: "" });
  const [kundaliData, setKundaliData] = useState(null);

  const handleSubmit = async () => {
    const data = await getKundali(birthDetails);
    setKundaliData(data);
  };

  return (
    <div>
      <h1>Kundali Generator</h1>
      <input placeholder="Date (YYYY-MM-DD)" onChange={e => setBirthDetails({ ...birthDetails, date: e.target.value })} />
      <input placeholder="Time (HH:MM)" onChange={e => setBirthDetails({ ...birthDetails, time: e.target.value })} />
      <input placeholder="Place" onChange={e => setBirthDetails({ ...birthDetails, place: e.target.value })} />
      <button onClick={handleSubmit}>Generate Kundali</button>

      {kundaliData && (
        <pre>{JSON.stringify(kundaliData, null, 2)}</pre>
      )}
    </div>
  );
}

export default Kundali;