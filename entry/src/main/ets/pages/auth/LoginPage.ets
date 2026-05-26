import {
  PAGE_BACKGROUND_COLOR,
  PRIMARY_TEXT_COLOR,
  SECONDARY_TEXT_COLOR,
  SURFACE_BACKGROUND_COLOR
} from '../../constants/AppTheme';
import { resolveApiBaseUrl } from '../../models/AuthSession';
import { HOME_TAB_INDEX } from '../../models/TabItem';
import { LoginResult, loginWithPassword, registerWithPassword } from '../../utils/ApiService';
import {
  UserDataSessionState,
  createClearedUserDataSessionState,
  fetchLoginUserData
} from '../../utils/UserDataSessionHelper';

@Entry
@Component
struct LoginPage {
  @StorageLink('apiBaseUrlText') apiBaseUrlText: string = '';
  @StorageLink('authSessionText') authSessionText: string = '';
  @StorageLink('authTokenText') authTokenText: string = '';
  @StorageLink('authUserIdText') authUserIdText: string = '';
  @StorageLink('authUsernameText') authUsernameText: string = '';
  @StorageLink('currentTabIndex') currentTabIndex: number = HOME_TAB_INDEX;
  @StorageLink('userProfileText') userProfileText: string = '';
  @StorageLink('weightRecordText') weightRecordText: string = '';
  @StorageLink('customFoodOptionText') customFoodOptionText: string = '';
  @StorageLink('foodPlanText') foodPlanText: string = '';
  @StorageLink('savedCustomWorkoutText') savedCustomWorkoutText: string = '';
  @StorageLink('workoutPlanText') workoutPlanText: string = '';
  @StorageLink('workoutPlanMetaText') workoutPlanMetaText: string = '';
  @StorageLink('workoutRecordText') workoutRecordText: string = '';
  @StorageLink('pendingSyncQueueText') pendingSyncQueueText: string = '';
  @StorageLink('foodRecommendationCacheText') foodRecommendationCacheText: string = '';
  @StorageLink('exerciseRecommendationCacheText') exerciseRecommendationCacheText: string = '';
  @StorageLink('currentEditingSavedWorkoutIdText') currentEditingSavedWorkoutIdText: string = '';
  @StorageLink('currentExercisePlanIdText') currentExercisePlanIdText: string = '';
  @StorageLink('currentExerciseDraftText') currentExerciseDraftText: string = '';
  @StorageLink('currentExerciseProfileText') currentExerciseProfileText: string = '';
  @StorageLink('currentFoodPlanDateText') currentFoodPlanDateText: string = '';
  @StorageLink('currentFoodPlanMealTypeText') currentFoodPlanMealTypeText: string = '';
  @StorageLink('dailyFoodCalorieTargetText') dailyFoodCalorieTargetText: string = '2000';
  @StorageLink('dailyBriefingAiCacheText') dailyBriefingAiCacheText: string = '';
  @StorageLink('ttsAudioCacheText') ttsAudioCacheText: string = '';
  @StorageLink('weeklyPlanDraftConversationIdText') weeklyPlanDraftConversationIdText: string = '';
  @StorageLink('weeklyPlanDraftDateText') weeklyPlanDraftDateText: string = '';
  @StorageLink('assistantOpenConversationIdText') assistantOpenConversationIdText: string = '';
  @StorageLink('lastSyncAttemptText') lastSyncAttemptText: string = '';
  @StorageLink('lastSyncSuccessText') lastSyncSuccessText: string = '';
  @StorageLink('exercisePlanPickerVisible') exercisePlanPickerVisible: boolean = false;

  @State username: string = '';
  @State password: string = '';
  @State loginNotice: string = '登录成功后会自动返回首页。';
  @State authBusy: boolean = false;

  aboutToAppear(): void {
    this.apiBaseUrlText = resolveApiBaseUrl(this.apiBaseUrlText);
  }

  private goBack(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (error) {
      this.loginNotice = '返回失败，请重试。';
    }
  }

  private goHome(): void {
    try {
      this.getUIContext().getRouter().back();
      return;
    } catch (error) {
    }

    try {
      let routeTask: Promise<void> = this.getUIContext().getRouter().replaceUrl({
        url: 'pages/Index'
      });
      routeTask.catch(() => {
        this.loginNotice = '返回首页失败，请重试。';
      });
    } catch (error) {
      this.loginNotice = '返回首页失败，请重试。';
    }
  }

  private applyUserDataSessionState(state: UserDataSessionState): void {
    this.userProfileText = state.userProfileText;
    this.weightRecordText = state.weightRecordText;
    this.customFoodOptionText = state.customFoodOptionText;
    this.foodPlanText = state.foodPlanText;
    this.savedCustomWorkoutText = state.savedCustomWorkoutText;
    this.workoutPlanText = state.workoutPlanText;
    this.workoutPlanMetaText = state.workoutPlanMetaText;
    this.workoutRecordText = state.workoutRecordText;
    this.pendingSyncQueueText = state.pendingSyncQueueText;
    this.foodRecommendationCacheText = state.foodRecommendationCacheText;
    this.exerciseRecommendationCacheText = state.exerciseRecommendationCacheText;
    this.currentEditingSavedWorkoutIdText = state.currentEditingSavedWorkoutIdText;
    this.currentExercisePlanIdText = state.currentExercisePlanIdText;
    this.currentExerciseDraftText = state.currentExerciseDraftText;
    this.currentExerciseProfileText = state.currentExerciseProfileText;
    this.currentFoodPlanDateText = state.currentFoodPlanDateText;
    this.currentFoodPlanMealTypeText = state.currentFoodPlanMealTypeText;
    this.dailyFoodCalorieTargetText = state.dailyFoodCalorieTargetText;
    this.dailyBriefingAiCacheText = state.dailyBriefingAiCacheText;
    this.ttsAudioCacheText = state.ttsAudioCacheText;
    this.weeklyPlanDraftConversationIdText = state.weeklyPlanDraftConversationIdText;
    this.weeklyPlanDraftDateText = state.weeklyPlanDraftDateText;
    this.assistantOpenConversationIdText = state.assistantOpenConversationIdText;
    this.lastSyncAttemptText = state.lastSyncAttemptText;
    this.lastSyncSuccessText = state.lastSyncSuccessText;
    this.exercisePlanPickerVisible = state.exercisePlanPickerVisible;
  }

