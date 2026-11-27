const API_BASE = (window.__CAVOM_CONFIG__?.apiBaseUrl || '/api').replace(/\/$/, '');

function csrfToken() {
  const cookie = document.cookie
    .split('; ')
    .find((entry) => entry.startsWith('XSRF-TOKEN='));
  return cookie ? decodeURIComponent(cookie.slice('XSRF-TOKEN='.length)) : null;
}

async function request(path, options = {}) {
  const token = csrfToken();
  const response = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers: {
      Accept: 'application/json',
      ...(options.body ? { 'Content-Type': 'application/json' } : {}),
      ...(token && options.method && options.method !== 'GET' ? { 'X-XSRF-TOKEN': token } : {}),
      ...options.headers
    }
  });
  if (!response.ok) {
    let message = `Request failed (${response.status})`;
    try {
      const error = await response.json();
      message = error.message || Object.values(error.errors || {}).join(', ') || message;
    } catch {
      // Keep the HTTP-derived message for non-JSON errors.
    }
    throw new Error(message);
  }
  if (response.status === 204) return null;
  return response.json();
}

export const api = {
  members: () => request('/members'),
  createMember: (member) => request('/members', { method: 'POST', body: JSON.stringify(member) }),
  contributions: (memberId) => request(`/members/${memberId}/contributions`),
  createContribution: (memberId, contribution) =>
    request(`/members/${memberId}/contributions`, {
      method: 'POST',
      body: JSON.stringify(contribution)
    })
};
