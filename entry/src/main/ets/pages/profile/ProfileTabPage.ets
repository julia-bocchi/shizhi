import {
  PAGE_BACKGROUND_COLOR,
  PRIMARY_TEXT_COLOR,
  SECONDARY_TEXT_COLOR,
  SURFACE_BACKGROUND_COLOR
} from '../../constants/AppTheme';
import {
  GENDER_FEMALE,
  GENDER_MALE,
  GENDER_UNKNOWN,
  UserProfile,
  createEmptyUserProfile
} from '../../models/UserProfile';
import {
  getBmiInfo,
  getCalorieRequirementText,
  getGenderSuggestion,
  getProfileCompletionText,
  getProfileReminderText,
  getProfileTagline,
  serializeUserProfile
} from '../../utils/ExerciseHelper';
import { DEFAULT_API_BASE_URL, isAuthSessionValid } from '../../models/AuthSession';
import { deserializeAuthSession } from '../../utils/AuthStorageHelper';
import { fetchUserProfile, loginWithPassword, logoutSession, updateUserProfileRemote } from '../../utils/ApiService';

@Component
export struct ProfileTabPage {
  @Link userProfile: UserProfile;
  @Link userProfileText: string;
  @State profileNotice: string = '资料实时生效，会自动同步到运动页。';
  @StorageLink('apiBaseUrlText') apiBaseUrlText: string = '';
  @StorageLink('authSessionText') authSessionText: string = '';
  @State loginUsername: string = '';
  @State loginPassword: string = '';
  @State authBusy: boolean = false;
  @State profileSaving: boolean = false;

  aboutToAppear(): void {
    if (this.apiBaseUrlText.trim().length === 0) {
      this.apiBaseUrlText = DEFAULT_API_BASE_URL;
    }
    let authSession = deserializeAuthSession(this.authSessionText);
    if (this.loginUsername.trim().length === 0 && authSession.username.trim().length > 0) {
      this.loginUsername = authSession.username;
    }
    if (isAuthSessionValid(authSession)) {
      this.pullProfileFromServer();
    }
  }

  private commitProfile(nextProfile: UserProfile, noticeText?: string): void {
    this.userProfile = nextProfile;
    this.userProfileText = serializeUserProfile(nextProfile);
    if (noticeText !== undefined) {
      this.profileNotice = noticeText;
    }
  }

  private updateProfileField(field: string, value: string): void {
    let nextProfile: UserProfile = {
      nickname: this.userProfile.nickname,
      heightCm: this.userProfile.heightCm,
      weightKg: this.userProfile.weightKg,
      age: this.userProfile.age,
      gender: this.userProfile.gender
    };

    if (field === 'nickname') {
      nextProfile.nickname = value;
    } else if (field === 'heightCm') {
      nextProfile.heightCm = value;
    } else if (field === 'weightKg') {
      nextProfile.weightKg = value;
    } else {
      nextProfile.age = value;
    }

    this.commitProfile(nextProfile);
  }

  private updateGender(gender: string): void {
    this.commitProfile({
      nickname: this.userProfile.nickname,
      heightCm: this.userProfile.heightCm,
      weightKg: this.userProfile.weightKg,
      age: this.userProfile.age,
      gender: gender
    }, '性别已更新，会一起参与资料完整度判断。');
  }

  private clearProfile(): void {
    this.commitProfile(createEmptyUserProfile(), '已清空资料，请重新输入你的个人信息。');
  }

  private getAuthSessionStatusText(): string {
    let authSession = deserializeAuthSession(this.authSessionText);
    if (!isAuthSessionValid(authSession)) {
      return '未登录';
    }
    return `已登录：${authSession.username.trim().length > 0 ? authSession.username.trim() : authSession.userId}`;
  }

  private getAuthStatusColor(): string {
    return isAuthSessionValid(deserializeAuthSession(this.authSessionText)) ? '#10B981' : '#FF7A59';
  }

  private async pullProfileFromServer(): Promise<void> {
    let authSession = deserializeAuthSession(this.authSessionText);
    if (!isAuthSessionValid(authSession)) {
      return;
    }
    try {
      let remoteProfile = await fetchUserProfile(this.apiBaseUrlText, authSession);
      this.commitProfile(remoteProfile, '已从后端拉取最新资料。');
    } catch (error) {
      this.profileNotice = `${error}`;
    }
  }