  private async completeAuthSuccess(result: LoginResult, noticeText: string): Promise<void> {
    this.applyUserDataSessionState(createClearedUserDataSessionState());
    this.authSessionText = result.authSessionText;
    this.authTokenText = result.authSession.token;
    this.authUserIdText = `${result.authSession.userId}`;
    this.authUsernameText = result.authSession.username;
    this.currentTabIndex = HOME_TAB_INDEX;
    this.password = '';
    this.loginNotice = '登录成功，正在同步用户数据。';
    try {
      let remoteUserData = await fetchLoginUserData(this.apiBaseUrlText, result.authSession);
      this.applyUserDataSessionState(remoteUserData);
      this.loginNotice = noticeText;
    } catch (error) {
      this.loginNotice = '登录成功，但用户数据同步失败，请稍后进入页面刷新。';
    }
    this.goHome();
  }

  private async handleLogin(): Promise<void> {
    if (this.authBusy) {
      return;
    }
    this.apiBaseUrlText = resolveApiBaseUrl(this.apiBaseUrlText);
    if (this.username.trim().length === 0) {
      this.loginNotice = '请先填写账号。';
      return;
    }
    if (this.password.length === 0) {
      this.loginNotice = '请先填写密码。';
      return;
    }

    this.authBusy = true;
    try {
      let loginResult = await loginWithPassword(this.apiBaseUrlText, this.username, this.password);
      await this.completeAuthSuccess(loginResult, '登录成功，已同步最近一周数据，正在返回首页。');
    } catch (error) {
      this.loginNotice = '登录失败，请检查账号、密码或服务状态后重试。';
    } finally {
      this.authBusy = false;
    }
  }

  private async handleRegister(): Promise<void> {
    if (this.authBusy) {
      return;
    }
    this.apiBaseUrlText = resolveApiBaseUrl(this.apiBaseUrlText);
    if (this.username.trim().length === 0) {
      this.loginNotice = '请先填写账号。';
      return;
    }
    if (this.password.length === 0) {
      this.loginNotice = '请先填写密码。';
      return;
    }

    this.authBusy = true;
    try {
      let registerResult = await registerWithPassword(this.apiBaseUrlText, this.username, this.password);
      await this.completeAuthSuccess(registerResult, '注册成功，已同步用户数据，正在返回首页。');
    } catch (error) {
      this.loginNotice = '注册失败，请检查账号是否已存在或服务状态后重试。';
    } finally {
      this.authBusy = false;
    }
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Column({ space: 6 }) {
          Text('登录')
            .fontSize(30)
            .fontWeight(FontWeight.Bolder)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text('未登录时点击“我的”会进入这里，登录成功后自动返回首页。')
            .fontSize(14)
            .fontColor(SECONDARY_TEXT_COLOR)
            .lineHeight(22)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')

        Column({ space: 10 }) {
          Text('账号登录')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')

          Text('输入账号和密码后即可登录，未注册可以直接创建账号。')
            .fontSize(13)
            .lineHeight(20)
            .fontColor('#DCE8FF')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(18)
        .backgroundColor('#0F6BFF')
        .borderRadius(24)

        Column({ space: 14 }) {
          Column({ space: 8 }) {
            Text('账号')
              .fontSize(12)
              .fontColor('#5373A6')

            TextInput({ placeholder: 'demo', text: this.username })
              .fontSize(15)
              .fontColor(PRIMARY_TEXT_COLOR)
              .height(46)
              .width('100%')
              .padding({ left: 12, right: 12 })
              .backgroundColor('#F5F8FF')
              .borderRadius(16)
              .onChange((value: string) => {
                this.username = value;
              })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')

          Column({ space: 8 }) {
            Text('密码')
              .fontSize(12)
              .fontColor('#5373A6')

            TextInput({ placeholder: '123456', text: this.password })
              .fontSize(15)
              .fontColor(PRIMARY_TEXT_COLOR)
              .height(46)
              .width('100%')
              .padding({ left: 12, right: 12 })
              .backgroundColor('#F5F8FF')
              .borderRadius(16)
              .onChange((value: string) => {
                this.password = value;
              })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')

          Button(this.authBusy ? '登录中...' : '登录')
            .width('100%')
            .height(46)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .backgroundColor('#0F6BFF')
            .borderRadius(18)
            .onClick(() => {
              this.handleLogin();
            })

          Button(this.authBusy ? '处理中...' : '注册并登录')
            .width('100%')
            .height(44)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#0F6BFF')
            .backgroundColor('#EAF2FF')
            .borderRadius(18)
            .onClick(() => {
              this.handleRegister();
            })

          Button('取消')
            .width('100%')
            .height(44)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#0F6BFF')
            .backgroundColor('#F4F7FD')
            .borderRadius(18)
            .onClick(() => {
              this.goBack();
            })

          Text(this.loginNotice)
            .fontSize(13)
            .lineHeight(20)
            .fontColor(SECONDARY_TEXT_COLOR)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(18)
        .backgroundColor(SURFACE_BACKGROUND_COLOR)
        .borderRadius(24)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 24, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PAGE_BACKGROUND_COLOR)
  }
}
