import {
  PAGE_BACKGROUND_COLOR,
  PRIMARY_TEXT_COLOR,
  SECONDARY_TEXT_COLOR,
  SURFACE_BACKGROUND_COLOR
} from '../../constants/AppTheme';
import { AiAssistantConfig, getDefaultAiApiEndpoint, getDefaultAiApiKey, getDefaultAiModel } from '../../models/AiAssistant';
import { RecommendationExerciseCandidate, RecommendationFoodCandidate } from '../../models/AiRecommendation';
import { EXERCISE_OPTIONS } from '../../models/ExerciseOption';
import { FoodPlanItem } from '../../models/FoodPlan';
import { FoodOption, PRESET_FOOD_OPTIONS } from '../../models/FoodOption';
import {
  buildDefaultCustomFoodImage,
  createLocalCustomFoodOptionId,
  createFoodPlanItem,
  deserializeCustomFoodOptions,
  deserializeFoodPlans,
  getFoodMealLabel,
  serializeCustomFoodOptions,
  serializeFoodPlans,
  upsertCustomFoodOptionByIdentity
} from '../../utils/FoodHelper';
import {
  getFoodVisualDescriptor,
  isBuiltinFoodImage,
  resolveFoodOptionImage,
  resolveFoodPlanImage
} from '../../utils/FoodVisualHelper';
import { deserializeWeightRecords, formatDate } from '../../utils/WeightRecordHelper';
import { EXERCISE_STORAGE_READY } from '../../utils/ExerciseStorage';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { DEFAULT_API_BASE_URL, isAuthSessionValid } from '../../models/AuthSession';
import { deserializeAuthSession } from '../../utils/AuthStorageHelper';
import { deserializeSavedCustomWorkouts, deserializeUserProfile, deserializeWorkoutRecords } from '../../utils/ExerciseHelper';
import {
  fetchFoodOptions,
  fetchFoodPlans
} from '../../utils/ApiService';
import { requestAiRecommendations } from '../../utils/AiRecommendationHelper';
import {
  getRecommendationRank,
  getRecommendationScore,
  serializeRecommendationCache
} from '../../utils/RecommendationStorageHelper';
import {
  createFoodMealReplaceOperation,
  createFoodOptionUpsertOperation,
  hasPendingSyncOperation,
} from '../../utils/SyncQueueHelper';
import { SyncRuntimeState, syncOperationNowOrQueue, syncPendingOperations } from '../../utils/SyncService';
import { FoodDraftSelectionItemPayload } from '../../models/SyncPayload';

interface FoodChoiceCardItem {
  id: string;
  type: string;
  option: FoodOption;
}

interface FoodDraftSelectionItem {
  foodId: string;
  option: FoodOption;
  count: number;
}

@Entry
@Component
struct FoodSelectionPage {
  @StorageLink('customFoodOptionText') customFoodOptionText: string = '';
  @StorageLink('foodPlanText') foodPlanText: string = '';
  @StorageLink('currentFoodPlanDateText') currentFoodPlanDateText: string = '';
  @StorageLink('currentFoodPlanMealTypeText') currentFoodPlanMealTypeText: string = '';
  @StorageLink('apiBaseUrlText') apiBaseUrlText: string = '';
  @StorageLink('authSessionText') authSessionText: string = '';
  @StorageLink('userProfileText') userProfileText: string = '';
  @StorageLink('weightRecordText') weightRecordText: string = '';
  @StorageLink('workoutRecordText') workoutRecordText: string = '';
  @StorageLink('savedCustomWorkoutText') savedCustomWorkoutText: string = '';
  @StorageLink('workoutPlanText') workoutPlanText: string = '';
  @StorageLink('workoutPlanMetaText') workoutPlanMetaText: string = '';
  @StorageLink('aiApiEndpointText') aiApiEndpointText: string = '';
  @StorageLink('aiApiKeyText') aiApiKeyText: string = '';
  @StorageLink('aiModelText') aiModelText: string = '';
  @StorageLink('dailyFoodCalorieTargetText') dailyFoodCalorieTargetText: string = '2000';
  @StorageLink('pendingSyncQueueText') pendingSyncQueueText: string = '';
  @StorageLink('foodRecommendationCacheText') foodRecommendationCacheText: string = '';
  @StorageLink('exerciseRecommendationCacheText') exerciseRecommendationCacheText: string = '';
  @StorageLink('currentEditingSavedWorkoutIdText') currentEditingSavedWorkoutIdText: string = '';
  @StorageLink('currentExercisePlanIdText') currentExercisePlanIdText: string = '';
  @StorageLink('lastSyncAttemptText') lastSyncAttemptText: string = '';
  @StorageLink('lastSyncSuccessText') lastSyncSuccessText: string = '';

  @State customFoodOptions: FoodOption[] = [];
  @State foodPlans: FoodPlanItem[] = [];
  @State draftSelections: FoodDraftSelectionItem[] = [];
  @State selectedDate: string = formatDate(new Date());
  @State selectedMealType: string = 'breakfast';
  @State planNotesInput: string = '';
  @State customSheetVisible: boolean = false;
  @State quantitySheetVisible: boolean = false;
  @State customFoodName: string = '';
  @State customFoodCalories: string = '';
  @State customFoodServing: string = '';
  @State customFoodDescription: string = '';
  @State customFoodImage: string = '';
  @State pageNotice: string = '点击食物卡片可加入待保存清单，点底部栏可调整数量。';
  @State recommendationBusy: boolean = false;

