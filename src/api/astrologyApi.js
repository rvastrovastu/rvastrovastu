import axios from "axios";

const BASE_URL = "http://localhost:5000"; // update to deployed backend URL later

export const getKundali = async (birthDetails) => {
  const res = await axios.post(`${BASE_URL}/api/kundali`, birthDetails);
  return res.data;
};

export const getPanchang = async (birthDetails) => {
  const res = await axios.post(`${BASE_URL}/api/panchang`, birthDetails);
  return res.data;
};