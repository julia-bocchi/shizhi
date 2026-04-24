import {
  PAGE_BACKGROUND_COLOR,
  PRIMARY_TEXT_COLOR,
  SECONDARY_TEXT_COLOR,
  SURFACE_BACKGROUND_COLOR
} from '../../constants/AppTheme';
import { resolveApiBaseUrl } from '../../models/AuthSession';
import { HOME_TAB_INDEX } from '../../models/TabItem';
import { fetchUserProfile, loginWithPassword, registerWithPassword } from '../../utils/ApiService';
import { serializeUserProfile } from '../../utils/ExerciseHelper';

@Entry
@Component
struct LoginPage {
  @StorageLink('apiBaseUrlText') apiBaseUrlText: string = '';
  @StorageLink('authSessionText') authSessionText: string = '';
  @StorageLink('userProfileText') userProfileText: string = '';
  @StorageLink('currentTabIndex') currentTabIndex: number = HOME_TAB_INDEX;

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
      this.authSessionText = loginResult.authSessionText;
      let remoteProfile = await fetchUserProfile(this.apiBaseUrlText, loginResult.authSession);
      this.userProfileText = serializeUserProfile(remoteProfile);
      this.currentTabIndex = HOME_TAB_INDEX;
      this.password = '';
      this.loginNotice = '登录成功，正在返回首页。';
      this.goBack();
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
      this.authSessionText = registerResult.authSessionText;
      let remoteProfile = await fetchUserProfile(this.apiBaseUrlText, registerResult.authSession);
      this.userProfileText = serializeUserProfile(remoteProfile);
      this.currentTabIndex = HOME_TAB_INDEX;
      this.password = '';
      this.loginNotice = '注册成功，正在返回首页。';
      this.goBack();
    } catch (error) {
      this.loginNotice = '注册失败，请检查账号是否已存在后重试。';
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
