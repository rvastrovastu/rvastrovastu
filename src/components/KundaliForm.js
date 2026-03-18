import { useState } from "react";
import { getKundali } from "../api/astrologyApi";

function KundaliForm() {
  const [form, setForm] = useState({
    year: "",
    month: "",
    date: "",
    hours: "",
    minutes: "",
    latitude: "",
    longitude: "",
    timezone: "5.5"
  });

  const [result, setResult] = useState(null);

  const handleChange = (e) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  const handleSubmit = async () => {
    const res = await getKundali(form);
    setResult(res);
  };

  return (
    <div>
      <h2>Generate Kundali</h2>

      <input name="year" placeholder="Year" onChange={handleChange} />
      <input name="month" placeholder="Month" onChange={handleChange} />
      <input name="date" placeholder="Date" onChange={handleChange} />
      <input name="hours" placeholder="Hour" onChange={handleChange} />
      <input name="minutes" placeholder="Minutes" onChange={handleChange} />
      <input name="latitude" placeholder="Latitude" onChange={handleChange} />
      <input name="longitude" placeholder="Longitude" onChange={handleChange} />

      <button onClick={handleSubmit}>Generate Kundali</button>

      {result && (
        <div>
          <h3>Planet Positions:</h3>
          <pre>{JSON.stringify(result, null, 2)}</pre>
        </div>
      )}
    </div>
  );
}

export default KundaliForm;