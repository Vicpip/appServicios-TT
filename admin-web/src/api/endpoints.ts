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
  },
  technicians: {
    list: '/api/admin/technicians',
    create: '/api/admin/technicians',
    detail: (id: string) => `/api/admin/technicians/${id}`,
  },
  printers: {
    list: '/api/admin/printers',
    create: '/api/admin/printers',
    detail: (id: string) => `/api/admin/printers/${id}`,
  },
  plants: {
    list: '/api/admin/plants',
    create: '/api/admin/plants',
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
    detail: (id: string) => `/api/admin/policies/${id}`,
    printers: (id: string) => `/api/admin/policies/${id}/printers`,
  },
  sync: {
    history: '/api/admin/sync/history',
    status: '/api/sync/status',
  },
  health: '/api/health',
} as const
