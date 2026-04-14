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

@Component
export struct ProfileTabPage {
  @Link userProfile: UserProfile;
  @Link userProfileText: string;
  @State profileNotice: string = '资料实时生效，会自动同步到运动页。';

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

  private getBmiStatusColor(): string {
    let bmiInfo = getBmiInfo(this.userProfile);
    if (!bmiInfo.hasValue) {
      return '#7D8794';
    }
    if (bmiInfo.statusText === '偏瘦') {
      return '#2F6FED';
    }
    if (bmiInfo.statusText === '正常') {
      return '#2E8B57';
    }
    if (bmiInfo.statusText === '超重') {
      return '#D86C3D';
    }
    return '#C95F34';
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
            .fontColor('#D8E5FF')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(18)
        .backgroundColor('#17324D')
        .borderRadius(24)

        Column({ space: 14 }) {
          Text('基础信息')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_TEXT_COLOR)

          Column({ space: 8 }) {
            Text('昵称（可选）')
              .fontSize(12)
              .fontColor('#4F6690')

            TextInput({ placeholder: '例如 小林', text: this.userProfile.nickname })
              .fontSize(16)
              .fontColor(PRIMARY_TEXT_COLOR)
              .height(46)
              .width('100%')
              .padding({ left: 12, right: 12 })
              .backgroundColor('#F6F8FB')
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
                .fontColor('#4F6690')

              Row({ space: 8 }) {
                TextInput({ placeholder: '170', text: this.userProfile.heightCm })
                  .fontSize(16)
                  .fontColor(PRIMARY_TEXT_COLOR)
                  .height(46)
                  .layoutWeight(1)
                  .padding({ left: 12, right: 12 })
                  .backgroundColor('#F6F8FB')
                  .borderRadius(16)
                  .onChange((value: string) => {
                    this.updateProfileField('heightCm', value);
                  })

                Text('cm')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#2F6FED')
                  .padding({ left: 12, right: 12, top: 11, bottom: 11 })
                  .backgroundColor('#EAF1FF')
                  .borderRadius(14)
              }
              .width('100%')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Column({ space: 8 }) {
              Text('体重')
                .fontSize(12)
                .fontColor('#4F6690')

              Row({ space: 8 }) {
                TextInput({ placeholder: '60', text: this.userProfile.weightKg })
                  .fontSize(16)
                  .fontColor(PRIMARY_TEXT_COLOR)
                  .height(46)
                  .layoutWeight(1)
                  .padding({ left: 12, right: 12 })
                  .backgroundColor('#F6F8FB')
                  .borderRadius(16)
                  .onChange((value: string) => {
                    this.updateProfileField('weightKg', value);
                  })

                Text('kg')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#D86C3D')
                  .padding({ left: 12, right: 12, top: 11, bottom: 11 })
                  .backgroundColor('#FFF1E8')
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
              .fontColor('#4F6690')

            Row({ space: 8 }) {
              TextInput({ placeholder: '24', text: this.userProfile.age })
                .fontSize(16)
                .fontColor(PRIMARY_TEXT_COLOR)
                .height(46)
                .layoutWeight(1)
                .padding({ left: 12, right: 12 })
                .backgroundColor('#F6F8FB')
                .borderRadius(16)
                .onChange((value: string) => {
                  this.updateProfileField('age', value);
                })

              Text('岁')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#2E8B57')
                .padding({ left: 12, right: 12, top: 11, bottom: 11 })
                .backgroundColor('#EAF5EE')
                .borderRadius(14)
            }
            .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')

          Column({ space: 8 }) {
            Text('性别')
              .fontSize(12)
              .fontColor('#4F6690')

            Row({ space: 10 }) {
              Button(GENDER_MALE)
                .layoutWeight(1)
                .height(42)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.isSelectedGender(GENDER_MALE) ? '#FFFFFF' : PRIMARY_TEXT_COLOR)
                .backgroundColor(this.isSelectedGender(GENDER_MALE) ? '#2F6FED' : '#EEF3FF')
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
                .backgroundColor(this.isSelectedGender(GENDER_FEMALE) ? '#D86C3D' : '#FFF1E8')
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
                .backgroundColor(this.isSelectedGender(GENDER_UNKNOWN) ? '#7D8794' : '#F2F4F7')
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
            .fontColor('#667085')

          Button('清空资料')
            .width('100%')
            .height(46)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#17324D')
            .backgroundColor('#EEF3FF')
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
        .backgroundColor('#F8EEDC')
        .borderRadius(24)

        Column({ space: 10 }) {
          Text('热量计算基础')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text(getCalorieRequirementText(this.userProfile))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#17324D')

          Text(getGenderSuggestion(this.userProfile))
            .fontSize(13)
            .lineHeight(20)
            .fontColor('#667085')

          Text('运动页采用常见公式估算消耗：MET × 3.5 × 体重(kg) ÷ 200 × 时长(分钟)。')
            .fontSize(12)
            .lineHeight(20)
            .fontColor(SECONDARY_TEXT_COLOR)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(18)
        .backgroundColor('#EAF1FF')
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