  private getAiConfig(): AiAssistantConfig {
    if (this.aiApiEndpointText.trim().length === 0) {
      this.aiApiEndpointText = getDefaultAiApiEndpoint();
    }
    if (this.aiModelText.trim().length === 0) {
      this.aiModelText = getDefaultAiModel();
    }
    if (this.aiApiKeyText.trim().length === 0) {
      this.aiApiKeyText = getDefaultAiApiKey();
    }
    return {
      apiEndpoint: this.aiApiEndpointText,
      apiKey: this.aiApiKeyText,
      model: this.aiModelText
    };
  }

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
  }

  private async flushPendingSync(): Promise<void> {
    let result = await syncPendingOperations(this.buildSyncState());
    this.applySyncState(result.state);
    this.customFoodOptions = deserializeCustomFoodOptions(this.customFoodOptionText);
    this.foodPlans = deserializeFoodPlans(this.foodPlanText);
    if (result.syncedCount > 0) {
      this.initializeDraftSelections();
      this.pageNotice = '本地数据已自动同步。';
    } else if (result.lastErrorMessage.trim().length > 0) {
      this.pageNotice = '已保存到本地，联网后会自动同步。';
    }
  }

  private getDailyFoodCalorieTarget(): number {
    let targetValue = Number(this.dailyFoodCalorieTargetText.trim());
    if (isNaN(targetValue) || targetValue <= 0) {
      return 2000;
    }
    return targetValue;
  }

  private getRecommendationFoodCandidates(): RecommendationFoodCandidate[] {
    let result: RecommendationFoodCandidate[] = [];
    let options = this.getSortedFoodOptions(false);
    for (let index = 0; index < options.length; index++) {
      result.push({
        id: options[index].id,
        name: options[index].name,
        description: options[index].description,
        mealSuggestion: options[index].mealSuggestion,
        calories: options[index].calories,
        serving: options[index].serving
      });
    }
    return result;
  }

  private getRecommendationExerciseCandidates(): RecommendationExerciseCandidate[] {
    let result: RecommendationExerciseCandidate[] = [];
    for (let index = 0; index < EXERCISE_OPTIONS.length; index++) {
      if (EXERCISE_OPTIONS[index].id === 'custom') {
        continue;
      }
      result.push({
        id: `exercise:${EXERCISE_OPTIONS[index].id}`,
        name: EXERCISE_OPTIONS[index].name,
        description: EXERCISE_OPTIONS[index].description,
        category: 'preset'
      });
    }
    let savedWorkouts = deserializeSavedCustomWorkouts(this.savedCustomWorkoutText);
    for (let index = 0; index < savedWorkouts.length; index++) {
      result.push({
        id: `saved:${savedWorkouts[index].id}`,
        name: savedWorkouts[index].name,
        description: '自定义训练模板',
        category: 'saved_template'
      });
    }
    return result;
  }

  private isFoodAiTopRecommendation(foodId: string): boolean {
    let rankValue = getRecommendationRank(this.foodRecommendationCacheText, foodId);
    return rankValue >= 0 && rankValue < 3;
  }

  private async refreshAiRecommendations(): Promise<void> {
    if (this.recommendationBusy) {
      return;
    }
    this.recommendationBusy = true;
    this.pageNotice = 'AI 正在重新整理食物和运动推荐。';
    try {
      let response = await requestAiRecommendations(this.getAiConfig(), {
        profile: deserializeUserProfile(this.userProfileText),
        weightRecords: deserializeWeightRecords(this.weightRecordText),
        workoutRecords: deserializeWorkoutRecords(this.workoutRecordText),
        dailyFoodCalorieTarget: this.getDailyFoodCalorieTarget(),
        foodCandidates: this.getRecommendationFoodCandidates(),
        exerciseCandidates: this.getRecommendationExerciseCandidates()
      });
      this.foodRecommendationCacheText = serializeRecommendationCache({
        updatedAt: `${Date.now()}`,
        reply: response.reply,
        items: response.foodRankings
      });
      this.exerciseRecommendationCacheText = serializeRecommendationCache({
        updatedAt: `${Date.now()}`,
        reply: response.reply,
        items: response.exerciseRankings
      });
      this.pageNotice = response.reply.trim().length > 0 ? response.reply : 'AI 推荐已更新。';
    } catch (error) {
      this.pageNotice = `${error}`;
    } finally {
      this.recommendationBusy = false;
    }
  }

  aboutToAppear(): void {
    EXERCISE_STORAGE_READY;
    if (this.apiBaseUrlText.trim().length === 0) {
      this.apiBaseUrlText = DEFAULT_API_BASE_URL;
    }
    this.customFoodOptions = deserializeCustomFoodOptions(this.customFoodOptionText);
    this.foodPlans = deserializeFoodPlans(this.foodPlanText);
    if (this.currentFoodPlanDateText.trim().length > 0) {
      this.selectedDate = this.currentFoodPlanDateText;
    } else {
      this.currentFoodPlanDateText = this.selectedDate;
    }
    if (this.currentFoodPlanMealTypeText.trim().length > 0) {
      this.selectedMealType = this.currentFoodPlanMealTypeText;
    }
    this.initializeDraftSelections();
    this.flushPendingSync().then(() => {
      this.syncRemoteFoodData();
    });
  }

  private saveFoodPlans(nextPlans: FoodPlanItem[]): void {
    this.foodPlans = nextPlans;
    this.foodPlanText = serializeFoodPlans(nextPlans);
  }

  private saveCustomFoodOptions(nextOptions: FoodOption[]): void {
    this.customFoodOptions = nextOptions;
    this.customFoodOptionText = serializeCustomFoodOptions(nextOptions);
  }

  private async syncRemoteFoodData(): Promise<void> {
    await this.flushPendingSync();
    if (hasPendingSyncOperation(this.pendingSyncQueueText, 'food_option') ||
      hasPendingSyncOperation(this.pendingSyncQueueText, 'food_meal')) {
      return;
    }
    let authSession = deserializeAuthSession(this.authSessionText);
    if (!isAuthSessionValid(authSession)) {
      return;
    }
    try {
      let fields = this.selectedDate.split('-');
      let year = Number(fields[0]);
      let month = Number(fields[1]) - 1;
      let rangeStart = formatDate(new Date(year, month, 1));
      let rangeEnd = formatDate(new Date(year, month + 1, 0));
      let remoteOptions = await fetchFoodOptions(this.apiBaseUrlText, authSession);
      let mergedOptions = this.customFoodOptions.slice();
      for (let index = 0; index < remoteOptions.length; index++) {
        let hasMatched = false;
        for (let optionIndex = 0; optionIndex < mergedOptions.length; optionIndex++) {
          if (mergedOptions[optionIndex].id === remoteOptions[index].id) {
            mergedOptions[optionIndex] = remoteOptions[index];
            hasMatched = true;
            break;
          }
        }
        if (!hasMatched) {
          mergedOptions.push(remoteOptions[index]);
        }
      }
      this.customFoodOptions = mergedOptions;
      this.customFoodOptionText = serializeCustomFoodOptions(mergedOptions);
      this.foodPlans = await fetchFoodPlans(this.apiBaseUrlText, authSession, rangeStart, rangeEnd);
      this.foodPlanText = serializeFoodPlans(this.foodPlans);
      this.initializeDraftSelections();
    } catch (error) {
    }
  }

  private goBack(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (error) {
      this.pageNotice = '返回失败，请重试。';
    }
  }

  private formatFriendlyDate(dateText: string): string {
    let fields: string[] = dateText.split('-');
    if (fields.length < 3) {
      return dateText;
    }
    return `${fields[0]}年${Number(fields[1])}月${Number(fields[2])}日`;
  }

  private getMealAccentColor(): string {
    if (this.selectedMealType === 'breakfast') {
      return '#F59E0B';
    }
    if (this.selectedMealType === 'lunch') {
      return '#10B981';
    }
    if (this.selectedMealType === 'dinner') {
      return '#0F6BFF';
    }
    return '#7B61FF';
  }

  private getMealSurfaceColor(): string {
    if (this.selectedMealType === 'breakfast') {
      return '#FFF7E8';
    }
    if (this.selectedMealType === 'lunch') {
      return '#EDFDF5';
    }
    if (this.selectedMealType === 'dinner') {
      return '#EEF4FF';
    }
    return '#F5EEFF';
  }

  private getCurrentMealPlans(): FoodPlanItem[] {
    let result: FoodPlanItem[] = [];
    for (let index = 0; index < this.foodPlans.length; index++) {
      if (this.foodPlans[index].date === this.selectedDate && this.foodPlans[index].mealType === this.selectedMealType) {
        result.push(this.foodPlans[index]);
      }
    }
    return result;
  }

  private buildOptionFromPlan(plan: FoodPlanItem): FoodOption {
    return {
      id: plan.foodId,
      name: plan.name,
      description: plan.description,
      calories: plan.calories,
      serving: plan.serving,
      mealSuggestion: getFoodMealLabel(plan.mealType),
      image: resolveFoodPlanImage(plan),
      accentColor: plan.accentColor
    };
  }

  private initializeDraftSelections(): void {
    let mealPlans: FoodPlanItem[] = this.getCurrentMealPlans();
    let nextDrafts: FoodDraftSelectionItem[] = [];
    let defaultNotes: string = '';

    for (let index = 0; index < mealPlans.length; index++) {
      if (defaultNotes.length === 0 && mealPlans[index].notes.trim().length > 0) {
        defaultNotes = mealPlans[index].notes.trim();
      }

      let foundIndex: number = -1;
      for (let draftIndex = 0; draftIndex < nextDrafts.length; draftIndex++) {
        if (nextDrafts[draftIndex].foodId === mealPlans[index].foodId) {
          foundIndex = draftIndex;
          break;
        }
      }

      if (foundIndex >= 0) {
        nextDrafts[foundIndex] = {
          foodId: nextDrafts[foundIndex].foodId,
          option: nextDrafts[foundIndex].option,
          count: nextDrafts[foundIndex].count + 1
        };
      } else {
        nextDrafts.push({
          foodId: mealPlans[index].foodId,
          option: this.buildOptionFromPlan(mealPlans[index]),
          count: 1
        });
      }
    }

    this.draftSelections = nextDrafts;
    if (defaultNotes.length > 0) {
      this.planNotesInput = defaultNotes;
    }
    this.pageNotice = mealPlans.length > 0
      ? '已载入当前餐次已保存的食物，调整完成后记得点击底部按钮确认保存。'
      : '点击食物卡片可加入待保存清单，点底部栏可调整数量。';
  }

  private findDraftSelectionIndex(foodId: string): number {
    for (let index = 0; index < this.draftSelections.length; index++) {
      if (this.draftSelections[index].foodId === foodId) {
        return index;
      }
    }
    return -1;
  }

  private getDraftSelectionCount(foodId: string): number {
    let draftIndex: number = this.findDraftSelectionIndex(foodId);
    if (draftIndex < 0) {
      return 0;
    }
    return this.draftSelections[draftIndex].count;
  }

  private getDraftSelectionSubtotal(foodId: string): number {
    let draftIndex: number = this.findDraftSelectionIndex(foodId);
    if (draftIndex < 0) {
      return 0;
    }
    return this.draftSelections[draftIndex].option.calories * this.draftSelections[draftIndex].count;
  }

  private getDraftActionHint(foodId: string): string {
    return this.getDraftSelectionCount(foodId) > 0 ? '点击继续增加数量' : '点击加入待保存清单';
  }

  private getDraftSelectedCount(): number {
    let totalCount: number = 0;
    for (let index = 0; index < this.draftSelections.length; index++) {
      totalCount += this.draftSelections[index].count;
    }
    return totalCount;
  }

  private getDraftSelectedCalories(): number {
    let totalCalories: number = 0;
    for (let index = 0; index < this.draftSelections.length; index++) {
      totalCalories += this.draftSelections[index].option.calories * this.draftSelections[index].count;
    }
    return totalCalories;
  }

  private getSavedMealSummaryText(): string {
    let savedCount: number = this.getCurrentMealPlans().length;
    if (savedCount === 0) {
      return '当前餐次还没有保存内容，确认按钮会把底部清单保存到今天。';
    }
    return `当前餐次已保存 ${savedCount} 份，重新确认后会覆盖本餐次内容。`;
  }

  private shouldShowClearAction(): boolean {
    return this.getDraftSelectedCount() === 0 && this.getCurrentMealPlans().length > 0;
  }

  private canOpenQuantitySheet(): boolean {
    return this.getDraftSelectedCount() > 0 || this.getCurrentMealPlans().length > 0;
  }

  private increaseDraftSelection(option: FoodOption): void {
    let nextDrafts: FoodDraftSelectionItem[] = this.draftSelections.slice();
    let draftIndex: number = this.findDraftSelectionIndex(option.id);
    if (draftIndex >= 0) {
      nextDrafts[draftIndex] = {
        foodId: nextDrafts[draftIndex].foodId,
        option: nextDrafts[draftIndex].option,
        count: nextDrafts[draftIndex].count + 1
      };
    } else {
      nextDrafts.unshift({
        foodId: option.id,
        option: option,
        count: 1
      });
    }
    this.draftSelections = nextDrafts;
    this.pageNotice = `已选择 ${option.name}，当前待保存 ${this.getDraftSelectedCount()} 份。`;
  }

  private setDraftSelectionCount(option: FoodOption, nextCount: number): void {
    if (nextCount <= 0) {
      this.decreaseDraftSelection(option.id);
      return;
    }

    let nextDrafts: FoodDraftSelectionItem[] = [];
    let hasMatched: boolean = false;
    for (let index = 0; index < this.draftSelections.length; index++) {
      if (this.draftSelections[index].foodId === option.id) {
        nextDrafts.push({
          foodId: option.id,
          option: option,
          count: nextCount
        });
        hasMatched = true;
      } else {
        nextDrafts.push(this.draftSelections[index]);
      }
    }

    if (!hasMatched) {
      nextDrafts.unshift({
        foodId: option.id,
        option: option,
        count: nextCount
      });
    }
    this.draftSelections = nextDrafts;
    this.pageNotice = `已将 ${option.name} 调整为 ${nextCount} 份。`;
  }

  private decreaseDraftSelection(foodId: string): void {
    let nextDrafts: FoodDraftSelectionItem[] = [];
    for (let index = 0; index < this.draftSelections.length; index++) {
      if (this.draftSelections[index].foodId !== foodId) {
        nextDrafts.push(this.draftSelections[index]);
        continue;
      }

      if (this.draftSelections[index].count > 1) {
        nextDrafts.push({
          foodId: this.draftSelections[index].foodId,
          option: this.draftSelections[index].option,
          count: this.draftSelections[index].count - 1
        });
      }
    }
    this.draftSelections = nextDrafts;
    if (nextDrafts.length === 0 && this.getCurrentMealPlans().length === 0) {
      this.pageNotice = '待保存清单已清空。';
    } else if (nextDrafts.length === 0) {
      this.pageNotice = '待保存清单已清空，点击确认后会清空当前餐次。';
    }
  }

  private openCustomFoodSheet(): void {
    this.quantitySheetVisible = false;
    this.customSheetVisible = true;
  }

  private closeCustomFoodSheet(): void {
    this.customSheetVisible = false;
  }

  private openQuantitySheet(): void {
    if (!this.canOpenQuantitySheet()) {
      this.pageNotice = '先选至少一种食物，再来调整数量。';
      return;
    }
    this.customSheetVisible = false;
    this.quantitySheetVisible = true;
  }

  private closeQuantitySheet(): void {
    this.quantitySheetVisible = false;
  }

  private async pickCustomFoodImage(): Promise<void> {
    try {
      let photoPicker = new photoAccessHelper.PhotoViewPicker();
      let pickerOptions = new photoAccessHelper.PhotoSelectOptions();
      pickerOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      pickerOptions.maxSelectNumber = 1;
      let result = await photoPicker.select(pickerOptions);
      if (result.photoUris && result.photoUris.length > 0) {
        this.customFoodImage = result.photoUris[0];
        this.pageNotice = '已选择相册图片。';
      }
    } catch (error) {
      this.pageNotice = '选择相册图片失败，请重试。';
    }
  }

  private clearCustomFoodForm(): void {
    this.customFoodName = '';
    this.customFoodCalories = '';
    this.customFoodServing = '';
    this.customFoodDescription = '';
    this.customFoodImage = '';
  }

  private getDraftSelectionPayloads(): FoodDraftSelectionItemPayload[] {
    let result: FoodDraftSelectionItemPayload[] = [];
    for (let index = 0; index < this.draftSelections.length; index++) {
      result.push({
        foodId: this.draftSelections[index].option.id,
        count: this.draftSelections[index].count
      });
    }
    return result;
  }

  private async saveCustomFoodCard(addToMeal: boolean): Promise<void> {
    let name: string = this.customFoodName.trim();
    let serving: string = this.customFoodServing.trim();
    let caloriesValue: number = Number(this.customFoodCalories.trim());

    if (name.length === 0) {
      this.pageNotice = '请先填写食物名称。';
      return;
    }
    if (isNaN(caloriesValue) || caloriesValue <= 0) {
      this.pageNotice = '请填写有效热量，例如 320。';
      return;
    }
    if (serving.length === 0) {
      this.pageNotice = '请填写份量，例如 1 份、150 g。';
      return;
    }

    let customOption: FoodOption = {
      id: createLocalCustomFoodOptionId(name),
      name: name,
      description: this.customFoodDescription.trim().length > 0 ? this.customFoodDescription.trim() : '自定义食物卡片',
      calories: caloriesValue,
      serving: serving,
      mealSuggestion: getFoodMealLabel(this.selectedMealType),
      image: this.customFoodImage.trim().length > 0 ? this.customFoodImage.trim() : buildDefaultCustomFoodImage(this.selectedMealType),
      accentColor: this.getMealAccentColor()
    };

    let upsertResult = upsertCustomFoodOptionByIdentity(this.customFoodOptions, customOption);
    this.saveCustomFoodOptions(upsertResult.options);
    let saveResult = await syncOperationNowOrQueue(this.buildSyncState(), createFoodOptionUpsertOperation(upsertResult.option));
    this.applySyncState(saveResult.state);
    this.customFoodOptions = deserializeCustomFoodOptions(this.customFoodOptionText);
    this.foodPlans = deserializeFoodPlans(this.foodPlanText);
    this.initializeDraftSelections();
    let savedOption: FoodOption = upsertResult.option;
    for (let index = 0; index < this.customFoodOptions.length; index++) {
      let currentOption = this.customFoodOptions[index];
      if (currentOption.id === upsertResult.option.id) {
        savedOption = currentOption;
        break;
      }
    }

    if (addToMeal) {
      this.increaseDraftSelection(savedOption);
      this.pageNotice = saveResult.syncedImmediately
        ? `${upsertResult.hasUpdated ? '已更新' : '已创建'} ${savedOption.name}，已同步并加入待保存清单。`
        : `${upsertResult.hasUpdated ? '已更新' : '已创建'} ${savedOption.name}，并加入待保存清单。`;
    } else {
      this.pageNotice = saveResult.syncedImmediately
        ? `已${upsertResult.hasUpdated ? '更新' : '保存并同步'}自定义食物卡：${savedOption.name}。`
        : `已${upsertResult.hasUpdated ? '更新' : '保存'}自定义食物卡：${savedOption.name}。`;
    }

    this.closeCustomFoodSheet();
    this.clearCustomFoodForm();
  }

  private async saveTodaySelections(): Promise<void> {
    let savedMealPlans: FoodPlanItem[] = this.getCurrentMealPlans();
    if (this.getDraftSelectedCount() === 0 && savedMealPlans.length === 0) {
      this.pageNotice = '还没有选择食物。';
      return;
    }

    let remainingPlans: FoodPlanItem[] = [];
    for (let index = 0; index < this.foodPlans.length; index++) {
      if (this.foodPlans[index].date !== this.selectedDate || this.foodPlans[index].mealType !== this.selectedMealType) {
        remainingPlans.push(this.foodPlans[index]);
      }
    }

    let nextMealPlans: FoodPlanItem[] = [];
    for (let index = 0; index < this.draftSelections.length; index++) {
      for (let countIndex = 0; countIndex < this.draftSelections[index].count; countIndex++) {
        nextMealPlans.push(createFoodPlanItem(
          this.selectedDate,
          this.draftSelections[index].option,
          this.selectedMealType,
          this.planNotesInput
        ));
      }
    }

    this.saveFoodPlans(nextMealPlans.concat(remainingPlans));
    let saveResult = await syncOperationNowOrQueue(this.buildSyncState(), createFoodMealReplaceOperation(
      this.selectedDate,
      this.selectedMealType,
      this.planNotesInput,
      this.getDraftSelectionPayloads()
    ));
    this.applySyncState(saveResult.state);
    this.customFoodOptions = deserializeCustomFoodOptions(this.customFoodOptionText);
    this.foodPlans = deserializeFoodPlans(this.foodPlanText);
    this.initializeDraftSelections();
    this.quantitySheetVisible = false;
    this.customSheetVisible = false;
    this.pageNotice = nextMealPlans.length > 0
      ? (saveResult.syncedImmediately
        ? `已同步今天${getFoodMealLabel(this.selectedMealType)}的选择，共 ${nextMealPlans.length} 份。`
        : `已保存今天${getFoodMealLabel(this.selectedMealType)}的选择，共 ${nextMealPlans.length} 份；联网后会自动同步。`)
      : (saveResult.syncedImmediately
        ? `已同步清空今天${getFoodMealLabel(this.selectedMealType)}的选择。`
        : `已清空今天${getFoodMealLabel(this.selectedMealType)}的选择；联网后会自动同步。`);
    this.goBack();
  }

  private getSortedFoodOptions(applyAiRanking: boolean = true): FoodOption[] {
    let result: FoodOption[] = [];
    let knownIds: string[] = [];
    for (let index = 0; index < PRESET_FOOD_OPTIONS.length; index++) {
      result.push({
        id: PRESET_FOOD_OPTIONS[index].id,
        name: PRESET_FOOD_OPTIONS[index].name,
        description: PRESET_FOOD_OPTIONS[index].description,
        calories: PRESET_FOOD_OPTIONS[index].calories,
        serving: PRESET_FOOD_OPTIONS[index].serving,
        mealSuggestion: PRESET_FOOD_OPTIONS[index].mealSuggestion,
        image: resolveFoodOptionImage(PRESET_FOOD_OPTIONS[index]),
        accentColor: PRESET_FOOD_OPTIONS[index].accentColor
      });
      knownIds.push(PRESET_FOOD_OPTIONS[index].id);
    }
    for (let index = 0; index < this.customFoodOptions.length; index++) {
      if (knownIds.indexOf(this.customFoodOptions[index].id) >= 0) {
        continue;
      }
      result.push({
        id: this.customFoodOptions[index].id,
        name: this.customFoodOptions[index].name,
        description: this.customFoodOptions[index].description,
        calories: this.customFoodOptions[index].calories,
        serving: this.customFoodOptions[index].serving,
        mealSuggestion: this.customFoodOptions[index].mealSuggestion,
        image: resolveFoodOptionImage(this.customFoodOptions[index]),
        accentColor: this.customFoodOptions[index].accentColor
      });
      knownIds.push(this.customFoodOptions[index].id);
    }

    result.sort((left: FoodOption, right: FoodOption) => {
      if (applyAiRanking) {
        let leftScore = getRecommendationScore(this.foodRecommendationCacheText, left.id);
        let rightScore = getRecommendationScore(this.foodRecommendationCacheText, right.id);
        if (leftScore !== rightScore) {
          return rightScore - leftScore;
        }
      }
      let leftMatch: number = left.mealSuggestion === getFoodMealLabel(this.selectedMealType) ? 0 : 1;
      let rightMatch: number = right.mealSuggestion === getFoodMealLabel(this.selectedMealType) ? 0 : 1;
      if (leftMatch !== rightMatch) {
        return leftMatch - rightMatch;
      }
      if (left.name > right.name) {
        return 1;
      }
      if (left.name < right.name) {
        return -1;
      }
      return 0;
    });
    return result;
  }

  private getCardRows(): FoodChoiceCardItem[][] {
    let items: FoodChoiceCardItem[] = [];
    items.push({
      id: 'create-custom-card',
      type: 'create',
      option: {
        id: 'create-custom-card',
        name: '自定义食物',
        description: '从底部弹出面板，自定义食物图片、热量和份量。',
        calories: 0,
        serving: '点击创建',
        mealSuggestion: getFoodMealLabel(this.selectedMealType),
        image: 'builtin:food:custom-card',
        accentColor: this.getMealAccentColor()
      }
    });

    let sortedOptions: FoodOption[] = this.getSortedFoodOptions();
    for (let index = 0; index < sortedOptions.length; index++) {
      items.push({
        id: sortedOptions[index].id,
        type: 'option',
        option: sortedOptions[index]
      });
    }

    let rows: FoodChoiceCardItem[][] = [];
    for (let index = 0; index < items.length; index += 2) {
      rows.push(items.slice(index, index + 2));
    }
    return rows;
  }

  private getSourceLabel(option: FoodOption): string {
    if (this.isFoodAiTopRecommendation(option.id)) {
      return 'AI 推荐';
    }
    if (option.id.indexOf('local-food-option-') === 0 || option.id.indexOf('custom-food-') === 0) {
      return '我的卡片';
    }
    return option.mealSuggestion === getFoodMealLabel(this.selectedMealType) ? '推荐' : '可选';
  }

  @Builder
  buildFoodVisual(image: string, title: string, heightValue: number) {
    if (isBuiltinFoodImage(image)) {
      Stack({ alignContent: Alignment.BottomStart }) {
        Column() {
          Row() {
            Text(getFoodVisualDescriptor(image, title).primaryText)
              .fontSize(heightValue >= 200 ? 28 : 14)
              .fontWeight(FontWeight.Bolder)
              .fontColor('#FFFFFF')
              .padding({ left: heightValue >= 200 ? 16 : 10, right: heightValue >= 200 ? 16 : 10, top: 6, bottom: 6 })
              .backgroundColor('#26000000')
              .borderRadius(999)
          }
          .width('100%')
          .justifyContent(FlexAlign.End)

          Blank()
            .layoutWeight(1)

          Row({ space: 10 }) {
            Text(getFoodVisualDescriptor(image, title).secondaryText)
              .fontSize(heightValue >= 200 ? 16 : 11)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor('#1AFFFFFF')
              .borderRadius(999)

            Text(title)
              .fontSize(heightValue >= 200 ? 14 : 10)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
              .maxLines(1)
          }
        }
        .width('100%')
        .height('100%')
        .padding(heightValue >= 200 ? 18 : 10)
        .backgroundColor(getFoodVisualDescriptor(image, title).bottomColor)

        Text('')
          .width('72%')
          .height(heightValue >= 200 ? 92 : 46)
          .backgroundColor(getFoodVisualDescriptor(image, title).topColor)
          .borderRadius(heightValue >= 200 ? 28 : 18)
          .margin({ left: heightValue >= 200 ? 12 : 8, top: heightValue >= 200 ? 12 : 8 })

        Row({ space: heightValue >= 200 ? 14 : 8 }) {
          Text('')
            .width(heightValue >= 200 ? 88 : 40)
            .height(heightValue >= 200 ? 88 : 40)
            .borderRadius(heightValue >= 200 ? 44 : 20)
            .backgroundColor('#22FFFFFF')

          Text('')
            .width(heightValue >= 200 ? 58 : 28)
            .height(heightValue >= 200 ? 58 : 28)
            .borderRadius(heightValue >= 200 ? 29 : 14)
            .backgroundColor(getFoodVisualDescriptor(image, title).accentColor)
            .margin({ top: heightValue >= 200 ? 44 : 18 })
        }
        .padding({ left: heightValue >= 200 ? 18 : 10, top: heightValue >= 200 ? 18 : 10 })
      }
      .width('100%')
      .height(heightValue)
      .borderRadius(heightValue >= 200 ? 24 : 18)
    } else {
      Image(image)
        .width('100%')
        .height(heightValue)
        .objectFit(ImageFit.Cover)
        .borderRadius(heightValue >= 200 ? 24 : 18)
    }
  }

  @Builder
  buildCreateFoodCard() {
    Stack({ alignContent: Alignment.BottomStart }) {
      this.buildFoodVisual('builtin:food:custom-card', '自定义食物', 232)

      Column({ space: 8 }) {
        Text('自定义食物')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')

        Text('从底部弹出页面，支持选择相册图片')
          .fontSize(12)
          .lineHeight(18)
          .fontColor('#F8FAFC')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(16)
      .backgroundColor('#550D1628')
    }
    .width('100%')
    .height(232)
    .borderRadius(24)
    .onClick(() => {
      this.openCustomFoodSheet();
    })
  }

  @Builder
  buildFoodChoiceCard(option: FoodOption) {
    Stack({ alignContent: Alignment.BottomStart }) {
      this.buildFoodVisual(option.image, option.name, 232)

      Column({ space: 8 }) {
        Row() {
          Text(this.getSourceLabel(option))
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor('#26000000')
            .borderRadius(999)

          Row({ space: 6 }) {
            Text(`${Math.round(option.calories)} kcal`)
              .fontSize(10)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor('#26000000')
              .borderRadius(999)

            if (this.getDraftSelectionCount(option.id) > 0) {
              Text(`已选 ${this.getDraftSelectionCount(option.id)}`)
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor(option.accentColor)
                .borderRadius(999)
            }
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)

        Text(option.name)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .maxLines(2)

        Text(`${option.serving} · ${option.description}`)
          .fontSize(12)
          .lineHeight(18)
          .fontColor('#F1F5F9')
          .maxLines(2)

        Text(this.getDraftActionHint(option.id))
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(14)
      .backgroundColor('#8B0D1628')
    }
    .width('100%')
    .height(232)
    .borderRadius(24)
    .border({
      color: this.getDraftSelectionCount(option.id) > 0 ? option.accentColor : '#00000000',
      width: this.getDraftSelectionCount(option.id) > 0 ? 3 : 0
    })
    .onClick(() => {
      this.increaseDraftSelection(option);
    })
  }

  @Builder
  buildQuantitySheet() {
    if (this.quantitySheetVisible) {
      Stack({ alignContent: Alignment.Bottom }) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#66000000')
          .onClick(() => {
            this.closeQuantitySheet();
          })

        Column({ space: 14 }) {
          Row() {
            Column({ space: 4 }) {
              Text('已选食物')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(PRIMARY_TEXT_COLOR)

              Text(`${this.formatFriendlyDate(this.selectedDate)} · ${getFoodMealLabel(this.selectedMealType)}`)
                .fontSize(12)
                .fontColor(SECONDARY_TEXT_COLOR)
            }
            .alignItems(HorizontalAlign.Start)

            Button('收起')
              .height(34)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#17324D')
              .backgroundColor('#EEF3FF')
              .borderRadius(17)
              .onClick(() => {
                this.closeQuantitySheet();
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)

          Text(`共 ${this.getDraftSelectedCount()} 份 · ${Math.round(this.getDraftSelectedCalories())} kcal`)
            .fontSize(13)
            .fontColor('#4F6690')
            .width('100%')

          if (this.draftSelections.length > 0) {
            Scroll() {
              Column({ space: 12 }) {
                ForEach(this.draftSelections, (draft: FoodDraftSelectionItem) => {
                  Column({ space: 14 }) {
                    this.buildFoodVisual(draft.option.image, draft.option.name, 120)

                    Row({ space: 12 }) {
                      Column({ space: 6 }) {
                        Text(draft.option.name)
                          .fontSize(16)
                          .fontWeight(FontWeight.Bold)
                          .fontColor(PRIMARY_TEXT_COLOR)
                          .maxLines(1)

                        Text(`${draft.option.serving} · 单份 ${Math.round(draft.option.calories)} kcal`)
                          .fontSize(12)
                          .fontColor(SECONDARY_TEXT_COLOR)
                          .maxLines(2)

                        Text(`小计 ${Math.round(this.getDraftSelectionSubtotal(draft.foodId))} kcal`)
                          .fontSize(12)
                          .fontWeight(FontWeight.Medium)
                          .fontColor(draft.option.accentColor)
                      }
                      .layoutWeight(1)
                      .alignItems(HorizontalAlign.Start)

                      Row({ space: 10 }) {
                        Button('－')
                          .width(44)
                          .height(44)
                          .fontSize(24)
                          .fontWeight(FontWeight.Bolder)
                          .fontColor('#214161')
                          .backgroundColor('#EAF1FF')
                          .borderRadius(22)
                          .onClick(() => {
                            this.setDraftSelectionCount(draft.option, this.getDraftSelectionCount(draft.foodId) - 1);
                          })

                        Text(`${this.getDraftSelectionCount(draft.foodId)}`)
                          .fontSize(20)
                          .fontWeight(FontWeight.Bolder)
                          .fontColor(PRIMARY_TEXT_COLOR)
                          .width(52)
                          .height(44)
                          .textAlign(TextAlign.Center)
                          .borderRadius(18)
                          .backgroundColor('#F3F6FB')
                          .padding({ top: 10 })

                        Button('+')
                          .width(52)
                          .height(52)
                          .fontSize(28)
                          .fontWeight(FontWeight.Bolder)
                          .fontColor('#FFFFFF')
                          .backgroundColor(draft.option.accentColor)
                          .borderRadius(26)
                          .border({ color: '#FFFFFF', width: 2 })
                          .onClick(() => {
                            this.setDraftSelectionCount(draft.option, this.getDraftSelectionCount(draft.foodId) + 1);
                          })
                      }
                    }
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Start)
                  .padding(14)
                  .backgroundColor('#F8FAFD')
                  .borderRadius(22)
                }, (draft: FoodDraftSelectionItem) => draft.foodId)
              }
              .width('100%')
            }
            .width('100%')
            .height(280)
            .scrollable(ScrollDirection.Vertical)
            .scrollBar(BarState.Auto)
          } else {
            Column({ space: 8 }) {
              Text('待保存清单为空')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(PRIMARY_TEXT_COLOR)

              Text('当前餐次会在确认后被清空。')
                .fontSize(12)
                .fontColor(SECONDARY_TEXT_COLOR)
            }
            .alignItems(HorizontalAlign.Start)
            .justifyContent(FlexAlign.Center)
            .width('100%')
            .height(120)
            .padding(16)
            .backgroundColor('#F6F8FB')
            .borderRadius(18)
          }

          Text(this.shouldShowClearAction() ? '当前没有待保存食物，点击下面按钮会清空本餐次。' : '点“确认保存今天选择”后，会覆盖当前餐次并保存到今天。')
            .fontSize(12)
            .lineHeight(18)
            .fontColor(SECONDARY_TEXT_COLOR)
            .width('100%')

          Button(this.shouldShowClearAction() ? '清空并保存今天选择' : '确认保存今天选择')
            .width('100%')
            .height(50)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .backgroundColor(this.shouldShowClearAction() ? '#EF4444' : this.getMealAccentColor())
            .borderRadius(22)
            .onClick(() => {
              this.saveTodaySelections();
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 18, bottom: 24 })
        .backgroundColor(SURFACE_BACKGROUND_COLOR)
        .borderRadius({ topLeft: 28, topRight: 28 })
      }
      .width('100%')
      .height('100%')
    }
  }

  @Builder
  buildCustomFoodSheet() {
    if (this.customSheetVisible) {
      Stack({ alignContent: Alignment.Bottom }) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#66000000')
          .onClick(() => {
            this.closeCustomFoodSheet();
          })

        Column({ space: 12 }) {
          Row() {
            Column({ space: 4 }) {
              Text('自定义食物')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(PRIMARY_TEXT_COLOR)

              Text(`加入 ${getFoodMealLabel(this.selectedMealType)} · 点击灰色区域可取消`)
                .fontSize(12)
                .fontColor(SECONDARY_TEXT_COLOR)
            }
            .alignItems(HorizontalAlign.Start)

            Button('收起')
              .height(34)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#17324D')
              .backgroundColor('#EEF3FF')
              .borderRadius(17)
              .onClick(() => {
                this.closeCustomFoodSheet();
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)

          if (this.customFoodImage.trim().length > 0) {
            Image(this.customFoodImage)
              .width('100%')
              .height(150)
              .objectFit(ImageFit.Cover)
              .borderRadius(18)
          } else {
            Column({ space: 8 }) {
              Text('还没选择图片')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(PRIMARY_TEXT_COLOR)

              Text('可以从相册选择，也可以直接保存后自动生成内置卡面')
                .fontSize(12)
                .fontColor(SECONDARY_TEXT_COLOR)
            }
            .alignItems(HorizontalAlign.Start)
            .justifyContent(FlexAlign.Center)
            .width('100%')
            .height(120)
            .padding(16)
            .backgroundColor('#F6F8FB')
            .borderRadius(18)
          }

          Button(this.customFoodImage.trim().length > 0 ? '重新选择相册图片' : '从相册选择图片')
            .width('100%')
            .height(42)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .backgroundColor(this.getMealAccentColor())
            .borderRadius(18)
            .onClick(() => {
              this.pickCustomFoodImage();
            })

          TextInput({ placeholder: '食物名称，例如 鸡胸肉卷', text: this.customFoodName })
            .fontSize(15)
            .fontColor(PRIMARY_TEXT_COLOR)
            .height(46)
            .width('100%')
            .padding({ left: 12, right: 12 })
            .backgroundColor('#F6F8FB')
            .borderRadius(16)
            .onChange((value: string) => {
              this.customFoodName = value;
            })

          Row({ space: 12 }) {
            TextInput({ placeholder: '热量 kcal', text: this.customFoodCalories })
              .layoutWeight(1)
              .fontSize(15)
              .fontColor(PRIMARY_TEXT_COLOR)
              .height(46)
              .padding({ left: 12, right: 12 })
              .backgroundColor('#F6F8FB')
              .borderRadius(16)
              .onChange((value: string) => {
                this.customFoodCalories = value;
              })

            TextInput({ placeholder: '份量', text: this.customFoodServing })
              .layoutWeight(1)
              .fontSize(15)
              .fontColor(PRIMARY_TEXT_COLOR)
              .height(46)
              .padding({ left: 12, right: 12 })
              .backgroundColor('#F6F8FB')
              .borderRadius(16)
              .onChange((value: string) => {
                this.customFoodServing = value;
              })
          }
          .width('100%')

          TextInput({ placeholder: '描述，例如 高蛋白、适合早餐或加餐', text: this.customFoodDescription })
            .fontSize(15)
            .fontColor(PRIMARY_TEXT_COLOR)
            .height(46)
            .width('100%')
            .padding({ left: 12, right: 12 })
            .backgroundColor('#F6F8FB')
            .borderRadius(16)
            .onChange((value: string) => {
              this.customFoodDescription = value;
            })

          Row({ space: 10 }) {
            Button('仅保存卡片')
              .layoutWeight(1)
              .height(42)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getMealAccentColor())
              .backgroundColor('#FFFFFF')
              .borderRadius(18)
              .onClick(() => {
                this.saveCustomFoodCard(false);
              })

            Button(`保存并加入待保存清单`)
              .layoutWeight(1)
              .height(42)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
              .backgroundColor(this.getMealAccentColor())
              .borderRadius(18)
              .onClick(() => {
                this.saveCustomFoodCard(true);
              })
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 18, bottom: 24 })
        .backgroundColor(SURFACE_BACKGROUND_COLOR)
        .borderRadius({ topLeft: 28, topRight: 28 })
      }
      .width('100%')
      .height('100%')
    }
  }

  @Builder
  buildBottomActionBar() {
    Column() {
      Row({ space: 10 }) {
        Row({ space: 10 }) {
          Column({ space: 4 }) {
            Text(this.getDraftSelectedCount() > 0 ? `已选 ${this.getDraftSelectedCount()} 份` : this.shouldShowClearAction() ? '待保存为空' : '还没选择食物')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(PRIMARY_TEXT_COLOR)

            Text(this.getDraftSelectedCount() > 0
              ? `${Math.round(this.getDraftSelectedCalories())} kcal，点击展开具体配置`
              : this.shouldShowClearAction()
                ? '点击展开后可确认清空本餐次'
                : '点击这里查看数量配置')
              .fontSize(11)
              .fontColor(SECONDARY_TEXT_COLOR)
              .maxLines(1)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text('展开')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(this.getMealAccentColor())
            .borderRadius(999)
        }
        .layoutWeight(1)
        .height(64)
        .padding({ left: 14, right: 14 })
        .backgroundColor('#FFFFFF')
        .borderRadius(20)
        .border({ color: '#DFE7F3', width: 1 })
        .onClick(() => {
          this.openQuantitySheet();
        })

        Button(this.shouldShowClearAction() ? '清空保存' : '确认保存')
          .width(124)
          .height(64)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .backgroundColor(this.shouldShowClearAction() ? '#EF4444' : this.getMealAccentColor())
          .borderRadius(20)
          .onClick(() => {
            this.saveTodaySelections();
          })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 12 })
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .border({ color: '#E3EAF4', width: { top: 1 } })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        Row() {
          Row({ space: 6 }) {
            Image($r('sys.media.ohos_ic_back'))
              .width(18)
              .height(18)

            Text('返回')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(PRIMARY_TEXT_COLOR)
          }
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .backgroundColor('#F3F6FB')
          .borderRadius(20)
          .onClick(() => {
            this.goBack();
          })

          Text('选择食物')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(PRIMARY_TEXT_COLOR)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Text('')
            .width(62)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(VerticalAlign.Center)
        .padding({ left: 16, right: 16, top: 12, bottom: 14 })
        .backgroundColor(SURFACE_BACKGROUND_COLOR)
        .border({ color: '#E3EAF4', width: { top: 1 } })

        Scroll() {
          Column({ space: 18 }) {
            Column({ space: 12 }) {
              Row() {
                Text(`正在安排 ${getFoodMealLabel(this.selectedMealType)}`)
                  .fontSize(24)
                  .fontWeight(FontWeight.Bolder)
                  .fontColor(PRIMARY_TEXT_COLOR)
                  .layoutWeight(1)

                Button(this.recommendationBusy ? 'AI 排序中' : 'AI 推荐')
                  .height(34)
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#FFFFFF')
                  .backgroundColor(this.recommendationBusy ? '#98A2B3' : this.getMealAccentColor())
                  .borderRadius(17)
                  .onClick(() => {
                    this.refreshAiRecommendations();
                  })
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)
              .alignItems(VerticalAlign.Center)

              Text(`${this.formatFriendlyDate(this.selectedDate)} · 待保存 ${this.getDraftSelectedCount()} 份 · ${Math.round(this.getDraftSelectedCalories())} kcal`)
                .fontSize(13)
                .fontColor(SECONDARY_TEXT_COLOR)

              Text(this.getSavedMealSummaryText())
                .fontSize(12)
                .lineHeight(18)
                .fontColor('#4F6690')

              TextInput({ placeholder: '给这次添加备注，例如 少糖 / 训练后 / 外食', text: this.planNotesInput })
                .fontSize(15)
                .fontColor(PRIMARY_TEXT_COLOR)
                .height(46)
                .width('100%')
                .padding({ left: 12, right: 12 })
                .backgroundColor('#F6F8FB')
                .borderRadius(16)
                .onChange((value: string) => {
                  this.planNotesInput = value;
                })

              Text(this.pageNotice)
                .fontSize(13)
                .lineHeight(20)
                .fontColor('#4F6690')
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding(18)
            .backgroundColor(this.getMealSurfaceColor())
            .borderRadius(24)

            Column({ space: 12 }) {
              ForEach(this.getCardRows(), (row: FoodChoiceCardItem[]) => {
                Row({ space: 12 }) {
                  ForEach(row, (item: FoodChoiceCardItem) => {
                    Column() {
                      if (item.type === 'create') {
                        this.buildCreateFoodCard()
                      } else {
                        this.buildFoodChoiceCard(item.option)
                      }
                    }
                    .layoutWeight(1)
                  }, (item: FoodChoiceCardItem) => item.id)

                  if (row.length === 1) {
                    Text('')
                      .layoutWeight(1)
                  }
                }
                .width('100%')
                .alignItems(VerticalAlign.Top)
              }, (row: FoodChoiceCardItem[]) => row[0].id)
            }
            .width('100%')
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 24, bottom: 132 })
        }
        .width('100%')
        .height('100%')
        .scrollable(ScrollDirection.Vertical)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
        .friction(0.6)
        .backgroundColor(PAGE_BACKGROUND_COLOR)
      }
      .width('100%')
      .height('100%')

      this.buildBottomActionBar()
      this.buildQuantitySheet()
      this.buildCustomFoodSheet()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PAGE_BACKGROUND_COLOR)
  }
}
