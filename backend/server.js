require("dotenv").config();

const express = require("express");
const axios = require("axios");
const cors = require("cors");

const app = express();

app.use(cors());
app.use(express.json());

const API_KEY = process.env.API_KEY;

// Kundali API
app.post("/api/kundali", async (req, res) => {
  try {
    const response = await axios.post(
      "https://json.freeastrologyapi.com/planets",
      req.body,
      {
        headers: {
          "Content-Type": "application/json",
          "x-api-key": API_KEY,
        },
      }
    );

    res.json(response.data);

  } catch (error) {
    console.error(error.response?.data || error.message);
    res.status(500).send("Error fetching kundali");
  }
});

// Panchang API
app.post("/api/panchang", async (req, res) => {
  try {
    const response = await axios.post(
      "https://json.freeastrologyapi.com/panchang",
      req.body,
      {
        headers: {
          "Content-Type": "application/json",
          "x-api-key": API_KEY,
        },
      }
    );

    res.json(response.data);

  } catch (error) {
    console.error(error.response?.data || error.message);
    res.status(500).send("Error fetching panchang");
  }
});

app.listen(5000, () => {
  console.log("Backend running on http://localhost:5000");
});