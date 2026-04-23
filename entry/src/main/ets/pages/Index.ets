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
import { isAuthSessionValid, resolveApiBaseUrl } from '../models/AuthSession';
import { deserializeAuthSession } from '../utils/AuthStorageHelper';
import { SyncRuntimeState, syncPendingOperations } from '../utils/SyncService';


@Entry
@Component
struct Index {
  @StorageLink('currentTabIndex') currentTabIndex: number = HOME_TAB_INDEX;
  @StorageLink('userProfileText') userProfileText: string = '';
  @StorageLink('exercisePlanPickerVisible') exercisePlanPickerVisible: boolean = false;
  @StorageLink('apiBaseUrlText') apiBaseUrlText: string = '';
  @StorageLink('authSessionText') authSessionText: string = '';
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
  @StorageLink('lastSyncAttemptText') lastSyncAttemptText: string = '';
  @StorageLink('lastSyncSuccessText') lastSyncSuccessText: string = '';
  @State userProfile: UserProfile = createEmptyUserProfile();

  private syncTimerId: number = -1;

  private buildSyncState(): SyncRuntimeState {
    return {
      apiBaseUrlText: this.apiBaseUrlText,
      authSessionText: this.authSessionText,
      userProfileText: this.userProfileText,
      weightRecordText: this.weightRecordText,
      customFoodOptionText: this.customFoodOptionText,
      foodPlanText: this.foodPlanText,
      savedCustomWorkoutText: this.savedCustomWorkoutText,
      workoutPlanText: this.workoutPlanText,
      workoutPlanMetaText: this.workoutPlanMetaText,
      workoutRecordText: this.workoutRecordText,
      pendingSyncQueueText: this.pendingSyncQueueText,
      foodRecommendationCacheText: this.foodRecommendationCacheText,
      exerciseRecommendationCacheText: this.exerciseRecommendationCacheText,
      currentEditingSavedWorkoutIdText: this.currentEditingSavedWorkoutIdText,
      currentExercisePlanIdText: this.currentExercisePlanIdText,
      lastSyncAttemptText: this.lastSyncAttemptText,
      lastSyncSuccessText: this.lastSyncSuccessText
    };
  }

  private applySyncState(nextState: SyncRuntimeState): void {
    this.userProfileText = nextState.userProfileText;
    this.weightRecordText = nextState.weightRecordText;
    this.customFoodOptionText = nextState.customFoodOptionText;
    this.foodPlanText = nextState.foodPlanText;
    this.savedCustomWorkoutText = nextState.savedCustomWorkoutText;
    this.workoutPlanText = nextState.workoutPlanText;
    this.workoutPlanMetaText = nextState.workoutPlanMetaText;
    this.workoutRecordText = nextState.workoutRecordText;
    this.pendingSyncQueueText = nextState.pendingSyncQueueText;
    this.foodRecommendationCacheText = nextState.foodRecommendationCacheText;
    this.exerciseRecommendationCacheText = nextState.exerciseRecommendationCacheText;
    this.currentEditingSavedWorkoutIdText = nextState.currentEditingSavedWorkoutIdText;
    this.currentExercisePlanIdText = nextState.currentExercisePlanIdText;
    this.lastSyncAttemptText = nextState.lastSyncAttemptText;
    this.lastSyncSuccessText = nextState.lastSyncSuccessText;
    this.userProfile = deserializeUserProfile(this.userProfileText);
  }

  private async flushPendingSync(): Promise<void> {
    let result = await syncPendingOperations(this.buildSyncState());
    this.applySyncState(result.state);
  }

  private startSyncTimer(): void {
    this.stopSyncTimer();
    this.syncTimerId = setInterval(() => {
      this.flushPendingSync();
    }, 60000);
  }

  private stopSyncTimer(): void {
    if (this.syncTimerId >= 0) {
      clearInterval(this.syncTimerId);
      this.syncTimerId = -1;
    }
  }

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
    this.apiBaseUrlText = resolveApiBaseUrl(this.apiBaseUrlText);
    this.userProfile = deserializeUserProfile(this.userProfileText);
    if (this.currentTabIndex === PROFILE_TAB_INDEX &&
      !isAuthSessionValid(deserializeAuthSession(this.authSessionText))) {
      this.currentTabIndex = HOME_TAB_INDEX;
    }
    this.flushPendingSync();
    this.startSyncTimer();
  }

  aboutToDisappear(): void {
    this.stopSyncTimer();
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
