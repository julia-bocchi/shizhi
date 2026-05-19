import { describe, it, expect } from '@ohos/hypium';
import { createLoginResultFromResponse } from '../main/ets/utils/ApiService';
import {
  deserializeAuthSession,
  resolveStoredAuthSession,
  resolveStoredAuthSessionText
} from '../main/ets/utils/AuthStorageHelper';

export default function authSessionTest() {
  describe('authSessionTest', () => {
    it('parses login response user_id and token', 0, () => {
      let result = createLoginResultFromResponse({
        user_id: '1006',
        username: 'demo',
        token: 'jwt-token'
      }, 'demo');

      let session = deserializeAuthSession(result.authSessionText);
      expect(session.userId).assertEqual(1006);
      expect(session.username).assertEqual('demo');
      expect(session.token).assertEqual('jwt-token');
    });

    it('recovers session from explicit stored token fields', 0, () => {
      let session = resolveStoredAuthSession('', 'stored-jwt-token', '1006', 'demo');

      expect(session.userId).assertEqual(1006);
      expect(session.username).assertEqual('demo');
      expect(session.token).assertEqual('stored-jwt-token');
    });

    it('prefers valid serialized session over fallback fields', 0, () => {
      let session = resolveStoredAuthSession(JSON.stringify({
        userId: 1007,
        username: 'saved',
        token: 'saved-token',
        loginAt: '1'
      }), 'fallback-token', '1006', 'demo');

      expect(session.userId).assertEqual(1007);
      expect(session.username).assertEqual('saved');
      expect(session.token).assertEqual('saved-token');
    });

    it('returns empty session when no valid stored token exists', 0, () => {
      let session = resolveStoredAuthSession('', '', '1006', 'demo');

      expect(session.userId).assertEqual(0);
      expect(session.token).assertEqual('');
    });

    it('serializes recovered session text from fallback fields', 0, () => {
      let sessionText = resolveStoredAuthSessionText('', 'stored-jwt-token', '1006', 'demo');
      let session = deserializeAuthSession(sessionText);

      expect(session.userId).assertEqual(1006);
      expect(session.username).assertEqual('demo');
      expect(session.token).assertEqual('stored-jwt-token');
    });
  });
}
