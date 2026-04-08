import { createBrowserRouter } from 'react-router-dom'
import AppLayout from '@/components/layout/AppLayout'
import DashboardPage from '@/pages/DashboardPage'
import ReportsPage from '@/pages/ReportsPage'
import ClientsPage from '@/pages/ClientsPage'
import TechniciansPage from '@/pages/TechniciansPage'
import PrintersPage from '@/pages/PrintersPage'
import PoliciesPage from '@/pages/PoliciesPage'
import SyncPage from '@/pages/SyncPage'
import PrinterDetailPage from '@/pages/PrinterDetailPage'
import TechnicianProfilePage from '@/pages/TechnicianProfilePage'

export const router = createBrowserRouter([
  {
    path: '/',
    element: <AppLayout />,
    children: [
      { index: true, element: <DashboardPage /> },
      { path: 'reports', element: <ReportsPage /> },
      { path: 'clients', element: <ClientsPage /> },
      { path: 'technicians', element: <TechniciansPage /> },
      { path: 'technicians/:id', element: <TechnicianProfilePage /> },
      { path: 'printers', element: <PrintersPage /> },
      { path: 'printers/:id', element: <PrinterDetailPage /> },
      { path: 'policies', element: <PoliciesPage /> },
      { path: 'sync', element: <SyncPage /> },
    ],
  },
])
