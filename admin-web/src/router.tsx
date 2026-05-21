import { createBrowserRouter } from 'react-router-dom'
import AppLayout from '@/components/layout/AppLayout'
import ProtectedRoute from '@/components/ProtectedRoute'
import LoginPage from '@/pages/LoginPage'
import DashboardPage from '@/pages/DashboardPage'
import ReportsPage from '@/pages/ReportsPage'
import ClientsPage from '@/pages/ClientsPage'
import TechniciansPage from '@/pages/TechniciansPage'
import PrintersPage from '@/pages/PrintersPage'
import PoliciesPage from '@/pages/PoliciesPage'
import PolicyDetailPage from '@/pages/PolicyDetailPage'
import SyncPage from '@/pages/SyncPage'
import ClientDetailPage from '@/pages/ClientDetailPage'
import PrinterDetailPage from '@/pages/PrinterDetailPage'
import TechnicianProfilePage from '@/pages/TechnicianProfilePage'

export const router = createBrowserRouter([
  {
    path: '/login',
    element: <LoginPage />,
  },
  {
    path: '/',
    element: (
      <ProtectedRoute>
        <AppLayout />
      </ProtectedRoute>
    ),
    children: [
      { index: true, element: <DashboardPage /> },
      { path: 'reports', element: <ReportsPage /> },
      { path: 'clients', element: <ClientsPage /> },
      { path: 'clients/:id', element: <ClientDetailPage /> },
      { path: 'technicians', element: <TechniciansPage /> },
      { path: 'technicians/:id', element: <TechnicianProfilePage /> },
      { path: 'printers', element: <PrintersPage /> },
      { path: 'printers/:id', element: <PrinterDetailPage /> },
      { path: 'policies', element: <PoliciesPage /> },
      { path: 'policies/:id', element: <PolicyDetailPage /> },
      { path: 'sync', element: <SyncPage /> },
    ],
  },
])
