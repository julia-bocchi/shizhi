import { PAGE_BACKGROUND_COLOR } from '../constants/AppTheme';
import { MainBottomNavigation } from '../components/MainBottomNavigation';
import {
  AI_TAB_INDEX,
  APP_TAB_ITEMS,
  EXERCISE_TAB_INDEX,
  FOOD_TAB_INDEX,
  HOME_TAB_INDEX,
  PROFILE_TAB_INDEX,
  RECORD_TAB_INDEX
} from '../models/TabItem';
import { HomeTabPage } from './home/HomeTabPage';
import { AiAssistantTabPage } from './assistant/AiAssistantTabPage';
import { ExerciseTabPage } from './exercise/ExerciseTabPage';
import { FoodTabPage } from './food/FoodTabPage';
import { RecordTabPage } from './record/RecordTabPage';
import { ProfileTabPage } from './profile/ProfileTabPage';
import { UserProfile, createEmptyUserProfile } from '../models/UserProfile';
import { deserializeUserProfile } from '../utils/ExerciseHelper';
import { EXERCISE_STORAGE_READY } from '../utils/ExerciseStorage';
import { DEFAULT_API_BASE_URL } from '../models/AuthSession';


@Entry
@Component
struct Index {
  @State currentTabIndex: number = HOME_TAB_INDEX;
  @StorageLink('userProfileText') userProfileText: string = '';
  @StorageLink('exercisePlanPickerVisible') exercisePlanPickerVisible: boolean = false;
  @StorageLink('apiBaseUrlText') apiBaseUrlText: string = '';
  @State userProfile: UserProfile = createEmptyUserProfile();

  // 系统返回键监听（标准、无报错）
  onBackPress(): boolean {
    // 如果当前在 AI 页面 → 回到主页，并拦截返回（不退出APP）
    if (this.currentTabIndex !== HOME_TAB_INDEX) {
      this.currentTabIndex = HOME_TAB_INDEX;
      return true; // 拦截系统默认行为
    }
    // 其他页面 → 正常退出
    return false;
  }

  aboutToAppear(): void {
    EXERCISE_STORAGE_READY;
    if (this.apiBaseUrlText.trim().length === 0) {
      this.apiBaseUrlText = DEFAULT_API_BASE_URL;
    }
    this.userProfile = deserializeUserProfile(this.userProfileText);

  }

  @Builder
  buildCurrentPage() {
    if (this.currentTabIndex === HOME_TAB_INDEX) {
      HomeTabPage({
        currentTabIndex: $currentTabIndex
      })
    } else if (this.currentTabIndex === AI_TAB_INDEX) {
      AiAssistantTabPage({
        currentTabIndex: $currentTabIndex,
        userProfile: $userProfile
      })
    } else if (this.currentTabIndex === EXERCISE_TAB_INDEX) {
      ExerciseTabPage({
        currentTabIndex: $currentTabIndex,
        userProfile: $userProfile
      })
    } else if (this.currentTabIndex === FOOD_TAB_INDEX) {
      FoodTabPage({
        currentTabIndex: $currentTabIndex
      })
    } else if (this.currentTabIndex === RECORD_TAB_INDEX) {
      RecordTabPage()
    } else if (this.currentTabIndex === PROFILE_TAB_INDEX) {
      ProfileTabPage({
        userProfile: $userProfile,
        userProfileText: $userProfileText
      })
    } else {
      HomeTabPage({
        currentTabIndex: $currentTabIndex
      })
    }
  }

  build() {
    Column() {
      Column() {
        this.buildCurrentPage()
      }
      .layoutWeight(1)
      .width('100%')
      if (this.currentTabIndex != AI_TAB_INDEX && !this.exercisePlanPickerVisible) {
        MainBottomNavigation({
          currentIndex: $currentTabIndex,
          items: APP_TAB_ITEMS
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PAGE_BACKGROUND_COLOR)
  }
}
