import { PAGE_BACKGROUND_COLOR } from '../../constants/AppTheme';

// 首页内容暂时留空，先把页面切换框架搭起来，后续可以直接在这里扩展。
@Component
export struct HomeTabPage {
  build() {
    Column() {
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PAGE_BACKGROUND_COLOR)
  }
}
