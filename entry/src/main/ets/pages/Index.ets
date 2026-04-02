import { PAGE_BACKGROUND_COLOR } from '../constants/AppTheme';
import { MainBottomNavigation } from '../components/MainBottomNavigation';
import { APP_TAB_ITEMS, HOME_TAB_INDEX } from '../models/TabItem';
import { HomeTabPage } from './home/HomeTabPage';
import { RecordTabPage } from './record/RecordTabPage';

@Entry
@Component
struct Index {
  @State currentTabIndex: number = HOME_TAB_INDEX;

  @Builder
  buildCurrentPage() {
    if (this.currentTabIndex === HOME_TAB_INDEX) {
      HomeTabPage()
    } else {
      RecordTabPage()
    }
  }

  build() {
    Column() {
      Column() {
        this.buildCurrentPage()
      }
      .layoutWeight(1)
      .width('100%')

      MainBottomNavigation({
        currentIndex: $currentTabIndex,
        items: APP_TAB_ITEMS
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PAGE_BACKGROUND_COLOR)
  }
}
