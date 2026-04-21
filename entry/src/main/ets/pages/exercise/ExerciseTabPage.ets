import {
  PAGE_BACKGROUND_COLOR,
  PRIMARY_TEXT_COLOR,
  SECONDARY_TEXT_COLOR,
  SURFACE_BACKGROUND_COLOR
} from '../../constants/AppTheme';
import {
  EXERCISE_OPTIONS,
  ExerciseDraft,
  ExerciseOption,
  SavedCustomWorkout,
  createDefaultExerciseDraft
} from '../../models/ExerciseOption';
import { UserProfile } from '../../models/UserProfile';
import {
  getActiveWorkoutMode,
  createDraftFromSavedCustomWorkout,
  deserializeExerciseDraft,
  deserializeSavedCustomWorkouts,
  deserializeWorkoutRecords,
  getWorkoutModeLabel,
  getWorkoutTitle,
  serializeExerciseDraft,
  serializeUserProfile
} from '../../utils/ExerciseHelper';
import { formatDate } from '../../utils/WeightRecordHelper';
import { EXERCISE_STORAGE_READY } from '../../utils/ExerciseStorage';
import { WorkoutRecord } from '../../models/WorkoutRecord';
import { WorkoutPlanItem } from '../../models/WorkoutPlan';
import {
  createWorkoutPlanItem,
  deserializeWorkoutPlans,
  formatWorkoutPlanGoalValue,
  getWorkoutPlanGoalFromDraft,
  getWorkoutPlanGoalLabel,
  getWorkoutPlanGoalText,
  getWorkoutPlanGoalUnit,
  serializeWorkoutPlans
} from '../../utils/WorkoutPlanHelper';

interface DailyWorkoutSummary {
  calories: number;
  count: number;
}

interface CalendarDayItem {
  key: string;
  dateText: string;
  dayNumber: number;
  isCurrentMonth: boolean;
  isToday: boolean;
  planCount: number;
}

@Component
export struct ExerciseTabPage {
  @Link currentTabIndex: number;
  @Link userProfile: UserProfile;
  @StorageLink('savedCustomWorkoutText') savedCustomWorkoutText: string = '';
  @StorageLink('workoutRecordText') workoutRecordText: string = '';
  @StorageLink('workoutPlanText') workoutPlanText: string = '';
  @StorageLink('currentExerciseDraftText') currentExerciseDraftText: string = '';
  @StorageLink('currentExerciseProfileText') currentExerciseProfileText: string = '';
  @StorageLink('currentEditingSavedWorkoutIdText') currentEditingSavedWorkoutIdText: string = '';
  @StorageLink('currentExercisePlanIdText') currentExercisePlanIdText: string = '';
  @StorageLink('exercisePlanPickerVisible') exercisePlanPickerVisible: boolean = false;

  @State savedCustomWorkouts: SavedCustomWorkout[] = [];
  @State workoutPlans: WorkoutPlanItem[] = [];
  @State workoutPlanRenderVersion: number = 0;
  @State planListCollapsed: boolean = false;
  @State selectedPlanDate: string = formatDate(new Date());
  @State calendarYear: number = new Date().getFullYear();
  @State calendarMonth: number = new Date().getMonth();
  @State planPickerVisible: boolean = false;
  @State planTitleInput: string = '';
  @State planNotesInput: string = '';
  @State planGoalValueInput: string = '';
  @State selectedPlanExerciseId: string = '';
  @State selectedPlanSavedWorkoutId: string = '';

  aboutToAppear(): void {
    EXERCISE_STORAGE_READY;
    this.exercisePlanPickerVisible = false;
    this.syncSavedCustomWorkoutsFromStorage();
    this.syncWorkoutPlansFromStorage();
  }

  aboutToDisappear(): void {
    this.exercisePlanPickerVisible = false;
  }

  private syncSavedCustomWorkoutsFromStorage(): void {
    this.savedCustomWorkouts = deserializeSavedCustomWorkouts(this.savedCustomWorkoutText);
  }

  private syncWorkoutPlansFromStorage(): void {
    this.workoutPlans = deserializeWorkoutPlans(this.workoutPlanText);
    this.workoutPlanRenderVersion += 1;
  }

  private getAllWorkoutPlans(): WorkoutPlanItem[] {
    return this.workoutPlans;
  }

  private saveWorkoutPlans(nextPlans: WorkoutPlanItem[]): void {
    this.workoutPlans = nextPlans.slice();
    this.workoutPlanText = serializeWorkoutPlans(nextPlans);
    this.workoutPlanRenderVersion += 1;
  }

  private getTodaySummary(): DailyWorkoutSummary {
    let records: WorkoutRecord[] = deserializeWorkoutRecords(this.workoutRecordText);
    let today: string = formatDate(new Date());
    let totalCalories: number = 0;
    let todayCount: number = 0;

    for (let index = 0; index < records.length; index++) {
      if (records[index].date === today) {
        totalCalories += records[index].calories;
        todayCount += 1;
      }
    }

    return {
      calories: totalCalories,
      count: todayCount
    };
  }

  private getTodayCaloriesText(): string {
    return `${this.getTodaySummary().calories.toFixed(1)} kcal`;
  }

  private getTodayWorkoutCountText(): string {
    let summary: DailyWorkoutSummary = this.getTodaySummary();
    return summary.count > 0 ? `已完成 ${summary.count} 次训练` : '今天还没有记录训练';
  }

  private getExercisePickerCountText(): string {
    return `${EXERCISE_OPTIONS.length + this.savedCustomWorkouts.length} 项训练可选`;
  }

  private getWorkoutRecords(): WorkoutRecord[] {
    return deserializeWorkoutRecords(this.workoutRecordText);
  }

