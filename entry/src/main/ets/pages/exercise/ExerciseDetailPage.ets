import {
  PAGE_BACKGROUND_COLOR,
  PRIMARY_TEXT_COLOR,
  SECONDARY_TEXT_COLOR,
  SURFACE_BACKGROUND_COLOR
} from '../../constants/AppTheme';
import {
  CUSTOM_INTENSITY_MODERATE,
  CUSTOM_INTENSITY_OPTIONS,
  CUSTOM_MODE_OPTIONS,
  CustomIntensityOption,
  EXERCISE_OPTIONS,
  EXERCISE_MODE_COUNT_RATE,
  EXERCISE_MODE_DISTANCE_PACE,
  EXERCISE_MODE_DISTANCE_SPEED,
  EXERCISE_MODE_DURATION,
  EXERCISE_MODE_SET_TIMER,
  ExerciseDraft,
  ExerciseOption,
  SavedCustomWorkout,
  WorkoutMetrics,
  createDefaultExerciseDraft
} from '../../models/ExerciseOption';
import { UserProfile, createEmptyUserProfile } from '../../models/UserProfile';
import { WorkoutRecord } from '../../models/WorkoutRecord';
import {
  calculateCaloriesBurned,
  createDraftFromSavedCustomWorkout,
  createSavedCustomWorkoutFromDraft,
  deserializeExerciseDraft,
  deserializeSavedCustomWorkouts,
  deserializeUserProfile,
  deserializeWorkoutRecords,
  findExerciseOption,
  formatClockText,
  getActiveWorkoutMode,
  getProfileReminderText,
  getSetTimerProgress,
  getSetTimerStageRemainingText,
  getSetTimerStageText,
  getSetTimerTotalSeconds,
  getWeightValue,
  getWorkoutMetrics,
  getWorkoutValidationMessage,
  serializeExerciseDraft,
  serializeSavedCustomWorkouts,
  serializeWorkoutRecords
} from '../../utils/ExerciseHelper';
import { formatDate } from '../../utils/WeightRecordHelper';
import { EXERCISE_STORAGE_READY } from '../../utils/ExerciseStorage';
import {
  FEEDBACK_STYLE_ALARM,
  FEEDBACK_STYLE_STANDARD,
  TrainingFeedbackResult,
  playTrainingFeedback
} from '../../utils/TrainingFeedbackHelper';
import { DEFAULT_API_BASE_URL } from '../../models/AuthSession';
import {
  createWorkoutRecordCreateOperation,
  createWorkoutTemplateDeleteOperation,
  createWorkoutTemplateUpsertOperation
} from '../../utils/SyncQueueHelper';
import { SyncRuntimeState, syncOperationNowOrQueue, syncPendingOperations } from '../../utils/SyncService';

const SET_TIMER_MODE_AUTO: string = 'auto';
const SET_TIMER_MODE_MANUAL: string = 'manual';
const MANUAL_STAGE_IDLE: string = 'idle';
const MANUAL_STAGE_WORK: string = 'work';
const MANUAL_STAGE_REST: string = 'rest';
const MANUAL_STAGE_DONE: string = 'done';

interface ExerciseSwitchItem {
  exerciseId: string;
  savedWorkoutId: string;
  label: string;
  accentColor: string;
  isSavedWorkout: boolean;
}

@Entry
@Component
struct ExerciseDetailPage {
  @StorageLink('savedCustomWorkoutText') savedCustomWorkoutText: string = '';
  @StorageLink('workoutRecordText') workoutRecordText: string = '';
  @StorageLink('currentExerciseDraftText') currentExerciseDraftText: string = '';
  @StorageLink('currentExerciseProfileText') currentExerciseProfileText: string = '';
  @StorageLink('currentEditingSavedWorkoutIdText') currentEditingSavedWorkoutIdText: string = '';
  @StorageLink('currentExercisePlanIdText') currentExercisePlanIdText: string = '';
  @StorageLink('apiBaseUrlText') apiBaseUrlText: string = '';
  @StorageLink('authSessionText') authSessionText: string = '';
  @StorageLink('userProfileText') userProfileText: string = '';
  @StorageLink('weightRecordText') weightRecordText: string = '';
  @StorageLink('customFoodOptionText') customFoodOptionText: string = '';
  @StorageLink('foodPlanText') foodPlanText: string = '';
  @StorageLink('workoutPlanText') workoutPlanText: string = '';
  @StorageLink('workoutPlanMetaText') workoutPlanMetaText: string = '';
  @StorageLink('pendingSyncQueueText') pendingSyncQueueText: string = '';
  @StorageLink('foodRecommendationCacheText') foodRecommendationCacheText: string = '';
  @StorageLink('exerciseRecommendationCacheText') exerciseRecommendationCacheText: string = '';
  @StorageLink('lastSyncAttemptText') lastSyncAttemptText: string = '';
  @StorageLink('lastSyncSuccessText') lastSyncSuccessText: string = '';

