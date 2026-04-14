export const GENDER_UNKNOWN: string = '未填写';
export const GENDER_MALE: string = '男';
export const GENDER_FEMALE: string = '女';

export const PROFILE_REQUIRED_FIELDS: string[] = ['身高', '体重', '年龄', '性别'];

export interface UserProfile {
  nickname: string;
  heightCm: string;
  weightKg: string;
  age: string;
  gender: string;
}

export function createEmptyUserProfile(): UserProfile {
  return {
    nickname: '',
    heightCm: '',
    weightKg: '',
    age: '',
    gender: GENDER_UNKNOWN
  };
}
