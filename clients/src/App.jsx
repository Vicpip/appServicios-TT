import { createBrowserRouter, RouterProvider, Navigate } from 'react-router-dom'
import Layout from '@/components/Layout'
import ProtectedRoute from '@/components/ProtectedRoute'
import Login from '@/pages/Login'
import Registro from '@/pages/Registro'
import Recuperar from '@/pages/Recuperar'
import ResetPassword from '@/pages/ResetPassword'
import Dashboard from '@/pages/Dashboard'
import Impresoras from '@/pages/Impresoras'
import ImpresoraDetalle from '@/pages/ImpresoraDetalle'
import Reportes from '@/pages/Reportes'
import Polizas from '@/pages/Polizas'
import PolizaDetalle from '@/pages/PolizaDetalle'

const router = createBrowserRouter([
  { path: '/login', element: <Login /> },
  { path: '/registro', element: <Registro /> },
  { path: '/recuperar', element: <Recuperar /> },
  { path: '/reset-password', element: <ResetPassword /> },
  {
    path: '/',
    element: (
      <ProtectedRoute>
        <Layout />
      </ProtectedRoute>
    ),
    children: [
      { index: true, element: <Navigate to="/dashboard" replace /> },
      { path: 'dashboard', element: <Dashboard /> },
      { path: 'impresoras', element: <Impresoras /> },
      { path: 'impresoras/:id', element: <ImpresoraDetalle /> },
      { path: 'reportes', element: <Reportes /> },
      { path: 'polizas', element: <Polizas /> },
      { path: 'polizas/:id', element: <PolizaDetalle /> },
    ],
  },
  { path: '*', element: <Navigate to="/login" replace /> },
])

export default function App() {
  return <RouterProvider router={router} />
}
