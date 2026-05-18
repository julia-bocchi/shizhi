import { describe, it, expect } from '@ohos/hypium';
import { createLoginResultFromResponse } from '../main/ets/utils/ApiService';
import { deserializeAuthSession } from '../main/ets/utils/AuthStorageHelper';

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
  });
}