  private openDraft(draftText: string, savedWorkoutId: string, planId: string = ''): void {
    this.currentExerciseDraftText = draftText;
    this.currentExerciseProfileText = serializeUserProfile(this.userProfile);
    this.currentEditingSavedWorkoutIdText = savedWorkoutId;
    this.currentExercisePlanIdText = planId;
    try {
      let routeTask: Promise<void> = this.getUIContext().getRouter().pushUrl({
        url: 'pages/exercise/ExerciseDetailPage'
      });
      routeTask.catch(() => {
      });
    } catch (error) {
    }
  }

  private openDraftFromWorkout(draft: ExerciseDraft, savedWorkoutId: string, planId: string = ''): void {
    this.openDraft(serializeExerciseDraft(draft), savedWorkoutId, planId);
  }

  private createDraftFromExerciseOption(option: ExerciseOption): ExerciseDraft {
    let draft: ExerciseDraft = createDefaultExerciseDraft();
    draft.exerciseId = option.id;
    if (option.id !== 'custom') {
      draft.customName = '';
    }
    return draft;
  }

  private selectExercise(optionId: string): void {
    let draft: ExerciseDraft = this.createDraftFromExerciseOption(this.findExerciseOptionById(optionId));
    this.openDraftFromWorkout(draft, '');
  }

  private selectSavedCustomWorkout(savedWorkout: SavedCustomWorkout): void {
    let draft: ExerciseDraft = createDraftFromSavedCustomWorkout(savedWorkout);
    this.openDraftFromWorkout(draft, savedWorkout.id);
  }

  private addPlanFromDraft(draft: ExerciseDraft, savedWorkoutId: string, goalValue: number): void {
    let nextPlans: WorkoutPlanItem[] = this.getAllWorkoutPlans().slice();
    nextPlans.unshift(createWorkoutPlanItem(
      this.selectedPlanDate,
      draft,
      this.userProfile,
      this.planTitleInput,
      this.planNotesInput,
      savedWorkoutId,
      goalValue
    ));

    this.saveWorkoutPlans(nextPlans);
    this.planPickerVisible = false;
    this.exercisePlanPickerVisible = false;
    this.resetPlanPickerInputs();
    this.resetPlanPickerSelection();
  }

  private resetPlanPickerInputs(): void {
    this.planTitleInput = '';
    this.planNotesInput = '';
  }

  private resetPlanPickerSelection(): void {
    this.selectedPlanExerciseId = '';
    this.selectedPlanSavedWorkoutId = '';
    this.planGoalValueInput = '';
  }

  private hasSelectedPlanChoice(): boolean {
    return this.selectedPlanExerciseId.length > 0 || this.selectedPlanSavedWorkoutId.length > 0;
  }

  private openPlanPicker(): void {
    this.resetPlanPickerInputs();
    this.resetPlanPickerSelection();
    this.planPickerVisible = true;
    this.exercisePlanPickerVisible = true;
  }

  private closePlanPicker(): void {
    this.planPickerVisible = false;
    this.exercisePlanPickerVisible = false;
    this.resetPlanPickerInputs();
    this.resetPlanPickerSelection();
  }

  private openPlanPickerForExercise(option: ExerciseOption): void {
    this.resetPlanPickerInputs();
    this.resetPlanPickerSelection();
    this.selectPlanExercise(option);
    this.planPickerVisible = true;
    this.exercisePlanPickerVisible = true;
  }

  private openPlanPickerForSavedWorkout(savedWorkout: SavedCustomWorkout): void {
    this.resetPlanPickerInputs();
    this.resetPlanPickerSelection();
    this.selectPlanSavedWorkout(savedWorkout);
    this.planPickerVisible = true;
    this.exercisePlanPickerVisible = true;
  }

  private removeWorkoutPlan(planId: string): void {
    let currentPlans: WorkoutPlanItem[] = this.getAllWorkoutPlans();
    let nextPlans: WorkoutPlanItem[] = [];
    for (let index = 0; index < currentPlans.length; index++) {
      if (currentPlans[index].id !== planId) {
        nextPlans.push(currentPlans[index]);
      }
    }
    this.saveWorkoutPlans(nextPlans);
  }

  private openWorkoutPlan(plan: WorkoutPlanItem): void {
    this.openDraft(plan.draftText, plan.savedWorkoutId, plan.id);
  }

  private findExerciseOptionById(optionId: string): ExerciseOption {
    for (let index = 0; index < EXERCISE_OPTIONS.length; index++) {
      if (EXERCISE_OPTIONS[index].id === optionId) {
        return EXERCISE_OPTIONS[index];
      }
    }
    return EXERCISE_OPTIONS[0];
  }

  private findSavedWorkoutById(savedWorkoutId: string): SavedCustomWorkout | undefined {
    for (let index = 0; index < this.savedCustomWorkouts.length; index++) {
      if (this.savedCustomWorkouts[index].id === savedWorkoutId) {
        return this.savedCustomWorkouts[index];
      }
    }
    return undefined;
  }

  private copyWorkoutPlan(plan: WorkoutPlanItem, manuallyCompleted: boolean = plan.manuallyCompleted,
    collapsed: boolean = plan.collapsed): WorkoutPlanItem {
    return {
      id: plan.id,
      date: plan.date,
      title: plan.title,
      summary: plan.summary,
      notes: plan.notes,
      draftText: plan.draftText,
      savedWorkoutId: plan.savedWorkoutId,
      accentColor: plan.accentColor,
      goalType: plan.goalType,
      goalValue: plan.goalValue,
      manuallyCompleted: manuallyCompleted,
      collapsed: collapsed
    };
  }

  private selectPlanExercise(option: ExerciseOption): void {
    this.selectedPlanExerciseId = option.id;
    this.selectedPlanSavedWorkoutId = '';
    this.syncPlanGoalValueInput(this.createDraftFromExerciseOption(option));
  }

  private selectPlanSavedWorkout(savedWorkout: SavedCustomWorkout): void {
    this.selectedPlanExerciseId = 'custom';
    this.selectedPlanSavedWorkoutId = savedWorkout.id;
    this.syncPlanGoalValueInput(createDraftFromSavedCustomWorkout(savedWorkout));
  }

