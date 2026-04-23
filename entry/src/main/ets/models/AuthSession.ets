export const DEFAULT_API_HOST_IP: string = '192.168.182.1';
export const DEFAULT_API_BASE_URL: string = `http://${DEFAULT_API_HOST_IP}:3000/api/v1`;
export const LEGACY_LOCAL_API_BASE_URL: string = 'http://127.0.0.1:3000/api/v1';

export interface AuthSession {
  userId: string;
  username: string;
  token: string;
  loginAt: string;
}

export function createEmptyAuthSession(): AuthSession {
  return {
    userId: '',
    username: '',
    token: '',
    loginAt: ''
  };
}

export function isAuthSessionValid(session: AuthSession): boolean {
  return session.userId.trim().length > 0 && session.token.trim().length > 0;
}

export function resolveApiBaseUrl(savedBaseUrl: string): string {
  let trimmed = savedBaseUrl.trim();
  if (trimmed.length === 0 || trimmed === LEGACY_LOCAL_API_BASE_URL) {
    return DEFAULT_API_BASE_URL;
  }
  return trimmed;
}
