import {
  ACTIVE_TAB_COLOR,
  ACTIVE_TAB_SURFACE_COLOR,
  INACTIVE_TAB_COLOR,
  NAV_BACKGROUND_COLOR,
  NAV_BORDER_COLOR
} from '../constants/AppTheme';
import { BottomTabItem } from '../models/TabItem';

@Component
export struct MainBottomNavigation {
  @Link currentIndex: number;
  @Prop items: BottomTabItem[] = [];

  private isActive(item: BottomTabItem): boolean {
    return item.index === this.currentIndex;
  }

  build() {
    Column() {
      Row() {
        ForEach(this.items, (item: BottomTabItem) => {
          Column({ space: 8 }) {
            Text(item.icon)
              .fontSize(20)
              .fontWeight(FontWeight.SemiBold)
              .fontColor(this.isActive(item) ? ACTIVE_TAB_COLOR : INACTIVE_TAB_COLOR)
              .width(38)
              .height(38)
              .textAlign(TextAlign.Center)
              .padding({ top: 8, bottom: 8 })
              .backgroundColor(this.isActive(item) ? ACTIVE_TAB_SURFACE_COLOR : '#00000000')
              .borderRadius(19)

            Text(item.label)
              .fontSize(13)
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
    .padding({ left: 20, right: 20, top: 8, bottom: 12 })
  }
}