  private getSelectedPlanDraft(): ExerciseDraft {
    if (this.selectedPlanSavedWorkoutId.length > 0) {
      let savedWorkout = this.findSavedWorkoutById(this.selectedPlanSavedWorkoutId);
      if (savedWorkout) {
        return createDraftFromSavedCustomWorkout(savedWorkout);
      }
    }
    if (this.selectedPlanExerciseId.length === 0) {
      return createDefaultExerciseDraft();
    }
    return this.createDraftFromExerciseOption(this.findExerciseOptionById(this.selectedPlanExerciseId));
  }

  private syncPlanGoalValueInput(draft: ExerciseDraft): void {
    let goal = getWorkoutPlanGoalFromDraft(draft);
    this.planGoalValueInput = formatWorkoutPlanGoalValue(goal.goalType, goal.goalValue);
  }

  private getSelectedPlanGoalType(): string {
    if (!this.hasSelectedPlanChoice()) {
      return 'duration';
    }
    return getWorkoutPlanGoalFromDraft(this.getSelectedPlanDraft()).goalType;
  }

  private getSelectedPlanGoalPlaceholder(): string {
    if (!this.hasSelectedPlanChoice()) {
      return '请先选择训练';
    }
    let goal = getWorkoutPlanGoalFromDraft(this.getSelectedPlanDraft());
    return formatWorkoutPlanGoalValue(goal.goalType, goal.goalValue);
  }

  private getSelectedPlanGoalLabel(): string {
    if (!this.hasSelectedPlanChoice()) {
      return '目标量';
    }
    return getWorkoutPlanGoalLabel(this.getSelectedPlanGoalType());
  }

  private getSelectedPlanGoalUnit(): string {
    if (!this.hasSelectedPlanChoice()) {
      return '';
    }
    return getWorkoutPlanGoalUnit(this.getSelectedPlanGoalType());
  }

  private getSelectedPlanDisplayName(): string {
    if (this.selectedPlanSavedWorkoutId.length > 0) {
      let savedWorkout = this.findSavedWorkoutById(this.selectedPlanSavedWorkoutId);
      return savedWorkout ? savedWorkout.name : '自定义模板';
    }
    if (this.selectedPlanExerciseId.length === 0) {
      return '未选择';
    }
    return this.findExerciseOptionById(this.selectedPlanExerciseId).name;
  }

  private isPlanExerciseSelected(option: ExerciseOption): boolean {
    return this.selectedPlanSavedWorkoutId.length === 0 && this.selectedPlanExerciseId === option.id;
  }

  private isPlanSavedWorkoutSelected(savedWorkout: SavedCustomWorkout): boolean {
    return this.selectedPlanSavedWorkoutId === savedWorkout.id;
  }

  private confirmPlanCreation(): void {
    if (!this.hasSelectedPlanChoice()) {
      return;
    }
    let goalValue = Number(this.planGoalValueInput.trim());
    if (isNaN(goalValue) || goalValue <= 0) {
      this.planGoalValueInput = this.getSelectedPlanGoalPlaceholder();
      return;
    }
    this.addPlanFromDraft(
      this.getSelectedPlanDraft(),
      this.selectedPlanSavedWorkoutId,
      goalValue
    );
  }

  private getMatchedRecordsForPlan(plan: WorkoutPlanItem): WorkoutRecord[] {
    let draft = deserializeExerciseDraft(plan.draftText);
    let exerciseName = getWorkoutTitle(draft);
    let result: WorkoutRecord[] = [];
    let records = this.getWorkoutRecords();

    for (let index = 0; index < records.length; index++) {
      let currentRecord = records[index];
      if (currentRecord.planId === plan.id) {
        result.push(currentRecord);
        continue;
      }
      if (currentRecord.planId.trim().length > 0 || currentRecord.date !== plan.date) {
        continue;
      }

      let matchesExerciseId = currentRecord.exerciseId.trim().length > 0 &&
        currentRecord.exerciseId === draft.exerciseId;
      let matchesTitle = currentRecord.name === exerciseName || currentRecord.name === plan.title;

      if (matchesExerciseId && (draft.exerciseId !== 'custom' || matchesTitle)) {
        result.push(currentRecord);
      } else if (matchesTitle) {
        result.push(currentRecord);
      }
    }

    return result;
  }

  private getPlanAchievedValue(plan: WorkoutPlanItem): number {
    let records = this.getMatchedRecordsForPlan(plan);
    let totalValue = 0;
    for (let index = 0; index < records.length; index++) {
      if (plan.goalType === 'distance') {
        totalValue += records[index].distanceKm;
      } else if (plan.goalType === 'count') {
        totalValue += records[index].count;
      } else {
        totalValue += records[index].durationSeconds / 60;
      }
    }
    return totalValue;
  }

  private isWorkoutPlanAutoCompleted(plan: WorkoutPlanItem): boolean {
    if (plan.goalValue <= 0) {
      return false;
    }
    return this.getPlanAchievedValue(plan) + 0.01 >= plan.goalValue;
  }

  private isWorkoutPlanCompleted(plan: WorkoutPlanItem): boolean {
    return plan.manuallyCompleted || this.isWorkoutPlanAutoCompleted(plan);
  }

  private getWorkoutPlanStatusText(plan: WorkoutPlanItem): string {
    if (this.isWorkoutPlanAutoCompleted(plan)) {
      return '自动完成';
    }
    if (plan.manuallyCompleted) {
      return '手动完成';
    }
    return getWorkoutPlanGoalText(plan.goalType, plan.goalValue);
  }

  private getWorkoutPlanTypeText(plan: WorkoutPlanItem): string {
    let draft = deserializeExerciseDraft(plan.draftText);
    return getWorkoutModeLabel(getActiveWorkoutMode(draft));
  }