  @State sessionProfile: UserProfile = createEmptyUserProfile();
  @State savedCustomWorkouts: SavedCustomWorkout[] = [];
  @State selectedExerciseId: string = 'hiit';
  @State customName: string = '';
  @State customMode: string = EXERCISE_MODE_DURATION;
  @State customIntensity: string = CUSTOM_INTENSITY_MODERATE;
  @State durationMinutes: string = '30';
  @State distanceKm: string = '5';
  @State paceMinutes: string = '6';
  @State speedKmH: string = '18';
  @State count: string = '300';
  @State cadencePerMinute: string = '120';
  @State sets: string = '4';
  @State workSeconds: string = '40';
  @State restSeconds: string = '20';
  @State selectedSavedWorkoutId: string = '';
  @State sessionElapsedSeconds: number = 0;
  @State sessionRunning: boolean = false;
  @State setTimerMode: string = SET_TIMER_MODE_AUTO;
  @State reminderEnabled: boolean = true;
  @State soundEnabled: boolean = true;
  @State vibrationEnabled: boolean = true;
  @State feedbackStyle: string = FEEDBACK_STYLE_ALARM;
  @State reminderCount: number = 0;
  @State lastReminderText: string = '训练开始后，切换训练与休息时会在这里记录提醒。';
  @State sessionNotice: string = '训练会按实时用时估算热量，结束后自动计入今日消耗。';
  @State manualCurrentSet: number = 1;
  @State manualStage: string = MANUAL_STAGE_IDLE;
  @State manualStageElapsedSeconds: number = 0;

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
    this.syncSavedCustomWorkoutsFromStorage();
  }

  private sessionTimerId: number = -1;
  private feedbackBusy: boolean = false;

  aboutToAppear(): void {
    EXERCISE_STORAGE_READY;
    if (this.apiBaseUrlText.trim().length === 0) {
      this.apiBaseUrlText = DEFAULT_API_BASE_URL;
    }
    this.loadState();
    this.flushPendingSync();
  }

  aboutToDisappear(): void {
    this.clearSessionTimer();
  }

  private loadState(): void {
    let draft: ExerciseDraft = deserializeExerciseDraft(this.currentExerciseDraftText);
    this.sessionProfile = deserializeUserProfile(this.currentExerciseProfileText);
    this.syncSavedCustomWorkoutsFromStorage();
    this.selectedSavedWorkoutId = this.currentEditingSavedWorkoutIdText;
    this.applyDraftFields(draft);
  }

  private getDraft(): ExerciseDraft {
    return {
      exerciseId: this.selectedExerciseId,
      customName: this.customName,
      customMode: this.customMode,
      customIntensity: this.customIntensity,
      durationMinutes: this.durationMinutes,
      distanceKm: this.distanceKm,
      paceMinutes: this.paceMinutes,
      speedKmH: this.speedKmH,
      count: this.count,
      cadencePerMinute: this.cadencePerMinute,
      sets: this.sets,
      workSeconds: this.workSeconds,
      restSeconds: this.restSeconds
    };
  }

  private syncDraft(): void {
    this.currentExerciseDraftText = serializeExerciseDraft(this.getDraft());
  }

  private syncSavedCustomWorkoutsFromStorage(): void {
    this.savedCustomWorkouts = deserializeSavedCustomWorkouts(this.savedCustomWorkoutText);
  }

  private applyDraftFields(draft: ExerciseDraft): void {
    this.selectedExerciseId = draft.exerciseId;
    this.customName = draft.customName;
    this.customMode = draft.customMode;
    this.customIntensity = draft.customIntensity;
    this.durationMinutes = draft.durationMinutes;
    this.distanceKm = draft.distanceKm;
    this.paceMinutes = draft.paceMinutes;
    this.speedKmH = draft.speedKmH;
    this.count = draft.count;
    this.cadencePerMinute = draft.cadencePerMinute;
    this.sets = draft.sets;
    this.workSeconds = draft.workSeconds;
    this.restSeconds = draft.restSeconds;
  }

  private applyDraft(draft: ExerciseDraft, savedWorkoutId: string, noticeText: string, planId: string = ''): void {
    this.selectedSavedWorkoutId = savedWorkoutId;
    this.currentEditingSavedWorkoutIdText = savedWorkoutId;
    this.currentExercisePlanIdText = planId;
    this.applyDraftFields(draft);
    this.syncDraft();
    this.resetSession(noticeText);
  }

  private isPresetExerciseSelected(option: ExerciseOption): boolean {
    if (option.id === 'custom') {
      return this.selectedExerciseId === 'custom' && this.selectedSavedWorkoutId.length === 0;
    }
    return this.selectedExerciseId === option.id;
  }

  private isSavedWorkoutSelected(savedWorkout: SavedCustomWorkout): boolean {
    return this.selectedExerciseId === 'custom' && this.selectedSavedWorkoutId === savedWorkout.id;
  }

  private switchToExercise(optionId: string): void {
    let selectedOption: ExerciseOption = findExerciseOption(optionId);
    if (optionId !== 'custom' && this.selectedExerciseId === optionId) {
      this.sessionNotice = `当前已在 ${selectedOption.name}。`;
      return;
    }
    if (optionId === 'custom' && this.selectedExerciseId === 'custom' && this.selectedSavedWorkoutId.length === 0) {
      this.sessionNotice = '当前已在自定义运动。';
      return;
    }
    let draft: ExerciseDraft = createDefaultExerciseDraft();
    draft.exerciseId = optionId;
    if (optionId !== 'custom') {
      draft.customName = '';
    }
    this.applyDraft(draft, '', `已切换到 ${selectedOption.name}。`);
  }

  private switchToSavedWorkout(savedWorkout: SavedCustomWorkout): void {
    if (this.isSavedWorkoutSelected(savedWorkout)) {
      this.sessionNotice = `当前已在模板：${savedWorkout.name}。`;
      return;
    }
    let draft: ExerciseDraft = createDraftFromSavedCustomWorkout(savedWorkout);
    this.applyDraft(draft, savedWorkout.id, `已切换到模板：${savedWorkout.name}。`);
  }

  private getExerciseSwitchItems(): ExerciseSwitchItem[] {
    let items: ExerciseSwitchItem[] = [];

    for (let optionIndex = 0; optionIndex < EXERCISE_OPTIONS.length; optionIndex++) {
      let option: ExerciseOption = EXERCISE_OPTIONS[optionIndex];
      items.push({
        exerciseId: option.id,
        savedWorkoutId: '',
        label: option.name,
        accentColor: option.accentColor,
        isSavedWorkout: false
      });
    }

    for (let savedIndex = 0; savedIndex < this.savedCustomWorkouts.length; savedIndex++) {
      let savedWorkout: SavedCustomWorkout = this.savedCustomWorkouts[savedIndex];
      items.push({
        exerciseId: 'custom',
        savedWorkoutId: savedWorkout.id,
        label: savedWorkout.name,
        accentColor: '#7B61FF',
        isSavedWorkout: true
      });
    }

    return items;
  }

  private isSwitchItemSelected(item: ExerciseSwitchItem): boolean {
    if (item.isSavedWorkout) {
      return this.selectedExerciseId === 'custom' && this.selectedSavedWorkoutId === item.savedWorkoutId;
    }
    if (item.exerciseId === 'custom') {
      return this.selectedExerciseId === 'custom' && this.selectedSavedWorkoutId.length === 0;
    }
    return this.selectedExerciseId === item.exerciseId;
  }

  private getCurrentSwitchItemIndex(): number {
    let items: ExerciseSwitchItem[] = this.getExerciseSwitchItems();
    for (let index = 0; index < items.length; index++) {
      if (this.isSwitchItemSelected(items[index])) {
        return index;
      }
    }
    return 0;
  }

  private getCurrentSwitchLabel(): string {
    let items: ExerciseSwitchItem[] = this.getExerciseSwitchItems();
    if (items.length === 0) {
      return this.getMetrics().exerciseName;
    }
    return items[this.getCurrentSwitchItemIndex()].label;
  }

  private switchToItem(item: ExerciseSwitchItem): void {
    if (item.isSavedWorkout) {
      for (let index = 0; index < this.savedCustomWorkouts.length; index++) {
        if (this.savedCustomWorkouts[index].id === item.savedWorkoutId) {
          this.switchToSavedWorkout(this.savedCustomWorkouts[index]);
          return;
        }
      }
      this.sessionNotice = '没有找到对应的自定义模板。';
      return;
    }
    this.switchToExercise(item.exerciseId);
  }

  private switchToAdjacentExercise(step: number): void {
    let items: ExerciseSwitchItem[] = this.getExerciseSwitchItems();
    if (items.length <= 1) {
      this.sessionNotice = '当前没有更多运动可切换。';
      return;
    }

    let nextIndex: number = this.getCurrentSwitchItemIndex() + step;
    if (nextIndex < 0) {
      nextIndex = items.length - 1;
    } else if (nextIndex >= items.length) {
      nextIndex = 0;
    }

    this.switchToItem(items[nextIndex]);
  }

  private getContentBottomPadding(): number {
    return 132;
  }

  private getMetrics(): WorkoutMetrics {
    return getWorkoutMetrics(this.sessionProfile, this.getDraft());
  }

  private getActiveMode(): string {
    return getActiveWorkoutMode(this.getDraft());
  }

  private getSelectedOption(): ExerciseOption {
    return findExerciseOption(this.selectedExerciseId);
  }

  private getProfileReminderDisplayText(): string {
    return getProfileReminderText(this.sessionProfile);
  }

  private parsePositiveNumber(value: string): number {
    let parsedValue: number = Number(value.trim());
    if (isNaN(parsedValue) || parsedValue <= 0) {
      return 0;
    }
    return parsedValue;
  }

  private clearSessionTimer(): void {
    if (this.sessionTimerId !== -1) {
      clearInterval(this.sessionTimerId);
      this.sessionTimerId = -1;
    }
  }

  private getLiveCalories(): number {
    return calculateCaloriesBurned(getWeightValue(this.sessionProfile), this.getMetrics().met, this.sessionElapsedSeconds / 60);
  }

  private getLiveCaloriesText(): string {
    if (getWeightValue(this.sessionProfile) <= 0 || this.sessionElapsedSeconds <= 0) {
      return '--';
    }
    return `${Math.round(this.getLiveCalories())} kcal`;
  }

  private adjustClockValue(value: number, offset: number, maxValue: number, wrap: boolean): number {
    let nextValue: number = value + offset;
    if (wrap) {
      if (nextValue < 0) {
        return maxValue;
      }
      if (nextValue > maxValue) {
        return 0;
      }
      return nextValue;
    }
    if (nextValue < 0) {
      return 0;
    }
    if (nextValue > maxValue) {
      return maxValue;
    }
    return nextValue;
  }

  private formatClockUnitValue(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  private getClockDisplaySeconds(): number {
    if (this.getActiveMode() === EXERCISE_MODE_SET_TIMER) {
      if (this.setTimerMode === SET_TIMER_MODE_AUTO) {
        let totalSeconds: number = getSetTimerTotalSeconds(this.getDraft());
        if (this.sessionElapsedSeconds > 0 || this.sessionRunning) {
          return Math.max(0, totalSeconds - this.sessionElapsedSeconds);
        }
        return totalSeconds;
      }

      if (this.manualStage === MANUAL_STAGE_WORK) {
        return Math.max(0, this.getWorkDurationSeconds() - this.manualStageElapsedSeconds);
      }
      if (this.manualStage === MANUAL_STAGE_REST) {
        return Math.max(0, this.getRestDurationSeconds() - this.manualStageElapsedSeconds);
      }
      if (this.manualStage === MANUAL_STAGE_DONE) {
        return 0;
      }
      return getSetTimerTotalSeconds(this.getDraft());
    }

    if (this.sessionElapsedSeconds > 0) {
      return this.sessionElapsedSeconds;
    }
    return Math.round(this.getMetrics().durationMinutes * 60);
  }

  private getClockRowText(offset: number): string {
    let displaySeconds: number = this.getClockDisplaySeconds();
    let hours: number = Math.floor(displaySeconds / 3600);
    let minutes: number = Math.floor((displaySeconds % 3600) / 60);
    let seconds: number = displaySeconds % 60;

    let hourText: string = this.formatClockUnitValue(this.adjustClockValue(hours, offset, 99, false));
    let minuteText: string = this.formatClockUnitValue(this.adjustClockValue(minutes, offset, 59, true));
    let secondText: string = this.formatClockUnitValue(this.adjustClockValue(seconds, offset, 59, true));
    return `${hourText} : ${minuteText} : ${secondText}`;
  }

  private getClockCaptionText(): string {
    if (this.getActiveMode() !== EXERCISE_MODE_SET_TIMER) {
      return this.sessionElapsedSeconds > 0 ? '已训练时长' : '目标时长';
    }
    if (this.setTimerMode === SET_TIMER_MODE_AUTO) {
      return this.sessionElapsedSeconds > 0 || this.sessionRunning ? '总剩余时间' : '总训练时间';
    }
    if (this.manualStage === MANUAL_STAGE_REST) {
      return '本段休息剩余';
    }
    if (this.manualStage === MANUAL_STAGE_DONE) {
      return '本次训练已完成';
    }
    return this.sessionElapsedSeconds > 0 ? '本段训练剩余' : '总训练时间';
  }

  private getCompactCalorieHint(): string {
    if (this.getLiveCaloriesText() === '--') {
      return '热量待估算';
    }
    return `约 ${this.getLiveCaloriesText()}`;
  }

  private canEditClockTarget(): boolean {
    return !this.sessionRunning && this.sessionElapsedSeconds === 0 &&
      (this.getActiveMode() === EXERCISE_MODE_SET_TIMER || this.getActiveMode() === EXERCISE_MODE_DURATION);
  }

  private getEditableTargetSeconds(): number {
    if (this.getActiveMode() === EXERCISE_MODE_SET_TIMER) {
      return getSetTimerTotalSeconds(this.getDraft());
    }
    if (this.getActiveMode() === EXERCISE_MODE_DURATION) {
      return Math.round(this.getMetrics().durationMinutes * 60);
    }
    return 0;
  }

  private applyEditableTargetSeconds(totalSeconds: number): void {
    if (this.getActiveMode() === EXERCISE_MODE_DURATION) {
      let nextMinutes: number = Math.max(1, Math.round(totalSeconds / 60));
      this.durationMinutes = `${nextMinutes}`;
      this.syncDraft();
      this.sessionNotice = `目标时长已调整为 ${nextMinutes} 分钟。`;
      return;
    }

    let setCount: number = Math.max(1, this.getSetCount());
    let restSecondsValue: number = this.getRestDurationSeconds();
    let minTotalSeconds: number = setCount + Math.max(0, setCount - 1) * restSecondsValue;
    let nextTotalSeconds: number = Math.max(minTotalSeconds, totalSeconds);
    let nextWorkSeconds: number = Math.max(1,
      Math.round((nextTotalSeconds - Math.max(0, setCount - 1) * restSecondsValue) / setCount));
    this.workSeconds = `${nextWorkSeconds}`;
    this.syncDraft();
    this.sessionNotice = `每组训练已调整为 ${nextWorkSeconds} 秒，总时长会同步更新。`;
  }

  private getClockAdjustmentPrimaryText(): string {
    if (this.getActiveMode() === EXERCISE_MODE_SET_TIMER) {
      return `${this.getSetCount()} 组 · 休息 ${this.getRestDurationSeconds()} 秒`;
    }
    if (this.getActiveMode() === EXERCISE_MODE_DURATION) {
      return '上下滑动滚轮调整目标时长';
    }
    return this.getStageDetailText();
  }

  private getClockAdjustmentSecondaryText(): string {
    if (this.getActiveMode() === EXERCISE_MODE_SET_TIMER) {
      return `当前每组 ${this.getWorkDurationSeconds()} 秒`;
    }
    return '';
  }

  private getWheelUnitValue(unit: string): number {
    let totalSeconds: number = this.getEditableTargetSeconds();
    if (unit === 'hour') {
      return Math.floor(totalSeconds / 3600);
    }
    if (unit === 'minute') {
      return Math.floor((totalSeconds % 3600) / 60);
    }
    return totalSeconds % 60;
  }

  private getHourPickerRange(): string[] {
    let result: string[] = [];
    for (let index = 0; index < 100; index++) {
      result.push(this.formatClockUnitValue(index));
    }
    return result;
  }

  private getMinuteSecondPickerRange(): string[] {
    let result: string[] = [];
    for (let index = 0; index < 60; index++) {
      result.push(this.formatClockUnitValue(index));
    }
    return result;
  }

  private getPickerSelectedIndex(index: number | number[]): number {
    if (typeof index === 'number') {
      return index;
    }
    if (index.length > 0) {
      return index[0];
    }
    return 0;
  }

  private updateClockWheelSelection(unit: string, selectedIndex: number): void {
    if (!this.canEditClockTarget()) {
      return;
    }

    let hours: number = this.getWheelUnitValue('hour');
    let minutes: number = this.getWheelUnitValue('minute');
    let seconds: number = this.getWheelUnitValue('second');

    if (unit === 'hour') {
      hours = selectedIndex;
    } else if (unit === 'minute') {
      minutes = selectedIndex;
    } else {
      seconds = selectedIndex;
    }

    this.applyEditableTargetSeconds(hours * 3600 + minutes * 60 + seconds);
  }

  private updateWorkoutField(field: string, value: string): void {
    if (field === 'customName') {
      this.customName = value;
    } else if (field === 'durationMinutes') {
      this.durationMinutes = value;
    } else if (field === 'distanceKm') {
      this.distanceKm = value;
    } else if (field === 'paceMinutes') {
      this.paceMinutes = value;
    } else if (field === 'speedKmH') {
      this.speedKmH = value;
    } else if (field === 'count') {
      this.count = value;
    } else if (field === 'cadencePerMinute') {
      this.cadencePerMinute = value;
    } else if (field === 'sets') {
      this.sets = value;
    } else if (field === 'workSeconds') {
      this.workSeconds = value;
    } else if (field === 'restSeconds') {
      this.restSeconds = value;
    }
    this.syncDraft();
    this.resetSessionForConfigChange();
  }

  private selectCustomMode(modeId: string): void {
    this.customMode = modeId;
    this.syncDraft();
    this.resetSession('已切换自定义运动模式。');
  }

  private selectCustomIntensity(intensityId: string): void {
    this.customIntensity = intensityId;
    this.syncDraft();
    this.sessionNotice = '自定义强度已更新。';
  }

  private resetSessionForConfigChange(): void {
    if (!this.sessionRunning && this.sessionElapsedSeconds === 0) {
      return;
    }
    this.resetSession('训练参数已变化，当前训练会话已重置。');
  }

  private resetSession(noticeText: string): void {
    this.clearSessionTimer();
    this.sessionRunning = false;
    this.sessionElapsedSeconds = 0;
    this.reminderCount = 0;
    this.lastReminderText = '训练开始后，切换训练与休息时会在这里记录提醒。';
    this.manualCurrentSet = 1;
    this.manualStage = MANUAL_STAGE_IDLE;
    this.manualStageElapsedSeconds = 0;
    this.sessionNotice = noticeText;
  }

  private async saveCurrentCustomWorkout(): Promise<void> {
    if (this.selectedExerciseId !== 'custom') {
      this.sessionNotice = '只有自定义运动才能保存模板。';
      return;
    }
    let validationMessage: string = getWorkoutValidationMessage(this.getDraft());
    if (validationMessage.length > 0) {
      this.sessionNotice = validationMessage;
      return;
    }
    let savedWorkout: SavedCustomWorkout = createSavedCustomWorkoutFromDraft(this.getDraft());
    let currentSavedWorkouts: SavedCustomWorkout[] = deserializeSavedCustomWorkouts(this.savedCustomWorkoutText);
    let nextSavedWorkouts: SavedCustomWorkout[] = [];
    let targetId: string = this.selectedSavedWorkoutId;
    let hasUpdated: boolean = false;
    for (let index = 0; index < currentSavedWorkouts.length; index++) {
      let currentWorkout: SavedCustomWorkout = currentSavedWorkouts[index];
      if (currentWorkout.id === this.selectedSavedWorkoutId || currentWorkout.name === savedWorkout.name) {
        nextSavedWorkouts.push({
          id: currentWorkout.id,
          name: savedWorkout.name,
          mode: savedWorkout.mode,
          intensity: savedWorkout.intensity,
          durationMinutes: savedWorkout.durationMinutes,
          distanceKm: savedWorkout.distanceKm,
          paceMinutes: savedWorkout.paceMinutes,
          speedKmH: savedWorkout.speedKmH,
          count: savedWorkout.count,
          cadencePerMinute: savedWorkout.cadencePerMinute,
          sets: savedWorkout.sets,
          workSeconds: savedWorkout.workSeconds,
          restSeconds: savedWorkout.restSeconds
        });
        targetId = currentWorkout.id;
        hasUpdated = true;
      } else {
        nextSavedWorkouts.push(currentWorkout);
      }
    }
    if (!hasUpdated) {
      nextSavedWorkouts.unshift(savedWorkout);
      targetId = savedWorkout.id;
    }
    let queuedTemplate: SavedCustomWorkout = savedWorkout;
    for (let index = 0; index < nextSavedWorkouts.length; index++) {
      if (nextSavedWorkouts[index].id === targetId) {
        queuedTemplate = nextSavedWorkouts[index];
      }
    }
    this.selectedSavedWorkoutId = targetId;
    this.currentEditingSavedWorkoutIdText = targetId;
    this.savedCustomWorkoutText = serializeSavedCustomWorkouts(nextSavedWorkouts);
    this.syncSavedCustomWorkoutsFromStorage();
    let result = await syncOperationNowOrQueue(this.buildSyncState(), createWorkoutTemplateUpsertOperation(queuedTemplate));
    this.applySyncState(result.state);
    this.syncSavedCustomWorkoutsFromStorage();
    this.selectedSavedWorkoutId = this.currentEditingSavedWorkoutIdText;
    this.sessionNotice = result.syncedImmediately
      ? (hasUpdated ? `已更新并同步模板：${savedWorkout.name}。` : `已保存并同步模板：${savedWorkout.name}。`)
      : (hasUpdated ? `已更新模板：${savedWorkout.name}。` : `已保存模板：${savedWorkout.name}。`);
  }

  private async deleteCurrentCustomWorkout(): Promise<void> {
    let currentSavedWorkouts: SavedCustomWorkout[] = deserializeSavedCustomWorkouts(this.savedCustomWorkoutText);
    let nextSavedWorkouts: SavedCustomWorkout[] = [];
    let removedWorkoutName: string = '';
    let removedWorkoutId: string = this.selectedSavedWorkoutId;
    for (let index = 0; index < currentSavedWorkouts.length; index++) {
      let currentWorkout: SavedCustomWorkout = currentSavedWorkouts[index];
      if (currentWorkout.id === this.selectedSavedWorkoutId || currentWorkout.name === this.customName.trim()) {
        removedWorkoutName = currentWorkout.name;
        removedWorkoutId = currentWorkout.id;
      } else {
        nextSavedWorkouts.push(currentWorkout);
      }
    }
    if (removedWorkoutName.length === 0) {
      this.sessionNotice = '当前没有可删除的模板。';
      return;
    }
    this.selectedSavedWorkoutId = '';
    this.currentEditingSavedWorkoutIdText = '';
    this.savedCustomWorkoutText = serializeSavedCustomWorkouts(nextSavedWorkouts);
    this.syncSavedCustomWorkoutsFromStorage();
    let result = await syncOperationNowOrQueue(this.buildSyncState(),
      createWorkoutTemplateDeleteOperation(removedWorkoutId, removedWorkoutName));
    this.applySyncState(result.state);
    this.syncSavedCustomWorkoutsFromStorage();
    this.sessionNotice = result.syncedImmediately
      ? `已删除并同步模板：${removedWorkoutName}。`
      : `已删除模板：${removedWorkoutName}。`;
  }

  private getSessionActionText(): string {
    if (this.sessionRunning) {
      return '暂停训练';
    }
    return this.sessionElapsedSeconds > 0 ? '继续训练' : '开始训练';
  }

  private initSetTimerFlow(): void {
    this.reminderCount = 0;
    this.lastReminderText = this.setTimerMode === SET_TIMER_MODE_AUTO
      ? '自动计时已准备好，会在训练结束和休息结束时提醒。'
      : '手动模式已准备好，由你控制训练和休息切换。';
    if (this.setTimerMode === SET_TIMER_MODE_MANUAL) {
      this.manualCurrentSet = 1;
      this.manualStage = MANUAL_STAGE_WORK;
      this.manualStageElapsedSeconds = 0;
    }
  }

  private handleStageReminder(stageText: string): void {
    this.reminderCount += 1;
    this.lastReminderText = `提醒 ${this.reminderCount}：${stageText}`;
    if (!this.reminderEnabled || this.feedbackBusy || (!this.soundEnabled && !this.vibrationEnabled)) {
      return;
    }
    this.feedbackBusy = true;
    playTrainingFeedback(this.soundEnabled, this.vibrationEnabled, this.feedbackStyle)
      .then((result: TrainingFeedbackResult) => {
        this.feedbackBusy = false;
        if (this.soundEnabled && !result.soundPlayed && this.vibrationEnabled && !result.vibrationPlayed) {
          this.sessionNotice = '阶段已切换，但提示音和震动都没有成功触发。';
        } else if (this.soundEnabled && !result.soundPlayed) {
          this.sessionNotice = '阶段已切换，但提示音没有成功播放。';
        } else if (this.vibrationEnabled && !result.vibrationPlayed) {
          this.sessionNotice = '阶段已切换，但震动没有成功触发。';
        } else {
          this.sessionNotice = this.feedbackStyle === FEEDBACK_STYLE_ALARM
            ? '阶段已切换，闹钟式提醒已触发。'
            : '阶段已切换，应用内提醒已触发。';
        }
      })
      .catch(() => {
        this.feedbackBusy = false;
        this.sessionNotice = '设备当前无法播放提示音或震动提醒。';
      });
  }

  private handleAutoSetTimerTick(previousStageText: string): void {
    let totalSeconds: number = getSetTimerTotalSeconds(this.getDraft());
    if (totalSeconds <= 0) {
      return;
    }
    if (this.sessionElapsedSeconds >= totalSeconds) {
      this.sessionElapsedSeconds = totalSeconds;
      this.clearSessionTimer();
      this.sessionRunning = false;
      this.handleStageReminder('全部训练已完成');
      this.sessionNotice = '按组训练已完成，点击“结束并记录”即可保存。';
      return;
    }
    let currentStageText: string = getSetTimerStageText(this.getDraft(), this.sessionElapsedSeconds);
    if (currentStageText !== previousStageText) {
      this.handleStageReminder(currentStageText);
    }
  }

  private toggleSession(): void {
    let validationMessage: string = getWorkoutValidationMessage(this.getDraft());
    if (validationMessage.length > 0) {
      this.sessionNotice = validationMessage;
      return;
    }
    if (this.sessionRunning) {
      this.clearSessionTimer();
      this.sessionRunning = false;
      this.sessionNotice = '训练已暂停。';
      return;
    }
    if (this.sessionElapsedSeconds === 0 && this.getActiveMode() === EXERCISE_MODE_SET_TIMER) {
      this.initSetTimerFlow();
    }
    this.sessionRunning = true;
    this.sessionNotice = '训练已开始，热量会按当前训练效果实时刷新。';
    this.clearSessionTimer();
    this.sessionTimerId = setInterval(() => {
      let previousStageText: string = this.getStageTitle();
      this.sessionElapsedSeconds += 1;
      if (this.getActiveMode() === EXERCISE_MODE_SET_TIMER) {
        if (this.setTimerMode === SET_TIMER_MODE_AUTO) {
          this.handleAutoSetTimerTick(previousStageText);
        } else if (this.manualStage !== MANUAL_STAGE_DONE) {
          this.manualStageElapsedSeconds += 1;
        }
      }
    }, 1000);
  }

  private getSetCount(): number {
    return Math.round(this.parsePositiveNumber(this.sets));
  }

  private getWorkDurationSeconds(): number {
    return Math.round(this.parsePositiveNumber(this.workSeconds));
  }

  private getRestDurationSeconds(): number {
    return Math.round(this.parsePositiveNumber(this.restSeconds));
  }

  private getManualActionText(): string {
    if (this.manualStage === MANUAL_STAGE_IDLE) {
      return '先开始训练';
    }
    if (this.manualStage === MANUAL_STAGE_WORK && this.manualCurrentSet >= this.getSetCount()) {
      return '完成训练';
    }
    if (this.manualStage === MANUAL_STAGE_WORK) {
      return '进入休息';
    }
    if (this.manualStage === MANUAL_STAGE_REST) {
      return '开始下一组';
    }
    return '训练已完成';
  }

  private advanceManualStage(): void {
    if (this.getActiveMode() !== EXERCISE_MODE_SET_TIMER || this.setTimerMode !== SET_TIMER_MODE_MANUAL) {
      return;
    }
    if (this.sessionElapsedSeconds === 0) {
      this.sessionNotice = '请先开始训练。';
      return;
    }
    if (this.manualStage === MANUAL_STAGE_WORK && this.manualCurrentSet >= this.getSetCount()) {
      this.manualStage = MANUAL_STAGE_DONE;
      this.clearSessionTimer();
      this.sessionRunning = false;
      this.handleStageReminder('全部训练已完成');
      this.sessionNotice = '手动组计时已完成，点击“结束并记录”即可保存。';
      return;
    }
    if (this.manualStage === MANUAL_STAGE_WORK) {
      this.manualStage = MANUAL_STAGE_REST;
      this.manualStageElapsedSeconds = 0;
      this.handleStageReminder(`第 ${this.manualCurrentSet} 组休息中`);
      return;
    }
    if (this.manualStage === MANUAL_STAGE_REST) {
      this.manualCurrentSet += 1;
      this.manualStage = MANUAL_STAGE_WORK;
      this.manualStageElapsedSeconds = 0;
      this.handleStageReminder(`第 ${this.manualCurrentSet} 组训练中`);
    }
  }

  private getStageTitle(): string {
    if (this.getActiveMode() !== EXERCISE_MODE_SET_TIMER) {
      if (this.sessionElapsedSeconds === 0) {
        return '等待开始';
      }
      return this.sessionRunning ? '训练进行中' : '训练已暂停';
    }
    if (this.setTimerMode === SET_TIMER_MODE_AUTO) {
      return getSetTimerStageText(this.getDraft(), this.sessionElapsedSeconds);
    }
    if (this.manualStage === MANUAL_STAGE_WORK) {
      return `第 ${this.manualCurrentSet} 组训练中`;
    }
    if (this.manualStage === MANUAL_STAGE_REST) {
      return `第 ${this.manualCurrentSet} 组休息中`;
    }
    if (this.manualStage === MANUAL_STAGE_DONE) {
      return '全部训练已完成';
    }
    return '等待开始';
  }

  private getStageDetailText(): string {
    if (this.getActiveMode() !== EXERCISE_MODE_SET_TIMER) {
      return this.getMetrics().durationMinutes > 0 ? `目标时长 ${this.getMetrics().durationText}` : '按实际训练时长实时估算热量';
    }
    if (this.setTimerMode === SET_TIMER_MODE_AUTO) {
      return `阶段剩余 ${getSetTimerStageRemainingText(this.getDraft(), this.sessionElapsedSeconds)} · 总剩余 ${formatClockText(Math.max(0, getSetTimerTotalSeconds(this.getDraft()) - this.sessionElapsedSeconds))}`;
    }
    if (this.manualStage === MANUAL_STAGE_WORK) {
      return `本组训练 ${formatClockText(this.manualStageElapsedSeconds)} / ${formatClockText(this.getWorkDurationSeconds())}`;
    }
    if (this.manualStage === MANUAL_STAGE_REST) {
      return `本组休息 ${formatClockText(this.manualStageElapsedSeconds)} / ${formatClockText(this.getRestDurationSeconds())}`;
    }
    return '手动组计时已完成';
  }

  private getProgressWidth(): string {
    let progressValue: number = 0;
    if (this.getActiveMode() === EXERCISE_MODE_SET_TIMER && this.setTimerMode === SET_TIMER_MODE_AUTO) {
      progressValue = getSetTimerProgress(this.getDraft(), this.sessionElapsedSeconds);
    } else {
      let targetSeconds: number = Math.round(this.getMetrics().durationMinutes * 60);
      if (targetSeconds > 0) {
        progressValue = this.sessionElapsedSeconds / targetSeconds;
      }
    }
    if (progressValue <= 0) {
      return '0%';
    }
    if (progressValue >= 1) {
      return '100%';
    }
    if (progressValue < 0.08) {
      return '8%';
    }
    return `${Math.round(progressValue * 100)}%`;
  }

  private async finishAndSaveSession(): Promise<void> {
    if (this.sessionElapsedSeconds <= 0) {
      this.sessionNotice = '还没有训练记录。';
      return;
    }
    this.clearSessionTimer();
    this.sessionRunning = false;
    let sessionCalories: number = Math.round(this.getLiveCalories() * 10) / 10;
    let currentMetrics: WorkoutMetrics = this.getMetrics();
    let currentRecords: WorkoutRecord[] = deserializeWorkoutRecords(this.workoutRecordText);
    let nextRecord: WorkoutRecord = {
      id: `${Date.now()}`,
      date: formatDate(new Date()),
      name: currentMetrics.exerciseName,
      calories: sessionCalories,
      durationSeconds: this.sessionElapsedSeconds,
      exerciseId: this.selectedExerciseId,
      planId: this.currentExercisePlanIdText,
      distanceKm: currentMetrics.distanceKm,
      count: currentMetrics.count
    };
    nextRecord.id = `local-workout-record-${Date.now()}-${Math.round(Math.random() * 1000)}`;
    currentRecords.unshift(nextRecord);
    this.workoutRecordText = serializeWorkoutRecords(currentRecords);
    let result = await syncOperationNowOrQueue(this.buildSyncState(),
      createWorkoutRecordCreateOperation(nextRecord, serializeExerciseDraft(this.getDraft())));
    this.applySyncState(result.state);
    this.syncDraft();
    this.currentExercisePlanIdText = '';
    this.goBack();
  }

  private goBack(): void {
    this.currentExercisePlanIdText = '';
    try {
      this.getUIContext().getRouter().back();
    } catch (error) {
      this.sessionNotice = '返回失败，请重试。';
    }
  }

  @Builder
  buildInputField(title: string, placeholder: string, textValue: string, unit: string, field: string, unitColor: string, unitBackground: string) {
    Column({ space: 8 }) {
      Text(title)
        .fontSize(12)
        .fontColor('#5373A6')
      Row({ space: 8 }) {
        TextInput({ placeholder: placeholder, text: textValue })
          .fontSize(16)
          .fontColor(PRIMARY_TEXT_COLOR)
          .height(46)
          .layoutWeight(1)
          .padding({ left: 12, right: 12 })
          .backgroundColor('#F5F8FF')
          .borderRadius(16)
          .onChange((value: string) => {
            this.updateWorkoutField(field, value);
          })
        Text(unit)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(unitColor)
          .padding({ left: 12, right: 12, top: 11, bottom: 11 })
          .backgroundColor(unitBackground)
          .borderRadius(14)
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  buildTopSwitchBar() {
    Row() {
      // 左侧：返回箭头
      Image($r('sys.media.ohos_ic_back'))
        .width(22)
        .height(22)
        .borderRadius(21)
        .onClick(() => {
          this.goBack();
        })

      // 中间：标题（自动居中）
      Text("训练详情")
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(PRIMARY_TEXT_COLOR)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      // 右侧：左右切换训练（保留）
      Row({ space: 8 }) {
        Button('<')
          .width(42)
          .height(42)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F6BFF')
          .backgroundColor('#EAF2FF')
          .borderRadius(21)
          .onClick(() => {
            this.switchToAdjacentExercise(-1);
          })

        Button('>')
          .width(42)
          .height(42)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F6BFF')
          .backgroundColor('#EAF2FF')
          .borderRadius(21)
          .onClick(() => {
            this.switchToAdjacentExercise(1);
          })
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .padding({ left: 16, right: 16, top: 12, bottom: 14 })
    .backgroundColor(SURFACE_BACKGROUND_COLOR)
    .border({
      color: '#D8E4F2',
      width: {
        top: 1
      }
    })
  }

  build() {
    Column() {
      //顶部固定导航栏
      this.buildTopSwitchBar() // 直接把底部栏放顶部

      //原来的页面内容
      Scroll() {
      Column({ space: 18 }) {
        Row() {
          Column({ space: 4 }) {
            Text(this.getMetrics().exerciseName)
              .fontSize(26)
              .fontWeight(FontWeight.Bolder)
              .fontColor(PRIMARY_TEXT_COLOR)

            Text('训练、计时和提醒都集中在这一页。')
              .fontSize(13)
              .fontColor(SECONDARY_TEXT_COLOR)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text(this.getCompactCalorieHint())
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .backgroundColor('#0F6BFF')
            .borderRadius(999)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Column({ space: 14 }) {
          if (this.canEditClockTarget()) {
            Row({ space: 6 }) {
              TextPicker({ range: this.getHourPickerRange(), selected: this.getWheelUnitValue('hour') })
                .canLoop(false)
                .width(92)
                .height(180)
                .backgroundColor('#FFFFFF')
                .borderRadius(22)
                .onChange((_: string | string[], index: number | number[]) => {
                  this.updateClockWheelSelection('hour', this.getPickerSelectedIndex(index));
                })

              Text(':')
                .fontSize(28)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')

              TextPicker({ range: this.getMinuteSecondPickerRange(), selected: this.getWheelUnitValue('minute') })
                .canLoop(true)
                .width(92)
                .height(180)
                .backgroundColor('#FFFFFF')
                .borderRadius(22)
                .onChange((_: string | string[], index: number | number[]) => {
                  this.updateClockWheelSelection('minute', this.getPickerSelectedIndex(index));
                })

              Text(':')
                .fontSize(28)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')

              TextPicker({ range: this.getMinuteSecondPickerRange(), selected: this.getWheelUnitValue('second') })
                .canLoop(true)
                .width(92)
                .height(180)
                .backgroundColor('#FFFFFF')
                .borderRadius(22)
                .onChange((_: string | string[], index: number | number[]) => {
                  this.updateClockWheelSelection('second', this.getPickerSelectedIndex(index));
                })
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
          } else {
            Text(this.getClockRowText(-1))
              .fontSize(28)
              .fontColor('#FFFFFF')
              .opacity(0.18)

            Text(this.getClockRowText(0))
              .fontSize(54)
              .fontWeight(FontWeight.Bolder)
              .fontColor('#FFFFFF')

            Text(this.getClockRowText(1))
              .fontSize(28)
              .fontColor('#FFFFFF')
              .opacity(0.18)

            Row() {
              Text('时').layoutWeight(1).textAlign(TextAlign.Center).fontSize(11).fontColor('#E3EEFF')
              Text('分').layoutWeight(1).textAlign(TextAlign.Center).fontSize(11).fontColor('#E3EEFF')
              Text('秒').layoutWeight(1).textAlign(TextAlign.Center).fontSize(11).fontColor('#E3EEFF')
            }
            .width('100%')
          }

          Text(this.getClockCaptionText())
            .fontSize(12)
            .fontColor('#E3EEFF')

          Text(this.getStageTitle())
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')

          Text(this.getStageDetailText())
            .fontSize(13)
            .lineHeight(20)
            .fontColor('#EFF6FF')

          Row({ space: 10 }) {
            Column({ space: 4 }) {
              Text('已训练')
                .fontSize(11)
                .fontColor('#E3EEFF')
              Text(formatClockText(this.sessionElapsedSeconds))
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Column({ space: 4 }) {
              Text('目标')
                .fontSize(11)
                .fontColor('#E3EEFF')
              Text(this.getMetrics().durationText)
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Column({ space: 4 }) {
              Text('提醒')
                .fontSize(11)
                .fontColor('#E3EEFF')
              Text(`${this.reminderCount} 次`)
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')

          if (this.canEditClockTarget()) {
            Column({ space: 6 }) {
              Text(this.getClockAdjustmentPrimaryText())
                .fontSize(12)
                .fontColor('#E3EEFF')

              if (this.getClockAdjustmentSecondaryText().length > 0) {
                Text(this.getClockAdjustmentSecondaryText())
                  .fontSize(11)
                  .fontColor('#EFF6FF')
              }
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
          }

          Row({ space: 10 }) {
            Button(this.getSessionActionText())
              .layoutWeight(1)
              .height(44)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor('#0F6BFF')
              .backgroundColor('#FFFFFF')
              .borderRadius(18)
              .onClick(() => { this.toggleSession(); })
            Button('重置')
              .width(88)
              .height(44)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
              .backgroundColor('#0F6BFF')
              .borderRadius(18)
              .onClick(() => { this.resetSession('训练已重置。'); })
          }
          .width('100%')

          if (this.getActiveMode() === EXERCISE_MODE_SET_TIMER && this.setTimerMode === SET_TIMER_MODE_MANUAL) {
            Button(this.getManualActionText())
              .width('100%')
              .height(42)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#0F6BFF')
              .backgroundColor('#FFFFFF')
              .borderRadius(18)
              .onClick(() => { this.advanceManualStage(); })
          }

          Button('结束并记录')
            .width('100%')
            .height(46)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .backgroundColor('#FF7A59')
            .borderRadius(18)
            .onClick(() => { this.finishAndSaveSession(); })

          Row({ space: 10 }) {
            Button(this.reminderEnabled ? '提醒已开' : '提醒已关')
              .layoutWeight(1)
              .height(38)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.reminderEnabled ? '#0F6BFF' : '#FFFFFF')
              .backgroundColor(this.reminderEnabled ? '#FFFFFF' : '#14B8A6')
              .borderRadius(16)
              .onClick(() => {
                this.reminderEnabled = !this.reminderEnabled;
              })
            Button(this.feedbackStyle === FEEDBACK_STYLE_ALARM ? '闹钟效果' : '普通提醒')
              .layoutWeight(1)
              .height(38)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#0F6BFF')
              .backgroundColor('#FFFFFF')
              .borderRadius(16)
              .onClick(() => {
                this.feedbackStyle = this.feedbackStyle === FEEDBACK_STYLE_ALARM
                  ? FEEDBACK_STYLE_STANDARD
                  : FEEDBACK_STYLE_ALARM;
                this.sessionNotice = this.feedbackStyle === FEEDBACK_STYLE_ALARM
                  ? '提醒方式已切换为闹钟式连续提醒。'
                  : '提醒方式已切换为普通提醒。';
              })
          }
          .width('100%')

          Stack({ alignContent: Alignment.Start }) {
            Text('').width('100%').height(8).backgroundColor('#FFFFFF').opacity(0.2).borderRadius(999)
            Text('').width(this.getProgressWidth()).height(8).backgroundColor('#FFFFFF').borderRadius(999)
          }
          .width('100%')

          Text(this.lastReminderText)
            .fontSize(12)
            .lineHeight(18)
            .fontColor('#EFF6FF')

          Text(this.sessionNotice)
            .fontSize(12)
            .lineHeight(18)
            .fontColor('#E3EEFF')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(20)
        .backgroundColor(this.getSelectedOption().accentColor)
        .borderRadius(28)

        if (this.getProfileReminderDisplayText() !== '资料完整，可以直接用于 BMI 和热量估算。') {
          Text(`${this.getProfileReminderDisplayText()} 缺少体重时热量会显示为 --。`)
            .fontSize(13)
            .lineHeight(20)
            .fontColor('#FF6B57')
            .width('100%')
            .padding(14)
            .backgroundColor('#FFF0F6')
            .borderRadius(18)
        }

        if (this.selectedExerciseId === 'custom') {
          Column({ space: 12 }) {
            Text('自定义模板')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor(PRIMARY_TEXT_COLOR)
            TextInput({ placeholder: '例如 羽毛球、爬楼梯', text: this.customName })
              .fontSize(16)
              .fontColor(PRIMARY_TEXT_COLOR)
              .height(46)
              .width('100%')
              .padding({ left: 12, right: 12 })
              .backgroundColor('#F5F8FF')
              .borderRadius(16)
              .onChange((value: string) => {
                this.updateWorkoutField('customName', value);
              })
            ForEach(CUSTOM_MODE_OPTIONS, (option: ExerciseOption) => {
              Button(option.name)
                .width('100%')
                .height(42)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.customMode === option.id ? '#FFFFFF' : PRIMARY_TEXT_COLOR)
                .backgroundColor(this.customMode === option.id ? '#0F6BFF' : '#F5F8FF')
                .borderRadius(16)
                .onClick(() => {
                  this.selectCustomMode(option.id);
                })
            }, (option: ExerciseOption) => option.id)
            Row({ space: 10 }) {
              ForEach(CUSTOM_INTENSITY_OPTIONS, (option: CustomIntensityOption) => {
                Button(option.label)
                  .layoutWeight(1)
                  .height(42)
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.customIntensity === option.id ? '#FFFFFF' : PRIMARY_TEXT_COLOR)
                  .backgroundColor(this.customIntensity === option.id ? '#7B61FF' : '#F2F0FF')
                  .borderRadius(16)
                  .onClick(() => {
                    this.selectCustomIntensity(option.id);
                  })
              }, (option: CustomIntensityOption) => option.id)
            }
            .width('100%')
            Row({ space: 12 }) {
              Button(this.selectedSavedWorkoutId.length > 0 ? '更新模板' : '保存模板')
                .layoutWeight(1)
                .height(44)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor('#FFFFFF')
                .backgroundColor('#7B61FF')
                .borderRadius(18)
                .onClick(() => {
                  this.saveCurrentCustomWorkout();
                })
              Button('删除模板')
                .layoutWeight(1)
                .height(44)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor('#7B61FF')
                .backgroundColor('#F2F0FF')
                .borderRadius(18)
                .onClick(() => {
                  this.deleteCurrentCustomWorkout();
                })
            }
            .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(18)
          .backgroundColor(SURFACE_BACKGROUND_COLOR)
          .borderRadius(24)
        }

        Column({ space: 12 }) {
          Text('训练设置')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_TEXT_COLOR)
          if (this.getActiveMode() === EXERCISE_MODE_SET_TIMER) {
            Row({ space: 10 }) {
              Button('自动提醒')
                .layoutWeight(1)
                .height(40)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.setTimerMode === SET_TIMER_MODE_AUTO ? '#FFFFFF' : PRIMARY_TEXT_COLOR)
                .backgroundColor(this.setTimerMode === SET_TIMER_MODE_AUTO ? '#0F6BFF' : '#EAF2FF')
                .borderRadius(16)
                .onClick(() => {
                  this.setTimerMode = SET_TIMER_MODE_AUTO;
                  this.resetSession('已切换到自动组计时。');
                })
              Button('手动切换')
                .layoutWeight(1)
                .height(40)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.setTimerMode === SET_TIMER_MODE_MANUAL ? '#FFFFFF' : PRIMARY_TEXT_COLOR)
                .backgroundColor(this.setTimerMode === SET_TIMER_MODE_MANUAL ? '#7B61FF' : '#F2F0FF')
                .borderRadius(16)
                .onClick(() => {
                  this.setTimerMode = SET_TIMER_MODE_MANUAL;
                  this.resetSession('已切换到手动组计时。');
                })
            }
            .width('100%')
          }
          if (this.getActiveMode() === EXERCISE_MODE_DURATION) {
            this.buildInputField('训练时长', '30', this.durationMinutes, '分钟', 'durationMinutes', '#10B981', '#ECFFF4')
          }
          if (this.getActiveMode() === EXERCISE_MODE_DISTANCE_PACE) {
            Row({ space: 12 }) {
              Column() {
                this.buildInputField('路程', '5', this.distanceKm, 'km', 'distanceKm', '#0F6BFF', '#EAF2FF')
              }
              .layoutWeight(1)
              Column() {
                this.buildInputField('配速', '6', this.paceMinutes, '分/km', 'paceMinutes', '#FF7A59', '#FFF0F6')
              }
              .layoutWeight(1)
            }
            .width('100%')
          }
          if (this.getActiveMode() === EXERCISE_MODE_DISTANCE_SPEED) {
            Row({ space: 12 }) {
              Column() {
                this.buildInputField('路程', '10', this.distanceKm, 'km', 'distanceKm', '#0F6BFF', '#EAF2FF')
              }
              .layoutWeight(1)
              Column() {
                this.buildInputField('速度', '18', this.speedKmH, 'km/h', 'speedKmH', '#10B981', '#ECFFF4')
              }
              .layoutWeight(1)
            }
            .width('100%')
          }
          if (this.getActiveMode() === EXERCISE_MODE_COUNT_RATE) {
            Row({ space: 12 }) {
              Column() {
                this.buildInputField('个数', '300', this.count, '次', 'count', '#C14D7F', '#FFE7F1')
              }
              .layoutWeight(1)
              Column() {
                this.buildInputField('节奏', '120', this.cadencePerMinute, '次/分', 'cadencePerMinute', '#0F6BFF', '#EAF2FF')
              }
              .layoutWeight(1)
            }
            .width('100%')
          }
          if (this.getActiveMode() === EXERCISE_MODE_SET_TIMER) {
            Column({ space: 12 }) {
              Row({ space: 12 }) {
                Column() {
                  this.buildInputField('组数', '4', this.sets, '组', 'sets', '#0F6BFF', '#EAF2FF')
                }
                .layoutWeight(1)
                Column() {
                  this.buildInputField('训练', '40', this.workSeconds, '秒', 'workSeconds', '#FF7A59', '#FFF0F6')
                }
                .layoutWeight(1)
              }
              .width('100%')
              this.buildInputField('休息', '20', this.restSeconds, '秒', 'restSeconds', '#10B981', '#ECFFF4')
            }
            .width('100%')
          }
          Text(this.getMetrics().validationMessage.length > 0 ? this.getMetrics().validationMessage : this.getMetrics().summaryText)
            .fontSize(13)
            .lineHeight(20)
            .fontColor(this.getMetrics().validationMessage.length > 0 ? '#FF5A7A' : '#667085')
          if (this.getMetrics().validationMessage.length === 0) {
            Text(`预计 ${this.getMetrics().durationText} · ${this.getMetrics().calorieText}`)
              .fontSize(12)
              .fontColor('#5373A6')
          }
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(18)
        .backgroundColor(SURFACE_BACKGROUND_COLOR)
        .borderRadius(24)

      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 24, bottom: this.getContentBottomPadding() })
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
    .backgroundColor(PAGE_BACKGROUND_COLOR)
  }
}
