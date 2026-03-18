import axios from 'axios'

const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_URL as string,
  timeout: 15000,
  headers: {
    'Content-Type': 'application/json',
    Accept: 'application/json',
  },
})

apiClient.interceptors.request.use(
  (config) => config,
  (error: unknown) => Promise.reject(error)
)

apiClient.interceptors.response.use(
  (response) => response,
  (error: unknown) => Promise.reject(error)
)

export default apiClient
