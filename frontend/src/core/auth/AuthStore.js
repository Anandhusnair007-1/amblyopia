import { create } from "zustand";
import axios from "axios";

const API = `${process.env.REACT_APP_BACKEND_URL}/api`;
const KEY = "ambyoai.auth";

const setAuthHeader = (token) => {
  if (token) axios.defaults.headers.common["Authorization"] = `Bearer ${token}`;
  else delete axios.defaults.headers.common["Authorization"];
};

export const useAuthStore = create((set, get) => ({
  token: null,
  user: null,
  ready: false,

  hydrate: () => {
    try {
      const raw = localStorage.getItem(KEY);
      if (raw) {
        const { token, user } = JSON.parse(raw);
        if (token) {
          setAuthHeader(token);
          set({ token, user, ready: true });
          return;
        }
      }
    } catch (e) {}
    set({ ready: true });
  },

  setAuth: (token, user) => {
    setAuthHeader(token);
    localStorage.setItem(KEY, JSON.stringify({ token, user }));
    set({ token, user });
  },

  patientRequestOtp: async (phone) => {
    const r = await axios.post(`${API}/auth/patient/request-otp`, { phone });
    return r.data;
  },
  patientVerifyOtp: async (phone, otp) => {
    const r = await axios.post(`${API}/auth/patient/verify-otp`, { phone, otp });
    get().setAuth(r.data.token, r.data.user);
    return r.data;
  },
  doctorLogin: async (email, password) => {
    const r = await axios.post(`${API}/auth/doctor/login`, { email, password });
    get().setAuth(r.data.token, r.data.user);
    return r.data.user;
  },
  logout: () => {
    localStorage.removeItem(KEY);
    setAuthHeader(null);
    set({ token: null, user: null });
  },
}));

export const api = axios.create({ baseURL: API });
api.interceptors.request.use((cfg) => {
  const t = useAuthStore.getState().token;
  if (t) cfg.headers.Authorization = `Bearer ${t}`;
  return cfg;
});
api.interceptors.response.use(
  (r) => r,
  (err) => {
    if (err?.response?.status === 401) {
      useAuthStore.getState().logout();
      if (window.location.pathname !== "/" && !window.location.pathname.endsWith("-login")) {
        window.location.href = "/";
      }
    }
    return Promise.reject(err);
  }
);
