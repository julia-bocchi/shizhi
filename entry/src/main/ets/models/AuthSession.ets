export const DEFAULT_API_HOST_IP: string = 'https://diffusion-dose-playing.ngrok-free.dev';
export const DEFAULT_API_BASE_URL: string = `${DEFAULT_API_HOST_IP}/api/v1`;
export const PSEUDO_AUTH_TOKEN_PREFIX: string = 'local-login-';

export interface AuthSession {
  userId: number;
  username: string;
  token: string;
  loginAt: string;
}

export function normalizeUserId(value: string | number | boolean | undefined | null, fallbackValue: number = 0): number {
  if (typeof value === 'number') {
    if (isNaN(value)) {
      return fallbackValue;
    }
    let normalizedValue = Math.trunc(value);
    return normalizedValue > 0 ? normalizedValue : fallbackValue;
  }
  if (value === undefined || value === null) {
    return fallbackValue;
  }
  let parsedValue = Number(`${value}`.trim());
  if (isNaN(parsedValue)) {
    return fallbackValue;
  }
  let normalizedValue = Math.trunc(parsedValue);
  return normalizedValue > 0 ? normalizedValue : fallbackValue;
}

export function createEmptyAuthSession(): AuthSession {
  return {
    userId: 0,
    username: '',
    token: '',
    loginAt: ''
  };
}

export function isAuthSessionValid(session: AuthSession): boolean {
  return normalizeUserId(session.userId) > 0 &&
    session.token.trim().length > 0 &&
    !isPseudoAuthSession(session);
}

export function isPseudoAuthSession(session: AuthSession): boolean {
  return session.token.trim().startsWith(PSEUDO_AUTH_TOKEN_PREFIX);
}

export function resolveApiBaseUrl(savedBaseUrl: string): string {
  let trimmed = savedBaseUrl.trim();
  if (trimmed.length === 0) {
    return DEFAULT_API_BASE_URL;
  }
  return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
}
