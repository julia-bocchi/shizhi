export const DEFAULT_API_BASE_URL: string = 'http://127.0.0.1:3000/api/v1';

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