  private getWorkoutPlanGoalBadgeText(plan: WorkoutPlanItem): string {
    return `目标 ${getWorkoutPlanGoalText(plan.goalType, plan.goalValue)}`;
  }

  private getWorkoutPlanProgressText(plan: WorkoutPlanItem): string {
    let achievedValue = this.getPlanAchievedValue(plan);
    let goalUnit = getWorkoutPlanGoalUnit(plan.goalType);
    let goalText = getWorkoutPlanGoalText(plan.goalType, plan.goalValue);
    if (this.isWorkoutPlanAutoCompleted(plan)) {
      return `已达成 ${formatWorkoutPlanGoalValue(plan.goalType, achievedValue)} ${goalUnit}`;
    }
    if (plan.manuallyCompleted) {
      if (achievedValue > 0) {
        return `已手动标记完成 · 当前进度 ${formatWorkoutPlanGoalValue(plan.goalType, achievedValue)} / ${formatWorkoutPlanGoalValue(plan.goalType, plan.goalValue)} ${goalUnit}`;
      }
      return '已手动标记完成';
    }
    if (achievedValue > 0) {
      return `进度 ${formatWorkoutPlanGoalValue(plan.goalType, achievedValue)} / ${formatWorkoutPlanGoalValue(plan.goalType, plan.goalValue)} ${goalUnit}`;
    }
    return `目标 ${goalText}`;
  }

  private toggleWorkoutPlanManualCompleted(planId: string): void {
    let currentPlans: WorkoutPlanItem[] = this.getAllWorkoutPlans();
    let nextPlans: WorkoutPlanItem[] = [];
    for (let index = 0; index < currentPlans.length; index++) {
      let currentPlan = currentPlans[index];
      if (currentPlan.id === planId) {
        nextPlans.push(this.copyWorkoutPlan(currentPlan, !currentPlan.manuallyCompleted, currentPlan.collapsed));
      } else {
        nextPlans.push(currentPlan);
      }
    }
    this.saveWorkoutPlans(nextPlans);
  }

  private toggleWorkoutPlanCollapsed(planId: string): void {
    let currentPlans: WorkoutPlanItem[] = this.getAllWorkoutPlans();
    let nextPlans: WorkoutPlanItem[] = [];
    for (let index = 0; index < currentPlans.length; index++) {
      let currentPlan = currentPlans[index];
      if (currentPlan.id === planId) {
        nextPlans.push(this.copyWorkoutPlan(currentPlan, currentPlan.manuallyCompleted, !currentPlan.collapsed));
      } else {
        nextPlans.push(currentPlan);
      }
    }
    this.saveWorkoutPlans(nextPlans);
  }

  private getCompletedPlanCountByDate(dateText: string): number {
    let currentPlans: WorkoutPlanItem[] = this.getAllWorkoutPlans();
    let count = 0;
    for (let index = 0; index < currentPlans.length; index++) {
      let currentPlan = currentPlans[index];
      if (currentPlan.date === dateText && this.isWorkoutPlanCompleted(currentPlan)) {
        count += 1;
      }
    }
    return count;
  }

  private getPlanCountByDate(dateText: string): number {
    let currentPlans: WorkoutPlanItem[] = this.getAllWorkoutPlans();
    let count: number = 0;
    for (let index = 0; index < currentPlans.length; index++) {
      if (currentPlans[index].date === dateText) {
        count += 1;
      }
    }
    return count;
  }

  private getPlansForSelectedDate(): WorkoutPlanItem[] {
    let renderVersion = this.workoutPlanRenderVersion;
    let currentPlans: WorkoutPlanItem[] = this.getAllWorkoutPlans();
    let result: WorkoutPlanItem[] = [];
    for (let index = 0; index < currentPlans.length + renderVersion * 0; index++) {
      if (currentPlans[index].date === this.selectedPlanDate) {
        result.push(currentPlans[index]);
      }
    }
    return result;
  }

  private getWorkoutPlanRenderKey(plan: WorkoutPlanItem): string {
    let completedFlag = this.isWorkoutPlanCompleted(plan) ? '1' : '0';
    let collapsedFlag = plan.collapsed ? '1' : '0';
    let manualFlag = plan.manuallyCompleted ? '1' : '0';
    return `${plan.id}-${collapsedFlag}-${manualFlag}-${completedFlag}-${this.workoutPlanRenderVersion}`;
  }

  private togglePlanListCollapsed(): void {
    this.planListCollapsed = !this.planListCollapsed;
  }

  private getSelectedDatePlanCountText(): string {
    let count: number = this.getPlansForSelectedDate().length;
    let completedCount: number = this.getCompletedPlanCountByDate(this.selectedPlanDate);
    if (count <= 0) {
      return '暂无计划';
    }
    if (completedCount <= 0) {
      return `${count} 项计划`;
    }
    return `${count} 项计划 · ${completedCount} 项完成`;
  }

  private formatFriendlyDate(dateText: string): string {
    let fields: string[] = dateText.split('-');
    if (fields.length < 3) {
      return dateText;
    }
    return `${fields[0]}年${Number(fields[1])}月${Number(fields[2])}日`;
  }

  private getCalendarTitle(): string {
    return `${this.calendarYear}年${this.calendarMonth + 1}月`;
  }

  private changeCalendarMonth(step: number): void {
    let nextMonth: number = this.calendarMonth + step;
    let nextYear: number = this.calendarYear;

    if (nextMonth < 0) {
      nextMonth = 11;
      nextYear -= 1;
    } else if (nextMonth > 11) {
      nextMonth = 0;
      nextYear += 1;
    }

    this.calendarYear = nextYear;
    this.calendarMonth = nextMonth;
  }

