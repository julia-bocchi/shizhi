import {
  ACTIVE_TAB_COLOR,
  ACTIVE_TAB_SURFACE_COLOR,
  INACTIVE_TAB_COLOR,
  NAV_BACKGROUND_COLOR,
  NAV_BORDER_COLOR
} from '../constants/AppTheme';
import { BottomTabItem } from '../models/TabItem';
import { deserializeAuthSession } from '../utils/AuthStorageHelper';
import { isAuthSessionValid } from '../models/AuthSession';

@Component
export struct MainBottomNavigation {
  @Link currentIndex: number;
  @Prop items: BottomTabItem[] = [];
  @StorageLink('authSessionText') authSessionText: string = '';

  private isActive(item: BottomTabItem): boolean {
    return item.index === this.currentIndex;
  }

  private openLoginPage(): void {
    try {
      let routeTask: Promise<void> = this.getUIContext().getRouter().pushUrl({
        url: 'pages/auth/LoginPage'
      });
      routeTask.catch(() => {
      });
    } catch (error) {
    }
  }

  build() {
    Column() {
      Row() {
        ForEach(this.items, (item: BottomTabItem) => {
          Column({ space: 8 }) {
            Text(item.icon)
              .fontSize(item.icon.length > 1 ? 16 : 20)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.isActive(item) ? ACTIVE_TAB_COLOR : INACTIVE_TAB_COLOR)
              .width(38)
              .height(38)
              .textAlign(TextAlign.Center)
              .padding({ top: 8, bottom: 8 })
              .backgroundColor(this.isActive(item) ? ACTIVE_TAB_SURFACE_COLOR : '#00000000')
              .borderRadius(19)

            Text(item.label)
              .fontSize(12)
              .fontWeight(this.isActive(item) ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(this.isActive(item) ? ACTIVE_TAB_COLOR : INACTIVE_TAB_COLOR)

            Text('')
              .width(this.isActive(item) ? 18 : 8)
              .height(4)
              .backgroundColor(this.isActive(item) ? ACTIVE_TAB_COLOR : '#00000000')
              .borderRadius(999)
          }
          .layoutWeight(1)
          .padding({ top: 12, bottom: 12 })
          .alignItems(HorizontalAlign.Center)
          .onClick(() => {
            if (item.id === 'profile' && !isAuthSessionValid(deserializeAuthSession(this.authSessionText))) {
              this.openLoginPage();
              return;
            }
            this.currentIndex = item.index;
          })
        }, (item: BottomTabItem) => item.id)
      }
      .width('100%')
    }
    .width('100%')
    .backgroundColor(NAV_BACKGROUND_COLOR)
    .border({
      color: NAV_BORDER_COLOR,
      width: {
        top: 1
      }
    })
    .padding({ left: 12, right: 12, top: 8, bottom: 12 })
  }
}
