import { createBrowserRouter } from 'react-router-dom'
import AppLayout from '@/components/layout/AppLayout'
import DashboardPage from '@/pages/DashboardPage'
import ReportsPage from '@/pages/ReportsPage'
import ClientsPage from '@/pages/ClientsPage'
import TechniciansPage from '@/pages/TechniciansPage'
import PrintersPage from '@/pages/PrintersPage'
import PoliciesPage from '@/pages/PoliciesPage'
import SyncPage from '@/pages/SyncPage'

export const router = createBrowserRouter([
  {
    path: '/',
    element: <AppLayout />,
    children: [
      { index: true, element: <DashboardPage /> },
      { path: 'reports', element: <ReportsPage /> },
      { path: 'clients', element: <ClientsPage /> },
      { path: 'technicians', element: <TechniciansPage /> },
      { path: 'printers', element: <PrintersPage /> },
      { path: 'policies', element: <PoliciesPage /> },
      { path: 'sync', element: <SyncPage /> },
    ],
  },
])