  private getCalendarDays(): CalendarDayItem[] {
    let result: CalendarDayItem[] = [];
    let monthStart = new Date(this.calendarYear, this.calendarMonth, 1);
    let offset = monthStart.getDay();
    let firstCellDate = new Date(this.calendarYear, this.calendarMonth, 1 - offset);
    let monthEnd = new Date(this.calendarYear, this.calendarMonth + 1, 0);
    let totalCellCount = Math.ceil((offset + monthEnd.getDate()) / 7) * 7;
    let todayText: string = formatDate(new Date());

    for (let index = 0; index < totalCellCount; index++) {
      let currentDate = new Date(firstCellDate.getTime());
      currentDate.setDate(firstCellDate.getDate() + index);
      let currentDateText: string = formatDate(currentDate);
      let isCurrentMonth: boolean = currentDate.getMonth() === this.calendarMonth;

      result.push({
        key: isCurrentMonth ? currentDateText : `blank-${index}`,
        dateText: isCurrentMonth ? currentDateText : '',
        dayNumber: isCurrentMonth ? currentDate.getDate() : 0,
        isCurrentMonth: isCurrentMonth,
        isToday: isCurrentMonth && currentDateText === todayText,
        planCount: isCurrentMonth ? this.getPlanCountByDate(currentDateText) : 0
      });
    }

    return result;
  }

  private getCalendarRows(): CalendarDayItem[][] {
    let days: CalendarDayItem[] = this.getCalendarDays();
    let rows: CalendarDayItem[][] = [];

    for (let index = 0; index < days.length; index += 7) {
      rows.push(days.slice(index, index + 7));
    }

    return rows;
  }

  private isSelectedCalendarDay(dateText: string): boolean {
    return dateText === this.selectedPlanDate;
  }

  private getCalendarNoteText(day: CalendarDayItem): string {
    if (!day.isCurrentMonth) {
      return '';
    }
    if (day.isToday) {
      return '今天';
    }
    return '';
  }

