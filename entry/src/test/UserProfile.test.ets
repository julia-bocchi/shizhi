import { describe, it, expect } from '@ohos/hypium';
import { UserProfile, GENDER_UNKNOWN } from '../main/ets/models/UserProfile';
import {
  getProfileTagline,
  normalizeUserProfile,
  serializeUserProfile
} from '../main/ets/utils/ExerciseHelper';

export default function userProfileTest() {
  describe('userProfileTest', () => {
    it('normalizes null profile fields from backend response', 0, () => {
      let profile = JSON.parse('{"nickname":null,"heightCm":null,"weightKg":null,"age":null,"gender":null}') as UserProfile;
      let normalizedProfile = normalizeUserProfile(profile);

      expect(normalizedProfile.nickname).assertEqual('');
      expect(normalizedProfile.heightCm).assertEqual('');
      expect(normalizedProfile.weightKg).assertEqual('');
      expect(normalizedProfile.age).assertEqual('');
      expect(normalizedProfile.gender).assertEqual(GENDER_UNKNOWN);
      expect(getProfileTagline(profile)).assertEqual('补充资料后，运动页会自动联动计算。');
      expect(serializeUserProfile(profile)).assertEqual('||||%E6%9C%AA%E5%A1%AB%E5%86%99');
    });
  });
}