  private async handleLogin(): Promise<void> {
    if (this.authBusy) {
      return;
    }
    if (this.loginUsername.trim().length === 0) {
      this.profileNotice = '请先填写登录账号。';
      return;
    }
    if (this.loginPassword.length === 0) {
      this.profileNotice = '请先填写登录密码。';
      return;
    }
    this.authBusy = true;
    try {
      let result = await loginWithPassword(this.apiBaseUrlText, this.loginUsername, this.loginPassword);
      this.authSessionText = result.authSessionText;
      this.loginPassword = '';
      let remoteProfile = await fetchUserProfile(this.apiBaseUrlText, result.authSession);
      this.commitProfile(remoteProfile, '登录成功，已同步后端资料。');
    } catch (error) {
      this.profileNotice = `${error}`;
    } finally {
      this.authBusy = false;
    }
  }

  private handleLogout(): void {
    let result = logoutSession();
    this.authSessionText = result.authSessionText;
    this.loginPassword = '';
    this.profileNotice = '已退出登录，本地资料仍会保留。';
  }

  private async saveProfileToServer(): Promise<void> {
    if (this.profileSaving) {
      return;
    }
    let authSession = deserializeAuthSession(this.authSessionText);
    if (!isAuthSessionValid(authSession)) {
      this.profileNotice = '请先登录，再把资料保存到后端。';
      return;
    }
    this.profileSaving = true;
    try {
      let remoteProfile = await updateUserProfileRemote(this.apiBaseUrlText, authSession, this.userProfile);
      this.commitProfile(remoteProfile, '资料已保存到后端。');
    } catch (error) {
      this.profileNotice = `${error}`;
    } finally {
      this.profileSaving = false;
    }
  }

  private getBmiStatusColor(): string {
    let bmiInfo = getBmiInfo(this.userProfile);
    if (!bmiInfo.hasValue) {
      return '#94A0B4';
    }
    if (bmiInfo.statusText === '偏瘦') {
      return '#0F6BFF';
    }
    if (bmiInfo.statusText === '正常') {
      return '#10B981';
    }
    if (bmiInfo.statusText === '超重') {
      return '#FF7A59';
    }
    return '#FF5A7A';
  }

