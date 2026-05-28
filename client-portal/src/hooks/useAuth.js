/**
 * useAuth — reads the JWT from localStorage, decodes its payload,
 * and exposes user info (name, email, client_id, etc.)
 *
 * No library needed: JWT payload is just base-64 encoded JSON.
 */
export function useAuth() {
  const token = localStorage.getItem('portal_token')

  if (!token) {
    return { token: null, user: null, isAuthenticated: false }
  }

  try {
    const parts = token.split('.')
    if (parts.length !== 3) throw new Error('invalid token')
    // Pad base64url → base64
    const payload = JSON.parse(
      atob(parts[1].replace(/-/g, '+').replace(/_/g, '/'))
    )

    // Check expiry
    if (payload.exp && payload.exp * 1000 < Date.now()) {
      localStorage.removeItem('portal_token')
      return { token: null, user: null, isAuthenticated: false }
    }

    return {
      token,
      user: {
        id:         payload.sub ?? payload.id,
        name:       payload.name ?? '',
        email:      payload.email ?? '',
        clientId:   payload.client_id ?? null,
        clientName: payload.client_name ?? '',
        plantName:  payload.plant_name ?? '',
        role:       payload.role ?? 'client',
      },
      isAuthenticated: true,
    }
  } catch {
    localStorage.removeItem('portal_token')
    return { token: null, user: null, isAuthenticated: false }
  }
}

export function logout() {
  localStorage.removeItem('portal_token')
  window.location.href = '/login'
}
