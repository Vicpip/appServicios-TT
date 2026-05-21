export const API = {
  reports: {
    list: '/api/admin/reports',
    detail: (id: string) => `/api/admin/reports/${id}`,
    review: (id: string) => `/api/admin/reports/${id}/review`,
    files: (id: string) => `/api/admin/reports/${id}/files`,
  },
  clients: {
    list: '/api/admin/clients',
    create: '/api/admin/clients',
    detail: (id: string) => `/api/admin/clients/${id}`,
    clientDetail: (id: string) => `/api/admin/clients/${id}/detail`,
  },
  technicians: {
    list: '/api/admin/technicians',
    create: '/api/admin/technicians',
    detail: (id: string) => `/api/admin/technicians/${id}`,
    reports: (id: string) => `/api/admin/technicians/${id}/reports`,
  },
  printers: {
    list: '/api/admin/printers',
    create: '/api/admin/printers',
    detail: (id: string) => `/api/admin/printers/${id}`,
    reports: (id: string) => `/api/admin/printers/${id}/reports`,
    stats: (id: string) => `/api/admin/printers/${id}/stats`,
    downloadTemplate: '/api/admin/printers/template/download',
    bulkUpload: '/api/admin/printers/bulk-upload',
  },
  plants: {
    list: '/api/admin/plants',
    create: '/api/admin/plants',
    update: (id: string) => `/api/admin/plants/${id}`,
  },
  areas: {
    list: '/api/admin/areas',
    create: '/api/admin/areas',
  },
  catalog: {
    models: '/api/admin/catalog/models',
    createModel: '/api/admin/catalog/models',
  },
  policies: {
    list: '/api/admin/policies',
    create: '/api/admin/policies',
    nextFolio: '/api/admin/policies/next-folio',
    detail: (id: string) => `/api/admin/policies/${id}`,
    printers: (id: string) => `/api/admin/policies/${id}/printers`,
    printerDetail: (policyId: string, printerId: string) =>
      `/api/admin/policies/${policyId}/printers/${printerId}`,
    assignments: (id: string) => `/api/admin/policies/${id}/assignments`,
    assignmentDelete: (policyId: string, printerId: string) =>
      `/api/admin/policies/${policyId}/assignments/${printerId}`,
    deliveries: (id: string) => `/api/admin/policies/${id}/deliveries`,
    deliveryDetail: (deliveryId: string) => `/api/admin/policy-deliveries/${deliveryId}/detail`,
    visits: (id: string) => `/api/admin/policies/${id}/visits`,
    generateVisits: (id: string) => `/api/admin/policies/${id}/visits/generate`,
    updateVisit: (policyId: string, visitId: string) =>
      `/api/admin/policies/${policyId}/visits/${visitId}`,
    deleteVisit: (policyId: string, visitId: string) =>
      `/api/admin/policies/${policyId}/visits/${visitId}`,
    deleteAllVisits: (policyId: string) =>
      `/api/admin/policies/${policyId}/visits`,
  },
  sync: {
    history: '/api/admin/sync/history',
    status: '/api/sync/status',
  },
  dashboard: {
    reportsByDay: '/api/admin/dashboard/reports-by-day',
    printersAttention: '/api/admin/dashboard/printers-attention',
    policiesExpiring: '/api/admin/dashboard/policies-expiring',
  },
  health: '/api/health',
} as const