  private isSelectedGender(gender: string): boolean {
    return this.userProfile.gender === gender;
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Column({ space: 6 }) {
          Text('用户资料')
            .fontSize(30)
            .fontWeight(FontWeight.Bolder)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text('填写你的基本信息后，运动页会自动计算 BMI、训练建议和热量消耗。')
            .fontSize(14)
            .fontColor(SECONDARY_TEXT_COLOR)
            .lineHeight(22)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')

        Column({ space: 10 }) {
          Text(getProfileTagline(this.userProfile))
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')

          Text(getProfileCompletionText(this.userProfile))
            .fontSize(26)
            .fontWeight(FontWeight.Bolder)
            .fontColor('#FFFFFF')

          Text(getProfileReminderText(this.userProfile))
            .fontSize(13)
            .lineHeight(20)
            .fontColor('#E3EEFF')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(18)
        .backgroundColor('#0F6BFF')
        .borderRadius(24)

        Column({ space: 14 }) {
          Row() {
            Column({ space: 4 }) {
              Text('联调登录')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor(PRIMARY_TEXT_COLOR)

              Text('登录后会带上 token 请求后端资料与业务接口。')
                .fontSize(12)
                .fontColor(SECONDARY_TEXT_COLOR)
            }
            .alignItems(HorizontalAlign.Start)

            Text(this.getAuthSessionStatusText())
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getAuthStatusColor())
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor(this.getAuthStatusColor() === '#10B981' ? '#ECFFF4' : '#FFF0F6')
              .borderRadius(999)
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .alignItems(VerticalAlign.Top)

          Column({ space: 8 }) {
            Text('后端地址')
              .fontSize(12)
              .fontColor('#5373A6')

            TextInput({ placeholder: DEFAULT_API_BASE_URL, text: this.apiBaseUrlText })
              .fontSize(15)
              .fontColor(PRIMARY_TEXT_COLOR)
              .height(46)
              .width('100%')
              .padding({ left: 12, right: 12 })
              .backgroundColor('#F5F8FF')
              .borderRadius(16)
              .onChange((value: string) => {
                this.apiBaseUrlText = value;
              })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')

          Row({ space: 12 }) {
            Column({ space: 8 }) {
              Text('账号')
                .fontSize(12)
                .fontColor('#5373A6')

              TextInput({ placeholder: 'demo', text: this.loginUsername })
                .fontSize(15)
                .fontColor(PRIMARY_TEXT_COLOR)
                .height(46)
                .width('100%')
                .padding({ left: 12, right: 12 })
                .backgroundColor('#F5F8FF')
                .borderRadius(16)
                .onChange((value: string) => {
                  this.loginUsername = value;
                })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Column({ space: 8 }) {
              Text('密码')
                .fontSize(12)
                .fontColor('#5373A6')

              TextInput({ placeholder: '123456', text: this.loginPassword })
                .fontSize(15)
                .fontColor(PRIMARY_TEXT_COLOR)
                .height(46)
                .width('100%')
                .padding({ left: 12, right: 12 })
                .backgroundColor('#F5F8FF')
                .borderRadius(16)
                .onChange((value: string) => {
                  this.loginPassword = value;
                })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')

          Row({ space: 10 }) {
            Button(this.authBusy ? '登录中...' : '登录并同步')
              .layoutWeight(1)
              .height(44)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
              .backgroundColor('#0F6BFF')
              .borderRadius(18)
              .onClick(() => {
                this.handleLogin();
              })

            Button('退出登录')
              .layoutWeight(1)
              .height(44)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#0F6BFF')
              .backgroundColor('#EAF2FF')
              .borderRadius(18)
              .onClick(() => {
                this.handleLogout();
              })
          }
          .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(18)
        .backgroundColor(SURFACE_BACKGROUND_COLOR)
        .borderRadius(24)

        Column({ space: 14 }) {
          Text('基础信息')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_TEXT_COLOR)

          Column({ space: 8 }) {
            Text('昵称（可选）')
              .fontSize(12)
              .fontColor('#5373A6')

            TextInput({ placeholder: '例如 小林', text: this.userProfile.nickname })
              .fontSize(16)
              .fontColor(PRIMARY_TEXT_COLOR)
              .height(46)
              .width('100%')
              .padding({ left: 12, right: 12 })
              .backgroundColor('#F5F8FF')
              .borderRadius(16)
              .onChange((value: string) => {
                this.updateProfileField('nickname', value);
              })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')

          Row({ space: 12 }) {
            Column({ space: 8 }) {
              Text('身高')
                .fontSize(12)
                .fontColor('#5373A6')

              Row({ space: 8 }) {
                TextInput({ placeholder: '170', text: this.userProfile.heightCm })
                  .fontSize(16)
                  .fontColor(PRIMARY_TEXT_COLOR)
                  .height(46)
                  .layoutWeight(1)
                  .padding({ left: 12, right: 12 })
                  .backgroundColor('#F5F8FF')
                  .borderRadius(16)
                  .onChange((value: string) => {
                    this.updateProfileField('heightCm', value);
                  })

                Text('cm')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#0F6BFF')
                  .padding({ left: 12, right: 12, top: 11, bottom: 11 })
                  .backgroundColor('#EAF2FF')
                  .borderRadius(14)
              }
              .width('100%')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Column({ space: 8 }) {
              Text('体重')
                .fontSize(12)
                .fontColor('#5373A6')

              Row({ space: 8 }) {
                TextInput({ placeholder: '60', text: this.userProfile.weightKg })
                  .fontSize(16)
                  .fontColor(PRIMARY_TEXT_COLOR)
                  .height(46)
                  .layoutWeight(1)
                  .padding({ left: 12, right: 12 })
                  .backgroundColor('#F5F8FF')
                  .borderRadius(16)
                  .onChange((value: string) => {
                    this.updateProfileField('weightKg', value);
                  })

                Text('kg')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FF7A59')
                  .padding({ left: 12, right: 12, top: 11, bottom: 11 })
                  .backgroundColor('#FFF0F6')
                  .borderRadius(14)
              }
              .width('100%')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')

          Column({ space: 8 }) {
            Text('年龄')
              .fontSize(12)
              .fontColor('#5373A6')

            Row({ space: 8 }) {
              TextInput({ placeholder: '24', text: this.userProfile.age })
                .fontSize(16)
                .fontColor(PRIMARY_TEXT_COLOR)
                .height(46)
                .layoutWeight(1)
                .padding({ left: 12, right: 12 })
                .backgroundColor('#F5F8FF')
                .borderRadius(16)
                .onChange((value: string) => {
                  this.updateProfileField('age', value);
                })

              Text('岁')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#10B981')
                .padding({ left: 12, right: 12, top: 11, bottom: 11 })
                .backgroundColor('#ECFFF4')
                .borderRadius(14)
            }
            .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')

          Column({ space: 8 }) {
            Text('性别')
              .fontSize(12)
              .fontColor('#5373A6')

            Row({ space: 10 }) {
              Button(GENDER_MALE)
                .layoutWeight(1)
                .height(42)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.isSelectedGender(GENDER_MALE) ? '#FFFFFF' : PRIMARY_TEXT_COLOR)
                .backgroundColor(this.isSelectedGender(GENDER_MALE) ? '#0F6BFF' : '#EAF2FF')
                .borderRadius(16)
                .onClick(() => {
                  this.updateGender(GENDER_MALE);
                })

              Button(GENDER_FEMALE)
                .layoutWeight(1)
                .height(42)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.isSelectedGender(GENDER_FEMALE) ? '#FFFFFF' : PRIMARY_TEXT_COLOR)
                .backgroundColor(this.isSelectedGender(GENDER_FEMALE) ? '#FF7A59' : '#FFF0F6')
                .borderRadius(16)
                .onClick(() => {
                  this.updateGender(GENDER_FEMALE);
                })

              Button(GENDER_UNKNOWN)
                .layoutWeight(1)
                .height(42)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.isSelectedGender(GENDER_UNKNOWN) ? '#FFFFFF' : PRIMARY_TEXT_COLOR)
                .backgroundColor(this.isSelectedGender(GENDER_UNKNOWN) ? '#94A0B4' : '#F3F6FB')
                .borderRadius(16)
                .onClick(() => {
                  this.updateGender(GENDER_UNKNOWN);
                })
            }
            .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')

          Text(this.profileNotice)
            .fontSize(13)
            .lineHeight(20)
            .fontColor(SECONDARY_TEXT_COLOR)

          Button(this.profileSaving ? '保存中...' : '保存资料到后端')
            .width('100%')
            .height(46)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .backgroundColor('#0F6BFF')
            .borderRadius(18)
            .onClick(() => {
              this.saveProfileToServer();
            })

          Button('清空资料')
            .width('100%')
            .height(46)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#0F6BFF')
            .backgroundColor('#EAF2FF')
            .borderRadius(18)
            .onClick(() => {
              this.clearProfile();
            })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(18)
        .backgroundColor(SURFACE_BACKGROUND_COLOR)
        .borderRadius(24)

        Column({ space: 10 }) {
          Text('BMI 自动分析')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_TEXT_COLOR)

          Row({ space: 14 }) {
            Column({ space: 6 }) {
              Text(getBmiInfo(this.userProfile).valueText)
                .fontSize(28)
                .fontWeight(FontWeight.Bolder)
                .fontColor(this.getBmiStatusColor())

              Text(getBmiInfo(this.userProfile).statusText)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.getBmiStatusColor())
            }
            .alignItems(HorizontalAlign.Start)

            Text(getBmiInfo(this.userProfile).suggestionText)
              .layoutWeight(1)
              .fontSize(14)
              .lineHeight(22)
              .fontColor('#344054')
          }
          .width('100%')

          Text('BMI 采用常见成人判断区间：18.5 以下偏瘦，18.5-23.9 正常，24-27.9 超重，28 及以上肥胖。')
            .fontSize(12)
            .lineHeight(20)
            .fontColor(SECONDARY_TEXT_COLOR)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(18)
        .backgroundColor('#F4F0FF')
        .borderRadius(24)

        Column({ space: 10 }) {
          Text('热量计算基础')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text(getCalorieRequirementText(this.userProfile))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#0F6BFF')

          Text(getGenderSuggestion(this.userProfile))
            .fontSize(13)
            .lineHeight(20)
            .fontColor(SECONDARY_TEXT_COLOR)

          Text('运动页采用常见公式估算消耗：MET × 3.5 × 体重(kg) ÷ 200 × 时长(分钟)。')
            .fontSize(12)
            .lineHeight(20)
            .fontColor(SECONDARY_TEXT_COLOR)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(18)
        .backgroundColor('#EFF8FF')
        .borderRadius(24)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 24, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
    .friction(0.6)
    .backgroundColor(PAGE_BACKGROUND_COLOR)
  }
}
