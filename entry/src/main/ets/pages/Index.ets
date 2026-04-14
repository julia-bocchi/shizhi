import { PAGE_BACKGROUND_COLOR } from '../constants/AppTheme';
import { MainBottomNavigation } from '../components/MainBottomNavigation';
import {
  APP_TAB_ITEMS,
  EXERCISE_TAB_INDEX,
  HOME_TAB_INDEX,
  PROFILE_TAB_INDEX
} from '../models/TabItem';
import { HomeTabPage } from './home/HomeTabPage';
import { ExerciseTabPage } from './exercise/ExerciseTabPage';
import { RecordTabPage } from './record/RecordTabPage';
import { ProfileTabPage } from './profile/ProfileTabPage';
import { UserProfile, createEmptyUserProfile } from '../models/UserProfile';
import { deserializeUserProfile } from '../utils/ExerciseHelper';
import { EXERCISE_STORAGE_READY } from '../utils/ExerciseStorage';

@Entry
@Component
struct Index {
  @State currentTabIndex: number = HOME_TAB_INDEX;
  @StorageLink('userProfileText') userProfileText: string = '';
  @State userProfile: UserProfile = createEmptyUserProfile();

  aboutToAppear(): void {
    EXERCISE_STORAGE_READY;
    this.userProfile = deserializeUserProfile(this.userProfileText);
  }

  @Builder
  buildCurrentPage() {
    if (this.currentTabIndex === HOME_TAB_INDEX) {
      HomeTabPage({
        currentTabIndex: $currentTabIndex,
        userProfile: $userProfile
      })
    } else if (this.currentTabIndex === EXERCISE_TAB_INDEX) {
      ExerciseTabPage({
        currentTabIndex: $currentTabIndex,
        userProfile: $userProfile
      })
    } else if (this.currentTabIndex === PROFILE_TAB_INDEX) {
      ProfileTabPage({
        userProfile: $userProfile,
        userProfileText: $userProfileText
      })
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
