import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import ProtectedRoute from './components/ProtectedRoute'
import Layout from './components/Layout'

// Public pages
import Login from './pages/Login'
import Registro from './pages/Registro'
import Recuperar from './pages/Recuperar'
import ResetPassword from './pages/ResetPassword'

// Protected pages
import Dashboard from './pages/Dashboard'
import Impresoras from './pages/Impresoras'
import ImpresoraDetalle from './pages/ImpresoraDetalle'
import Reportes from './pages/Reportes'
import ReporteDetalle from './pages/ReporteDetalle'
import Polizas from './pages/Polizas'

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        {/* Public */}
        <Route path="/login"          element={<Login />} />
        <Route path="/registro"       element={<Registro />} />
        <Route path="/recuperar"      element={<Recuperar />} />
        <Route path="/reset-password" element={<ResetPassword />} />

        {/* Protected — all wrapped in Layout sidebar */}
        <Route element={<ProtectedRoute />}>
          <Route element={<Layout />}>
            <Route path="/dashboard"          element={<Dashboard />} />
            <Route path="/impresoras"         element={<Impresoras />} />
            <Route path="/impresoras/:id"     element={<ImpresoraDetalle />} />
            <Route path="/reportes"           element={<Reportes />} />
            <Route path="/reportes/:id"       element={<ReporteDetalle />} />
            <Route path="/polizas"            element={<Polizas />} />
          </Route>
        </Route>

        {/* Fallback */}
        <Route path="*" element={<Navigate to="/dashboard" replace />} />
      </Routes>
    </BrowserRouter>
  )
}