  @Builder
  buildPlanTitle(plan: WorkoutPlanItem) {
    Stack({ alignContent: Alignment.Start }) {
      Text(plan.title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.isWorkoutPlanCompleted(plan) ? '#667085' : PRIMARY_TEXT_COLOR)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.isWorkoutPlanCompleted(plan)) {
        Text('')
          .width('100%')
          .height(1.5)
          .backgroundColor('#98A2B3')
          .opacity(0.9)
      }
    }
    .layoutWeight(1)
  }

  @Builder
  buildCalendarCard() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 4 }) {
          Text('训练日历')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text(this.formatFriendlyDate(this.selectedPlanDate))
            .fontSize(12)
            .fontColor(SECONDARY_TEXT_COLOR)
        }
        .alignItems(HorizontalAlign.Start)

        Row({ space: 8 }) {
          Text(this.getSelectedDatePlanCountText())
            .fontSize(12)
            .fontColor('#5373A6')
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor('#EAF2FF')
            .borderRadius(999)
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)

      Row() {
        Button('<')
          .width(38)
          .height(38)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F6BFF')
          .backgroundColor('#EAF2FF')
          .borderRadius(19)
          .onClick(() => {
            this.changeCalendarMonth(-1);
          })

        Text(this.getCalendarTitle())
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(PRIMARY_TEXT_COLOR)

        Button('>')
          .width(38)
          .height(38)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#0F6BFF')
          .backgroundColor('#EAF2FF')
          .borderRadius(19)
          .onClick(() => {
            this.changeCalendarMonth(1);
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Row() {
        Text('日').layoutWeight(1).textAlign(TextAlign.Center).fontSize(12).fontColor('#94A0B4')
        Text('一').layoutWeight(1).textAlign(TextAlign.Center).fontSize(12).fontColor('#94A0B4')
        Text('二').layoutWeight(1).textAlign(TextAlign.Center).fontSize(12).fontColor('#94A0B4')
        Text('三').layoutWeight(1).textAlign(TextAlign.Center).fontSize(12).fontColor('#94A0B4')
        Text('四').layoutWeight(1).textAlign(TextAlign.Center).fontSize(12).fontColor('#94A0B4')
        Text('五').layoutWeight(1).textAlign(TextAlign.Center).fontSize(12).fontColor('#94A0B4')
        Text('六').layoutWeight(1).textAlign(TextAlign.Center).fontSize(12).fontColor('#94A0B4')
      }
      .width('100%')

      Column({ space: 4 }) {
        ForEach(this.getCalendarRows(), (week: CalendarDayItem[]) => {
          Row() {
            ForEach(week, (day: CalendarDayItem) => {
              Column({ space: 6 }) {
                if (day.isCurrentMonth) {
                  Stack({ alignContent: Alignment.Center }) {
                    if (this.isSelectedCalendarDay(day.dateText)) {
                      Text('')
                        .width(44)
                        .height(44)
                        .backgroundColor('#0F6BFF')
                        .borderRadius(22)
                    }

                    Column({ space: 3 }) {
                      Text(`${day.dayNumber}`)
                        .fontSize(18)
                        .fontWeight(this.isSelectedCalendarDay(day.dateText) ? FontWeight.Bold : FontWeight.Medium)
                        .fontColor(this.isSelectedCalendarDay(day.dateText) ? '#FFFFFF' : PRIMARY_TEXT_COLOR)

                      Text(this.getCalendarNoteText(day))
                        .fontSize(10)
                        .fontWeight(this.isSelectedCalendarDay(day.dateText) ? FontWeight.Medium : FontWeight.Regular)
                        .fontColor(this.isSelectedCalendarDay(day.dateText) ? '#EAF2FF' : (day.isToday ? '#0F6BFF' : '#98A2B3'))
                        .maxLines(1)
                    }
                    .alignItems(HorizontalAlign.Center)

                    if (day.planCount > 0) {
                      Text('')
                        .width(7)
                        .height(7)
                        .backgroundColor(this.isSelectedCalendarDay(day.dateText) ? '#FFFFFF' : '#0F6BFF')
                        .borderRadius(4)
                        .margin({ top: 44 })
                    }
                  }
                  .width(56)
                  .height(56)
                } else {
                  Text('')
                    .width(56)
                    .height(56)
                }
              }
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .width('100%')
              .height(64)
              .layoutWeight(1)
              .onClick(() => {
                if (!day.isCurrentMonth) {
                  return;
                }
                this.selectedPlanDate = day.dateText;
              })
            }, (day: CalendarDayItem) => day.key)
          }
          .width('100%')
        }, (week: CalendarDayItem[]) => week[0].key)
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(18)
    .backgroundColor(SURFACE_BACKGROUND_COLOR)
    .borderRadius(24)
  }

  @Builder
  buildPlanListCard() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Column({ space: 6 }) {
          Text('当日计划')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text(this.formatFriendlyDate(this.selectedPlanDate))
            .fontSize(12)
            .fontColor(SECONDARY_TEXT_COLOR)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.getSelectedDatePlanCountText())
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#5373A6')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor('#EAF2FF')
            .borderRadius(999)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Row({ space: 8 }) {
          if (this.getPlansForSelectedDate().length > 0) {
            Button(this.planListCollapsed ? '展开计划' : '折叠计划')
              .width(84)
              .height(34)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#5373A6')
              .backgroundColor('#EEF4FF')
              .borderRadius(17)
              .onClick(() => {
                this.togglePlanListCollapsed();
              })
          }

          Button('+ 添加')
            .width(72)
            .height(36)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .backgroundColor('#0F6BFF')
            .borderRadius(18)
            .onClick(() => {
              this.openPlanPicker();
            })
        }
        .justifyContent(FlexAlign.End)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      if (!this.planListCollapsed && this.getPlansForSelectedDate().length === 0) {
        Text('点击右上角“+ 添加”，先选择训练类型，再设置目标量加入当天计划。')
          .fontSize(13)
          .lineHeight(20)
          .fontColor(SECONDARY_TEXT_COLOR)
          .width('100%')
          .padding(14)
          .backgroundColor('#F5F8FF')
          .borderRadius(16)
      }

      if (!this.planListCollapsed) {
        ForEach(this.getPlansForSelectedDate(), (plan: WorkoutPlanItem) => {
          Column({ space: 12 }) {
            Row({ space: 12 }) {
              Button(this.isWorkoutPlanCompleted(plan) ? '✓' : '')
              .width(28)
              .height(28)
              .margin({ top: 2 })
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .backgroundColor(this.isWorkoutPlanCompleted(plan) ? '#10B981' : '#FFFFFF')
              .border({
                width: 1.5,
                color: this.isWorkoutPlanCompleted(plan) ? '#10B981' : '#CBD5E1'
              })
              .borderRadius(14)
              .onClick(() => {
                this.toggleWorkoutPlanManualCompleted(plan.id);
              })

              Column({ space: 8 }) {
                Row({ space: 8 }) {
                  this.buildPlanTitle(plan)

                  Button(plan.collapsed ? '展开' : '收起')
                  .width(56)
                  .height(28)
                  .fontSize(11)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#5373A6')
                  .backgroundColor('#EEF4FF')
                  .borderRadius(14)
                  .onClick(() => {
                    this.toggleWorkoutPlanCollapsed(plan.id);
                  })
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)

                Text(this.getWorkoutPlanProgressText(plan))
                  .fontSize(12)
                  .lineHeight(18)
                  .fontColor(this.isWorkoutPlanCompleted(plan) ? '#667085' : SECONDARY_TEXT_COLOR)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')

                Row({ space: 6 }) {
                  Text(this.getWorkoutPlanStatusText(plan))
                    .fontSize(11)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.isWorkoutPlanCompleted(plan) ? '#667085' : '#5373A6')
                    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    .backgroundColor(this.isWorkoutPlanCompleted(plan) ? '#ECEFF3' : '#EAF2FF')
                    .borderRadius(999)

                  Text(this.getWorkoutPlanTypeText(plan))
                    .fontSize(11)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.isWorkoutPlanCompleted(plan) ? '#667085' : '#6B7280')
                    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    .backgroundColor(this.isWorkoutPlanCompleted(plan) ? '#ECEFF3' : '#F3F4F6')
                    .borderRadius(999)
                }
                .width('100%')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)

            if (!plan.collapsed) {
              Column({ space: 10 }) {
                Text(plan.summary)
                  .fontSize(12)
                  .lineHeight(18)
                  .fontColor(SECONDARY_TEXT_COLOR)
                  .width('100%')

                if (plan.notes.trim().length > 0) {
                  Text(plan.notes.trim())
                    .fontSize(12)
                    .lineHeight(18)
                    .fontColor('#4F6690')
                    .width('100%')
                    .padding(10)
                    .backgroundColor('#FFFFFF')
                    .borderRadius(12)
                }

                Row({ space: 6 }) {
                  Text(this.getWorkoutPlanGoalBadgeText(plan))
                    .fontSize(11)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.isWorkoutPlanCompleted(plan) ? '#667085' : '#5373A6')
                    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    .backgroundColor(this.isWorkoutPlanCompleted(plan) ? '#E5E7EB' : '#EAF2FF')
                    .borderRadius(999)

                  Text(this.getWorkoutPlanTypeText(plan))
                    .fontSize(11)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.isWorkoutPlanCompleted(plan) ? '#667085' : '#6B7280')
                    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    .backgroundColor(this.isWorkoutPlanCompleted(plan) ? '#ECEFF3' : '#F3F4F6')
                    .borderRadius(999)
                }
                .width('100%')

                Row({ space: 8 }) {
                  Button(this.isWorkoutPlanCompleted(plan) ? '再次训练' : '开始训练')
                    .layoutWeight(1)
                    .height(32)
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#FFFFFF')
                    .backgroundColor(this.isWorkoutPlanCompleted(plan) ? '#94A3B8' : plan.accentColor)
                    .borderRadius(14)
                    .onClick(() => {
                      this.openWorkoutPlan(plan);
                    })

                  Button('删除')
                    .width(68)
                    .height(32)
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#7B61FF')
                    .backgroundColor('#F2F0FF')
                    .borderRadius(14)
                    .onClick(() => {
                      this.removeWorkoutPlan(plan.id);
                    })
                }
                .width('100%')
              }
              .width('100%')
              .margin({ left: 40 })
            }
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .backgroundColor(this.isWorkoutPlanCompleted(plan) ? '#F3F4F6' : '#F5F8FF')
          .borderRadius(16)
          .opacity(this.isWorkoutPlanCompleted(plan) ? 0.82 : 1)
        }, (plan: WorkoutPlanItem) => this.getWorkoutPlanRenderKey(plan))
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(18)
    .backgroundColor(SURFACE_BACKGROUND_COLOR)
    .borderRadius(24)
  }

  @Builder
  buildPlanPickerSheet() {
    if (this.planPickerVisible) {
      Stack({ alignContent: Alignment.Bottom }) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#66000000')
          .onClick(() => {
            this.closePlanPicker();
          })

        Column({ space: 14 }) {
          Row() {
            Column({ space: 4 }) {
              Text('添加训练计划')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(PRIMARY_TEXT_COLOR)

              Text(this.formatFriendlyDate(this.selectedPlanDate))
                .fontSize(12)
                .fontColor(SECONDARY_TEXT_COLOR)
            }
            .alignItems(HorizontalAlign.Start)

            Button('收起')
              .height(34)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor('#0F6BFF')
              .backgroundColor('#EAF2FF')
              .borderRadius(17)
              .onClick(() => {
                this.closePlanPicker();
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)

          Text('先选训练，再设置本次计划的目标量。')
            .fontSize(13)
            .lineHeight(20)
            .fontColor(SECONDARY_TEXT_COLOR)

          TextInput({ placeholder: '计划标题，可留空默认使用训练名', text: this.planTitleInput })
            .fontSize(15)
            .fontColor(PRIMARY_TEXT_COLOR)
            .height(46)
            .width('100%')
            .padding({ left: 12, right: 12 })
            .backgroundColor('#F5F8FF')
            .borderRadius(16)
            .onChange((value: string) => {
              this.planTitleInput = value;
            })

          TextInput({ placeholder: '计划备注，例如早上空腹 / 下班后训练', text: this.planNotesInput })
            .fontSize(15)
            .fontColor(PRIMARY_TEXT_COLOR)
            .height(46)
            .width('100%')
            .padding({ left: 12, right: 12 })
            .backgroundColor('#F5F8FF')
            .borderRadius(16)
            .onChange((value: string) => {
              this.planNotesInput = value;
            })

          Column({ space: 8 }) {
            Text(this.getSelectedPlanGoalLabel())
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(PRIMARY_TEXT_COLOR)

            if (this.hasSelectedPlanChoice()) {
              Row({ space: 8 }) {
                TextInput({ placeholder: this.getSelectedPlanGoalPlaceholder(), text: this.planGoalValueInput })
                  .fontSize(16)
                  .fontColor(PRIMARY_TEXT_COLOR)
                  .height(46)
                  .layoutWeight(1)
                  .padding({ left: 12, right: 12 })
                  .backgroundColor('#F5F8FF')
                  .borderRadius(16)
                  .onChange((value: string) => {
                    this.planGoalValueInput = value;
                  })

                Text(this.getSelectedPlanGoalUnit())
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#0F6BFF')
                  .padding({ left: 12, right: 12, top: 11, bottom: 11 })
                  .backgroundColor('#EAF2FF')
                  .borderRadius(14)
              }
              .width('100%')
            } else {
              Text('先从下方列表点“选择”，再设置目标量。')
                .fontSize(12)
                .lineHeight(18)
                .fontColor(SECONDARY_TEXT_COLOR)
                .width('100%')
                .padding(12)
                .backgroundColor('#F5F8FF')
                .borderRadius(14)
            }

            Text(`当前已选：${this.getSelectedPlanDisplayName()}`)
              .fontSize(12)
              .fontColor(this.hasSelectedPlanChoice() ? '#5373A6' : SECONDARY_TEXT_COLOR)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')

          Text('选择训练类型')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(PRIMARY_TEXT_COLOR)

          Scroll() {
            Column({ space: 12 }) {
              ForEach(EXERCISE_OPTIONS, (option: ExerciseOption) => {
                Row({ space: 10 }) {
                  Column({ space: 4 }) {
                    Text(option.name)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(PRIMARY_TEXT_COLOR)

                    Text(option.description)
                      .fontSize(12)
                      .lineHeight(18)
                      .fontColor(SECONDARY_TEXT_COLOR)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Button(this.isPlanExerciseSelected(option) ? '已选' : '选择')
                    .width(74)
                    .height(36)
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.isPlanExerciseSelected(option) ? '#FFFFFF' : option.accentColor)
                    .backgroundColor(this.isPlanExerciseSelected(option) ? option.accentColor : '#FFFFFF')
                    .borderRadius(18)
                    .onClick(() => {
                      this.selectPlanExercise(option);
                    })
                }
                .width('100%')
                .padding(14)
                .backgroundColor('#F5F8FF')
                .borderRadius(18)
              }, (option: ExerciseOption) => option.id)

              if (this.savedCustomWorkouts.length > 0) {
                Text('已保存模板')
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(SECONDARY_TEXT_COLOR)
              }

              if (this.savedCustomWorkouts.length > 0) {
                ForEach(this.savedCustomWorkouts, (savedWorkout: SavedCustomWorkout) => {
                  Row({ space: 10 }) {
                    Column({ space: 4 }) {
                      Text(savedWorkout.name)
                        .fontSize(15)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(PRIMARY_TEXT_COLOR)

                      Text('自定义模板')
                        .fontSize(12)
                        .fontColor(SECONDARY_TEXT_COLOR)
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)

                    Button(this.isPlanSavedWorkoutSelected(savedWorkout) ? '已选' : '选择')
                      .width(74)
                      .height(36)
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.isPlanSavedWorkoutSelected(savedWorkout) ? '#FFFFFF' : '#7B61FF')
                      .backgroundColor(this.isPlanSavedWorkoutSelected(savedWorkout) ? '#7B61FF' : '#FFFFFF')
                      .borderRadius(18)
                      .onClick(() => {
                        this.selectPlanSavedWorkout(savedWorkout);
                      })
                  }
                  .width('100%')
                  .padding(14)
                  .backgroundColor('#F3F7FF')
                  .borderRadius(18)
                }, (savedWorkout: SavedCustomWorkout) => savedWorkout.id)
              }
            }
            .width('100%')
            .padding({ right: 2, bottom: 8 })
          }
          .width('100%')
          .height(180)
          .scrollable(ScrollDirection.Vertical)
          .scrollBar(BarState.Auto)

          Button(`加入 ${this.getSelectedPlanDisplayName()} 计划`)
            .width('100%')
            .height(46)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .backgroundColor(this.hasSelectedPlanChoice() ? '#0F6BFF' : '#98A2B3')
            .borderRadius(18)
            .onClick(() => {
              this.confirmPlanCreation();
            })
        }
        .width('92%')
        .padding({ left: 20, right: 20, top: 18, bottom: 24 })
        .backgroundColor(SURFACE_BACKGROUND_COLOR)
        .borderRadius(28)
        .margin({ bottom: 12 })
      }
      .width('100%')
      .height('100%')
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 6 }) {
            Text('训练与计划')
              .fontSize(28)
              .fontWeight(FontWeight.Bolder)
              .fontColor(PRIMARY_TEXT_COLOR)

            Text('先选日期，再把训练加入计划，或直接进入训练详情。')
              .fontSize(14)
              .fontColor(SECONDARY_TEXT_COLOR)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')

          Column({ space: 8 }) {
            Text('今日累计')
              .fontSize(14)
              .fontColor('#E3EEFF')

            Text(this.getTodayCaloriesText())
              .fontSize(34)
              .fontWeight(FontWeight.Bolder)
              .fontColor('#FFFFFF')

            Text(this.getTodayWorkoutCountText())
              .fontSize(13)
              .fontColor('#C8DBFF')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(18)
          .backgroundColor('#0F6BFF')
          .borderRadius(24)

          this.buildCalendarCard()
          this.buildPlanListCard()

          Column({ space: 12 }) {
            Row() {
              Text('选择训练')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor(PRIMARY_TEXT_COLOR)

              Text(this.getExercisePickerCountText())
                .fontSize(12)
                .fontColor(SECONDARY_TEXT_COLOR)
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)

            Text('预设训练')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(SECONDARY_TEXT_COLOR)

            ForEach(EXERCISE_OPTIONS, (option: ExerciseOption) => {
              Column({ space: 10 }) {
                Column({ space: 6 }) {
                  Text(option.name)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(PRIMARY_TEXT_COLOR)

                  Text(option.description)
                    .fontSize(12)
                    .lineHeight(18)
                    .fontColor(SECONDARY_TEXT_COLOR)
                }
                .alignItems(HorizontalAlign.Start)
                .width('100%')

                Row({ space: 10 }) {
                  Button('立即开始')
                    .layoutWeight(1)
                    .height(40)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#FFFFFF')
                    .backgroundColor(option.accentColor)
                    .borderRadius(16)
                    .onClick(() => {
                      this.selectExercise(option.id);
                    })

                  Button('加入计划')
                    .layoutWeight(1)
                    .height(40)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(PRIMARY_TEXT_COLOR)
                    .backgroundColor('#EAF2FF')
                    .borderRadius(16)
                    .onClick(() => {
                      this.openPlanPickerForExercise(option);
                    })
                }
                .width('100%')
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding(16)
              .backgroundColor('#F5F8FF')
              .borderRadius(18)
            }, (option: ExerciseOption) => option.id)

            if (this.savedCustomWorkouts.length > 0) {
              Text('已保存模板')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(SECONDARY_TEXT_COLOR)
            }

            if (this.savedCustomWorkouts.length > 0) {
              ForEach(this.savedCustomWorkouts, (savedWorkout: SavedCustomWorkout) => {
                Column({ space: 10 }) {
                  Column({ space: 6 }) {
                    Text(savedWorkout.name)
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(PRIMARY_TEXT_COLOR)

                    Text('自定义模板，可直接开始训练或加入当前日期计划')
                      .fontSize(12)
                      .lineHeight(18)
                      .fontColor(SECONDARY_TEXT_COLOR)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .width('100%')

                  Row({ space: 10 }) {
                    Button('立即开始')
                      .layoutWeight(1)
                      .height(40)
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#FFFFFF')
                      .backgroundColor('#7B61FF')
                      .borderRadius(16)
                      .onClick(() => {
                        this.selectSavedCustomWorkout(savedWorkout);
                      })

                    Button('加入计划')
                      .layoutWeight(1)
                      .height(40)
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#7B61FF')
                      .backgroundColor('#F2F0FF')
                      .borderRadius(16)
                      .onClick(() => {
                        this.openPlanPickerForSavedWorkout(savedWorkout);
                      })
                  }
                  .width('100%')
                }
                .alignItems(HorizontalAlign.Start)
                .width('100%')
                .padding(14)
                .backgroundColor('#F3F7FF')
                .borderRadius(18)
              }, (savedWorkout: SavedCustomWorkout) => savedWorkout.id)
            }
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
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
      .friction(0.6)
      .backgroundColor(PAGE_BACKGROUND_COLOR)

      this.buildPlanPickerSheet()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PAGE_BACKGROUND_COLOR)
  }
}
