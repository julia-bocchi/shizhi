import {
  PAGE_BACKGROUND_COLOR,
  PRIMARY_TEXT_COLOR,
  SECONDARY_TEXT_COLOR,
  SURFACE_BACKGROUND_COLOR
} from '../../constants/AppTheme';
import { FoodPlanItem } from '../../models/FoodPlan';
import { FoodMealOption, FOOD_MEAL_OPTIONS } from '../../models/FoodOption';
import {
  deserializeFoodPlans,
  getFoodMealSortValue,
  serializeFoodPlans
} from '../../utils/FoodHelper';
import {
  buildMonthCalendarRows,
  CALENDAR_WEEK_LABELS,
  CalendarMonthCell,
  formatMonthTitle,
  shiftCalendarMonth
} from '../../utils/MonthCalendarHelper';
import { formatDate } from '../../utils/WeightRecordHelper';
import { EXERCISE_STORAGE_READY } from '../../utils/ExerciseStorage';

interface CalendarDayItem extends CalendarMonthCell {
  planCount: number;
}

const DEFAULT_DAILY_CALORIE_TARGET: number = 2000;
const MIN_DAILY_CALORIE_TARGET: number = 500;
const MAX_DAILY_CALORIE_TARGET: number = 9999;

@Component
export struct FoodTabPage {
  @Link currentTabIndex: number;
  @StorageLink('foodPlanText') foodPlanText: string = '';
  @StorageLink('dailyFoodCalorieTargetText') dailyFoodCalorieTargetText: string = `${DEFAULT_DAILY_CALORIE_TARGET}`;
  @StorageLink('currentFoodPlanDateText') currentFoodPlanDateText: string = '';

  @State selectedPlanDate: string = formatDate(new Date());
  @State calendarYear: number = new Date().getFullYear();
  @State calendarMonth: number = new Date().getMonth();
  @State expandedMealType: string = '';
  @State scannerNotice: string = '拍照识别入口已预留，后续可以直接接相机和热量识别。';
  @State isDailyTargetDialogVisible: boolean = false;
  @State dailyTargetDraftText: string = '';
  @State bubbleFloatOffset: number = 0;
  @State bubbleOuterGlowSize: number = 194;
  @State bubbleMiddleGlowSize: number = 174;
  @State bubbleInnerGlowSize: number = 158;
  @State bubbleLiquidAccentWidth: number = 92;
  @State bubbleLiquidAccentOpacity: number = 0.18;
  @State bubbleLiquidSurfaceWidth: number = 86;
  @State bubbleLiquidSurfaceOffset: number = 0;
  @State bubbleHighlightOffset: number = 0;
  @State bubbleHaloOpacity: number = 0.14;
  @State bubbleReflectSize: number = 20;

  private bubbleAnimationTimerId: number = -1;
  private bubbleAnimationExpanded: boolean = false;

  aboutToAppear(): void {
    EXERCISE_STORAGE_READY;
    if (this.currentFoodPlanDateText.trim().length > 0) {
      this.selectedPlanDate = this.currentFoodPlanDateText;
      this.syncCalendarWithDate(this.selectedPlanDate);
    } else {
      this.currentFoodPlanDateText = this.selectedPlanDate;
    }
    this.startBubbleAnimation();
  }

  aboutToDisappear(): void {
    this.stopBubbleAnimation();
  }

  private getAllFoodPlans(): FoodPlanItem[] {
    return deserializeFoodPlans(this.foodPlanText);
  }

  private syncCalendarWithDate(dateText: string): void {
    let fields: string[] = dateText.split('-');
    if (fields.length < 3) {
      return;
    }
    this.calendarYear = Number(fields[0]);
    this.calendarMonth = Number(fields[1]) - 1;
  }

  private openPlanPage(): void {
    this.currentFoodPlanDateText = this.selectedPlanDate;
    try {
      let routeTask: Promise<void> = this.getUIContext().getRouter().pushUrl({ url: 'pages/food/FoodPlanPage' });
      routeTask.catch(() => {
      });
    } catch (error) {
      this.scannerNotice = '打开制定计划页失败，请重试。';
    }
  }

  private removeFoodPlan(planId: string): void {
    let currentPlans: FoodPlanItem[] = this.getAllFoodPlans();
    let nextPlans: FoodPlanItem[] = [];
    for (let index = 0; index < currentPlans.length; index++) {
      if (currentPlans[index].id !== planId) {
        nextPlans.push(currentPlans[index]);
      }
    }
    this.foodPlanText = serializeFoodPlans(nextPlans);
  }

  private getPlansForDate(dateText: string): FoodPlanItem[] {
    let result: FoodPlanItem[] = [];
    let currentPlans: FoodPlanItem[] = this.getAllFoodPlans();
    for (let index = 0; index < currentPlans.length; index++) {
      if (currentPlans[index].date === dateText) {
        result.push(currentPlans[index]);
      }
    }
    result.sort((left: FoodPlanItem, right: FoodPlanItem) =>
      getFoodMealSortValue(left.mealType) - getFoodMealSortValue(right.mealType)
    );
    return result;
  }

  private getPlansForMeal(dateText: string, mealType: string): FoodPlanItem[] {
    let result: FoodPlanItem[] = [];
    let plans: FoodPlanItem[] = this.getPlansForDate(dateText);
    for (let index = 0; index < plans.length; index++) {
      if (plans[index].mealType === mealType) {
        result.push(plans[index]);
      }
    }
    return result;
  }

  private getSelectedDateCalories(): number {
    let totalCalories: number = 0;
    let plans: FoodPlanItem[] = this.getPlansForDate(this.selectedPlanDate);
    for (let index = 0; index < plans.length; index++) {
      totalCalories += plans[index].calories;
    }
    return totalCalories;
  }

  private getSelectedDatePlanCount(): number {
    return this.getPlansForDate(this.selectedPlanDate).length;
  }

  private sanitizeDailyCalorieTargetInput(value: string): string {
    let nextText: string = '';
    for (let index = 0; index < value.length; index++) {
      let currentChar: string = value.charAt(index);
      if (currentChar >= '0' && currentChar <= '9' && nextText.length < 4) {
        nextText += currentChar;
      }
    }
    return nextText;
  }

  private openDailyTargetDialog(): void {
    let sanitizedText: string = this.sanitizeDailyCalorieTargetInput(this.dailyFoodCalorieTargetText);
    if (sanitizedText.length === 0) {
      this.dailyTargetDraftText = '';
    } else {
      this.dailyTargetDraftText = sanitizedText;
    }
    this.isDailyTargetDialogVisible = true;
  }

  private closeDailyTargetDialog(): void {
    this.isDailyTargetDialogVisible = false;
    this.dailyTargetDraftText = '';
  }

  private saveDailyTargetDialog(): void {
    let sanitizedText: string = this.sanitizeDailyCalorieTargetInput(this.dailyTargetDraftText);
    if (sanitizedText.length === 0) {
      this.dailyFoodCalorieTargetText = '';
      this.closeDailyTargetDialog();
      return;
    }

    let targetValue: number = Number(sanitizedText);
    if (targetValue < MIN_DAILY_CALORIE_TARGET) {
      this.dailyFoodCalorieTargetText = `${MIN_DAILY_CALORIE_TARGET}`;
    } else if (targetValue > MAX_DAILY_CALORIE_TARGET) {
      this.dailyFoodCalorieTargetText = `${MAX_DAILY_CALORIE_TARGET}`;
    } else {
      this.dailyFoodCalorieTargetText = sanitizedText;
    }
    this.closeDailyTargetDialog();
  }

  private getDailyCalorieTarget(): number {
    let sanitizedText: string = this.sanitizeDailyCalorieTargetInput(this.dailyFoodCalorieTargetText);
    if (sanitizedText.length === 0) {
      return DEFAULT_DAILY_CALORIE_TARGET;
    }

    let targetValue: number = Number(sanitizedText);
    if (targetValue < MIN_DAILY_CALORIE_TARGET || targetValue > MAX_DAILY_CALORIE_TARGET) {
      return DEFAULT_DAILY_CALORIE_TARGET;
    }
    return targetValue;
  }

  private getDailyCalorieTargetHintTextByText(targetText: string): string {
    let sanitizedText: string = this.sanitizeDailyCalorieTargetInput(targetText);
    if (sanitizedText.length === 0) {
      return `留空时默认 ${DEFAULT_DAILY_CALORIE_TARGET} kcal`;
    }

    let targetValue: number = Number(sanitizedText);
    if (targetValue < MIN_DAILY_CALORIE_TARGET || targetValue > MAX_DAILY_CALORIE_TARGET) {
      return `建议填写 ${MIN_DAILY_CALORIE_TARGET}-${MAX_DAILY_CALORIE_TARGET} kcal`;
    }
    return '目标会自动保存，下次打开仍然保留';
  }

  private getSelectedDateCalorieRatio(): number {
    return this.getSelectedDateCalories() / this.getDailyCalorieTarget();
  }

  private getSelectedDateCalorieFillRatio(): number {
    let ratio: number = this.getSelectedDateCalorieRatio();
    if (ratio < 0) {
      return 0;
    }
    if (ratio > 1) {
      return 1;
    }
    return ratio;
  }

  private getSelectedDateCaloriePercent(): number {
    return Math.round(this.getSelectedDateCalorieRatio() * 100);
  }

  private getSelectedDateCalorieFillHeightText(): string {
    let ratio: number = this.getSelectedDateCalorieFillRatio();
    if (ratio <= 0) {
      return '0%';
    }
    if (ratio < 0.12) {
      return '12%';
    }
    return `${Math.round(ratio * 100)}%`;
  }

  private getSelectedDateCalorieFillHeight(): number {
    let ratio: number = this.getSelectedDateCalorieFillRatio();
    if (ratio <= 0) {
      return 0;
    }
    if (ratio < 0.12) {
      return 16;
    }
    return Math.round(ratio * 126);
  }

  private getSelectedDateCalorieThemeColor(): string {
    let ratio: number = this.getSelectedDateCalorieRatio();
    if (ratio > 1) {
      return '#EF4444';
    }
    if (ratio >= 0.85) {
      return '#F59E0B';
    }
    if (ratio >= 0.55) {
      return '#22C55E';
    }
    return '#38BDF8';
  }

  private getSelectedDateCalorieThemeSoftColor(): string {
    let ratio: number = this.getSelectedDateCalorieRatio();
    if (ratio > 1) {
      return '#4A2830';
    }
    if (ratio >= 0.85) {
      return '#4C361A';
    }
    if (ratio >= 0.55) {
      return '#183A31';
    }
    return '#1D3952';
  }

  private getSelectedDateCalorieStatusText(): string {
    let totalCalories: number = Math.round(this.getSelectedDateCalories());
    let targetCalories: number = this.getDailyCalorieTarget();
    if (totalCalories <= 0) {
      return `今日目标 ${targetCalories} kcal，当前还没有记录摄入。`;
    }

    if (totalCalories > targetCalories) {
      let exceededCalories: number = totalCalories - targetCalories;
      let exceededPercent: number = Math.round((exceededCalories / targetCalories) * 100);
      return `已超过今日目标 ${exceededPercent}%，超出 ${exceededCalories} kcal。`;
    }

    let remainingCalories: number = targetCalories - totalCalories;
    return `已达到今日目标 ${this.getSelectedDateCaloriePercent()}%，还可摄入 ${remainingCalories} kcal。`;
  }

  private getSelectedDateCalorieGapLabelText(): string {
    if (this.getSelectedDateCalories() > this.getDailyCalorieTarget()) {
      return '超出热量';
    }
    return '剩余热量';
  }

  private getSelectedDateCalorieGapValueText(): string {
    let totalCalories: number = Math.round(this.getSelectedDateCalories());
    let targetCalories: number = this.getDailyCalorieTarget();
    return `${Math.abs(targetCalories - totalCalories)} kcal`;
  }

  private getBubbleLiquidCoreHeight(): number {
    let fillHeight: number = this.getSelectedDateCalorieFillHeight();
    if (fillHeight <= 0) {
      return 0;
    }
    if (fillHeight < 28) {
      return 20;
    }
    return fillHeight - 10;
  }

  private getBubbleLiquidSurfaceBottom(): number {
    let fillHeight: number = this.getSelectedDateCalorieFillHeight();
    if (fillHeight <= 0) {
      return 0;
    }
    let nextBottom: number = fillHeight - 10 + this.bubbleLiquidSurfaceOffset;
    if (nextBottom < 10) {
      return 10;
    }
    if (nextBottom > 112) {
      return 112;
    }
    return nextBottom;
  }

  private resetBubbleAnimationState(): void {
    this.bubbleFloatOffset = 0;
    this.bubbleOuterGlowSize = 194;
    this.bubbleMiddleGlowSize = 174;
    this.bubbleInnerGlowSize = 158;
    this.bubbleLiquidAccentWidth = 92;
    this.bubbleLiquidAccentOpacity = 0.18;
    this.bubbleLiquidSurfaceWidth = 86;
    this.bubbleLiquidSurfaceOffset = 0;
    this.bubbleHighlightOffset = 0;
    this.bubbleHaloOpacity = 0.14;
    this.bubbleReflectSize = 20;
  }

  private playBubbleAnimationFrame(): void {
    this.bubbleAnimationExpanded = !this.bubbleAnimationExpanded;
    let isExpanded: boolean = this.bubbleAnimationExpanded;
    animateTo({
      duration: 950,
      curve: Curve.EaseInOut
    }, () => {
      this.bubbleFloatOffset = isExpanded ? -8 : 3;
      this.bubbleOuterGlowSize = isExpanded ? 204 : 194;
      this.bubbleMiddleGlowSize = isExpanded ? 184 : 174;
      this.bubbleInnerGlowSize = isExpanded ? 166 : 158;
      this.bubbleLiquidAccentWidth = isExpanded ? 102 : 88;
      this.bubbleLiquidAccentOpacity = isExpanded ? 0.28 : 0.18;
      this.bubbleLiquidSurfaceWidth = isExpanded ? 98 : 84;
      this.bubbleLiquidSurfaceOffset = isExpanded ? 4 : -3;
      this.bubbleHighlightOffset = isExpanded ? 6 : -2;
      this.bubbleHaloOpacity = isExpanded ? 0.2 : 0.12;
      this.bubbleReflectSize = isExpanded ? 24 : 18;
    });
  }

  private startBubbleAnimation(): void {
    this.stopBubbleAnimation();
    this.resetBubbleAnimationState();
    this.playBubbleAnimationFrame();
    this.bubbleAnimationTimerId = setInterval(() => {
      this.playBubbleAnimationFrame();
    }, 1800);
  }

  private stopBubbleAnimation(): void {
    if (this.bubbleAnimationTimerId !== -1) {
      clearInterval(this.bubbleAnimationTimerId);
      this.bubbleAnimationTimerId = -1;
    }
  }

  private getSelectedDateCalorieStateText(): string {
    let totalCalories: number = Math.round(this.getSelectedDateCalories());
    let ratio: number = this.getSelectedDateCalorieRatio();
    if (totalCalories <= 0) {
      return '待安排';
    }
    if (ratio > 1) {
      return '已超目标';
    }
    if (ratio >= 0.9) {
      return '接近目标';
    }
    if (ratio >= 0.55) {
      return '状态不错';
    }
    return '还可补充';
  }

  private getPlanCountByDate(dateText: string): number {
    return this.getPlansForDate(dateText).length;
  }

  private getMealCalories(dateText: string, mealType: string): number {
    let totalCalories: number = 0;
    let plans: FoodPlanItem[] = this.getPlansForMeal(dateText, mealType);
    for (let index = 0; index < plans.length; index++) {
      totalCalories += plans[index].calories;
    }
    return totalCalories;
  }

  private getMealSummaryText(dateText: string, mealType: string): string {
    let plans: FoodPlanItem[] = this.getPlansForMeal(dateText, mealType);
    if (plans.length === 0) {
      return '未安排 · 0 kcal';
    }
    return `${plans.length} 份 · ${Math.round(this.getMealCalories(dateText, mealType))} kcal`;
  }

  private getMealPreviewText(dateText: string, mealType: string): string {
    let plans: FoodPlanItem[] = this.getPlansForMeal(dateText, mealType);
    if (plans.length === 0) {
      return '暂时还没有安排食物，点上方按钮去补充。';
    }

    let names: string[] = [];
    for (let index = 0; index < plans.length && index < 2; index++) {
      names.push(plans[index].name);
    }

    let previewText: string = names.join(' · ');
    if (plans.length > 2) {
      previewText = `${previewText} 等 ${plans.length} 项`;
    }

    if (plans[0].notes.trim().length > 0) {
      return `${previewText} · ${plans[0].notes.trim()}`;
    }
    return previewText;
  }

  private formatFriendlyDate(dateText: string): string {
    let fields: string[] = dateText.split('-');
    if (fields.length < 3) {
      return dateText;
    }
    return `${fields[0]}年${Number(fields[1])}月${Number(fields[2])}日`;
  }

  private getCalendarTitle(): string {
    return formatMonthTitle(this.calendarYear, this.calendarMonth);
  }

  private createMonthDateText(dayNumber: number): string {
    return formatDate(new Date(this.calendarYear, this.calendarMonth, dayNumber));
  }

  private changeCalendarMonth(step: number): void {
    let nextCursor = shiftCalendarMonth(this.calendarYear, this.calendarMonth, step);
    this.calendarYear = nextCursor.year;
    this.calendarMonth = nextCursor.month;
    this.selectedPlanDate = this.createMonthDateText(1);
    this.currentFoodPlanDateText = this.selectedPlanDate;
    this.expandedMealType = '';
  }

  private toggleMealSection(mealType: string): void {
    this.expandedMealType = this.expandedMealType === mealType ? '' : mealType;
  }

  private getMealAccentColor(mealType: string): string {
    if (mealType === 'breakfast') {
      return '#F59E0B';
    }
    if (mealType === 'lunch') {
      return '#10B981';
    }
    if (mealType === 'dinner') {
      return '#0F6BFF';
    }
    return '#7B61FF';
  }

  private getMealSurfaceColor(mealType: string): string {
    if (mealType === 'breakfast') {
      return '#FFF8EB';
    }
    if (mealType === 'lunch') {
      return '#EFFBF4';
    }
    if (mealType === 'dinner') {
      return '#F2F7FF';
    }
    return '#F7F2FF';
  }

  private getMonthPlanDayCount(): number {
    let currentPlans: FoodPlanItem[] = this.getAllFoodPlans();
    let monthPrefix: string = `${this.calendarYear}-${this.calendarMonth + 1 < 10 ? `0${this.calendarMonth + 1}` : `${this.calendarMonth + 1}`}-`;
    let countedDates: string[] = [];

    for (let index = 0; index < currentPlans.length; index++) {
      if (currentPlans[index].date.startsWith(monthPrefix) && countedDates.indexOf(currentPlans[index].date) < 0) {
        countedDates.push(currentPlans[index].date);
      }
    }

    return countedDates.length;
  }

  private getMonthPlanCount(): number {
    let currentPlans: FoodPlanItem[] = this.getAllFoodPlans();
    let monthPrefix: string = `${this.calendarYear}-${this.calendarMonth + 1 < 10 ? `0${this.calendarMonth + 1}` : `${this.calendarMonth + 1}`}-`;
    let count: number = 0;

    for (let index = 0; index < currentPlans.length; index++) {
      if (currentPlans[index].date.startsWith(monthPrefix)) {
        count += 1;
      }
    }

    return count;
  }

  private getMonthCalories(): number {
    let currentPlans: FoodPlanItem[] = this.getAllFoodPlans();
    let monthPrefix: string = `${this.calendarYear}-${this.calendarMonth + 1 < 10 ? `0${this.calendarMonth + 1}` : `${this.calendarMonth + 1}`}-`;
    let totalCalories: number = 0;

    for (let index = 0; index < currentPlans.length; index++) {
      if (currentPlans[index].date.startsWith(monthPrefix)) {
        totalCalories += currentPlans[index].calories;
      }
    }

    return Math.round(totalCalories);
  }

  private getCalendarRows(): CalendarDayItem[][] {
    let baseRows = buildMonthCalendarRows(this.calendarYear, this.calendarMonth);
    let rows: CalendarDayItem[][] = [];

    for (let rowIndex = 0; rowIndex < baseRows.length; rowIndex++) {
      let nextRow: CalendarDayItem[] = [];
      for (let columnIndex = 0; columnIndex < baseRows[rowIndex].length; columnIndex++) {
        let currentCell = baseRows[rowIndex][columnIndex];
        nextRow.push({
          key: currentCell.key,
          dateText: currentCell.dateText,
          dayNumber: currentCell.dayNumber,
          isCurrentMonth: currentCell.isCurrentMonth,
          isToday: currentCell.isToday,
          planCount: currentCell.isCurrentMonth ? this.getPlanCountByDate(currentCell.dateText) : 0
        });
      }
      rows.push(nextRow);
    }

    return rows;
  }

  @Builder
  buildFoodCard(plan: FoodPlanItem) {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Text('')
          .width(4)
          .height(46)
          .backgroundColor(plan.accentColor)
          .borderRadius(2)

        if (plan.image.trim().length > 0) {
          Image(plan.image)
            .width(52)
            .height(52)
            .objectFit(ImageFit.Cover)
            .borderRadius(14)
        } else {
          Stack({ alignContent: Alignment.Center }) {
            Text(plan.name.length > 0 ? plan.name.substring(0, 1) : '食')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
          }
          .width(52)
          .height(52)
          .backgroundColor(plan.accentColor)
          .borderRadius(14)
        }

        Column({ space: 6 }) {
          Row({ space: 6 }) {
            Text(plan.name)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(PRIMARY_TEXT_COLOR)
              .layoutWeight(1)
              .maxLines(1)

            Text(`${Math.round(plan.calories)} kcal`)
              .fontSize(10)
              .fontWeight(FontWeight.Bold)
              .fontColor('#17324D')
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor('#EEF4FF')
              .borderRadius(999)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Row({ space: 6 }) {
            Text(plan.serving)
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontColor(plan.accentColor)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor('#FFFFFF')
              .borderRadius(999)

            Text(plan.description)
              .fontSize(11)
              .lineHeight(16)
              .fontColor(SECONDARY_TEXT_COLOR)
              .layoutWeight(1)
              .maxLines(2)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button('删除')
          .width(62)
          .height(32)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#7A5C2E')
          .backgroundColor('#F8EEDC')
          .borderRadius(16)
          .onClick(() => {
            this.removeFoodPlan(plan.id);
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (plan.notes.trim().length > 0) {
        Text(plan.notes)
          .fontSize(11)
          .lineHeight(16)
          .fontColor('#4F6690')
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .width('100%')
          .backgroundColor('#FFFFFF')
          .borderRadius(14)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(12)
    .backgroundColor('#F8FAFD')
    .borderRadius(18)
  }

  @Builder
  buildMealSection(meal: FoodMealOption) {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 6 }) {
          Row({ space: 8 }) {
            Text(meal.label)
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(PRIMARY_TEXT_COLOR)

            Text(this.expandedMealType === meal.id ? '已展开' : '点击展开')
              .fontSize(10)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.getMealAccentColor(meal.id))
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor('#FFFFFF')
              .borderRadius(999)
          }

          Text(this.getMealSummaryText(this.selectedPlanDate, meal.id))
            .fontSize(12)
            .fontColor('#4F6690')

          Text(this.getMealPreviewText(this.selectedPlanDate, meal.id))
            .fontSize(12)
            .lineHeight(18)
            .fontColor(SECONDARY_TEXT_COLOR)
            .maxLines(this.expandedMealType === meal.id ? 3 : 2)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.expandedMealType === meal.id ? '收起' : '查看')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor(this.getMealAccentColor(meal.id))
          .borderRadius(999)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.toggleMealSection(meal.id);
      })

      if (this.expandedMealType === meal.id) {
        Column({ space: 10 }) {
          if (this.getPlansForMeal(this.selectedPlanDate, meal.id).length === 0) {
            Column({ space: 8 }) {
              Text(`还没安排${meal.label}`)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(PRIMARY_TEXT_COLOR)

              Text('点击右上角“制定计划”，进入选择页添加食物搭配。')
                .fontSize(12)
                .lineHeight(18)
                .fontColor(SECONDARY_TEXT_COLOR)
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding(14)
            .backgroundColor('#FFFFFF')
            .borderRadius(16)
          }

          ForEach(this.getPlansForMeal(this.selectedPlanDate, meal.id), (plan: FoodPlanItem) => {
            this.buildFoodCard(plan)
          }, (plan: FoodPlanItem) => plan.id)
        }
        .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(16)
    .backgroundColor(this.getMealSurfaceColor(meal.id))
    .borderRadius(22)
  }

  @Builder
  buildCalendarCard() {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 4 }) {
          Text('饮食日历')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text(this.formatFriendlyDate(this.selectedPlanDate))
            .fontSize(12)
            .fontColor(SECONDARY_TEXT_COLOR)
        }
        .alignItems(HorizontalAlign.Start)

        Button('制定计划')
          .height(36)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor('#8EBBFF')
          .borderRadius(18)
          .onClick(() => {
            this.openPlanPage();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Row({ space: 18 }) {
        Button('<')
          .width(34)
          .height(34)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#6782A8')
          .backgroundColor('#F3F6FC')
          .borderRadius(17)
          .onClick(() => {
            this.changeCalendarMonth(-1);
          })

        Text(this.getCalendarTitle())
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(PRIMARY_TEXT_COLOR)

        Button('>')
          .width(34)
          .height(34)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#6782A8')
          .backgroundColor('#F3F6FC')
          .borderRadius(17)
          .onClick(() => {
            this.changeCalendarMonth(1);
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)

      Row({ space: 6 }) {
        ForEach(CALENDAR_WEEK_LABELS, (label: string) => {
          Text(label)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .fontSize(12)
            .fontColor('#9AA6B5')
        }, (label: string) => label)
      }
      .width('100%')

      Column({ space: 6 }) {
        ForEach(this.getCalendarRows(), (week: CalendarDayItem[]) => {
          Row({ space: 6 }) {
            ForEach(week, (day: CalendarDayItem) => {
              Stack({ alignContent: Alignment.TopStart }) {
                Column({ space: 2 }) {
                  Text(day.isCurrentMonth ? `${day.dayNumber}` : '')
                    .fontSize(18)
                    .fontWeight(day.dateText === this.selectedPlanDate ? FontWeight.Bold : FontWeight.Medium)
                    .fontColor(day.dateText === this.selectedPlanDate ? '#FFFFFF' : (day.isCurrentMonth ? PRIMARY_TEXT_COLOR : '#C8D0DC'))

                  Text(day.isToday && day.isCurrentMonth ? '今' : '')
                    .fontSize(10)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(day.dateText === this.selectedPlanDate ? '#EAF2FF' : '#89AFFF')
                }
                .width('100%')
                .alignItems(HorizontalAlign.Center)
                .margin({ top: 8 })

                if (day.planCount > 0 && day.isCurrentMonth) {
                  Text('')
                    .width(6)
                    .height(6)
                    .backgroundColor(day.dateText === this.selectedPlanDate ? '#FFFFFF' : '#8EBBFF')
                    .borderRadius(3)
                    .margin({ top: 37, left: 24 })
                }
              }
              .layoutWeight(1)
              .height(52)
              .alignItems(HorizontalAlign.Center)
              .justifyContent(FlexAlign.Center)
              .backgroundColor(day.dateText === this.selectedPlanDate ? '#8EBBFF' : '#FFFFFF')
              .borderRadius(14)
              .border({
                width: 1,
                color: day.dateText === this.selectedPlanDate ? '#8EBBFF' : '#EEF2F7'
              })
              .onClick(() => {
                if (!day.isCurrentMonth) {
                  return;
                }
                this.selectedPlanDate = day.dateText;
                this.currentFoodPlanDateText = day.dateText;
                this.expandedMealType = '';
              })
            }, (day: CalendarDayItem) => day.key)
          }
          .width('100%')
        }, (week: CalendarDayItem[]) => week[0].key)
      }
      .width('100%')

      Row({ space: 10 }) {
        Column({ space: 4 }) {
          Text('记录天数')
            .fontSize(11)
            .fontColor('#8A95A5')

          Text(`${this.getMonthPlanDayCount()} 天`)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(PRIMARY_TEXT_COLOR)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .padding(12)
        .backgroundColor('#F7F9FD')
        .borderRadius(16)

        Column({ space: 4 }) {
          Text('餐次总数')
            .fontSize(11)
            .fontColor('#8A95A5')

          Text(`${this.getMonthPlanCount()} 份`)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(PRIMARY_TEXT_COLOR)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .padding(12)
        .backgroundColor('#F7F9FD')
        .borderRadius(16)

        Column({ space: 4 }) {
          Text('月度热量')
            .fontSize(11)
            .fontColor('#8A95A5')

          Text(`${this.getMonthCalories()} kcal`)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(PRIMARY_TEXT_COLOR)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .padding(12)
        .backgroundColor('#F7F9FD')
        .borderRadius(16)
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
  buildMealPlanCard() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 4 }) {
          Text('饮食计划')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text(`${this.formatFriendlyDate(this.selectedPlanDate)} · ${this.getSelectedDatePlanCount()} 份 · ${Math.round(this.getSelectedDateCalories())} kcal`)
            .fontSize(12)
            .fontColor(SECONDARY_TEXT_COLOR)

          Text(this.getSelectedDateCalorieStatusText())
            .fontSize(11)
            .lineHeight(16)
            .fontColor('#4F6690')
            .maxLines(2)
        }
        .alignItems(HorizontalAlign.Start)

        Button('调整计划')
          .height(36)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#17324D')
          .backgroundColor('#EEF3FF')
          .borderRadius(18)
          .onClick(() => {
            this.openPlanPage();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      if (this.getPlansForDate(this.selectedPlanDate).length === 0) {
        Text('先在上方选中日期，再点“制定计划”添加早餐、午餐、晚餐或加餐。')
          .fontSize(13)
          .lineHeight(20)
          .fontColor(SECONDARY_TEXT_COLOR)
          .padding(14)
          .width('100%')
          .backgroundColor('#F6F8FB')
          .borderRadius(16)
      }

      Column({ space: 10 }) {
        ForEach(FOOD_MEAL_OPTIONS, (meal: FoodMealOption) => {
          this.buildMealSection(meal)
        }, (meal: FoodMealOption) => meal.id)
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
  buildCalorieOverviewCard() {
    Column({ space: 20 }) {
      Row() {
        Text('热量总览')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#D7E5F5')
          .layoutWeight(1)

        Text(this.getSelectedDateCalorieStateText())
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .maxLines(1)
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .backgroundColor(this.getSelectedDateCalorieThemeColor())
          .borderRadius(999)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column({ space: 8 }) {
        Text('今日摄入')
          .fontSize(12)
          .fontColor('#93B0CD')

        Row({ space: 8 }) {
          Text(`${Math.round(this.getSelectedDateCalories())}`)
            .fontSize(40)
            .fontWeight(FontWeight.Bolder)
            .fontColor('#FFFFFF')

          Text('kcal')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#D4E2F3')
            .margin({ top: 20 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)

        Text(this.getSelectedDateCalorieStatusText())
          .fontSize(13)
          .lineHeight(20)
          .fontColor('#D4E2F3')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      Column({ space: 12 }) {
        Stack({ alignContent: Alignment.Center }) {
          Text('')
            .width(this.bubbleOuterGlowSize)
            .height(this.bubbleOuterGlowSize)
            .backgroundColor(this.getSelectedDateCalorieThemeColor())
            .opacity(this.bubbleHaloOpacity * 0.55)
            .borderRadius(this.bubbleOuterGlowSize / 2)

          Text('')
            .width(this.bubbleMiddleGlowSize)
            .height(this.bubbleMiddleGlowSize)
            .backgroundColor(this.getSelectedDateCalorieThemeColor())
            .opacity(this.bubbleHaloOpacity)
            .borderRadius(this.bubbleMiddleGlowSize / 2)

          Text('')
            .width(this.bubbleInnerGlowSize)
            .height(this.bubbleInnerGlowSize)
            .backgroundColor(this.getSelectedDateCalorieThemeColor())
            .opacity(this.bubbleHaloOpacity + 0.09)
            .borderRadius(this.bubbleInnerGlowSize / 2)

          Text('')
            .width(142)
            .height(142)
            .backgroundColor('#FFFFFF')
            .opacity(0.9)
            .borderRadius(71)
            .translate({ x: 0, y: this.bubbleFloatOffset })

          Stack({ alignContent: Alignment.Bottom }) {
            Text('')
              .width(126)
              .height(126)
              .backgroundColor('#F8FCFF')
              .opacity(0.96)
              .borderRadius(63)

            if (this.getSelectedDateCalorieFillHeight() > 0) {
              Text('')
                .width(126)
                .height(this.getSelectedDateCalorieFillHeight())
                .backgroundColor(this.getSelectedDateCalorieThemeColor())
                .opacity(0.2)
                .borderRadius(63)

              Text('')
                .width(this.bubbleLiquidAccentWidth)
                .height(this.getBubbleLiquidCoreHeight())
                .backgroundColor(this.getSelectedDateCalorieThemeColor())
                .opacity(this.bubbleLiquidAccentOpacity)
                .borderRadius(this.bubbleLiquidAccentWidth / 2)
                .margin({ bottom: 9 })

              Text('')
                .width(this.bubbleLiquidSurfaceWidth + 16)
                .height(18)
                .backgroundColor(this.getSelectedDateCalorieThemeColor())
                .opacity(0.12)
                .borderRadius(12)
                .margin({ bottom: this.getBubbleLiquidSurfaceBottom() - 4 })

              Text('')
                .width(this.bubbleLiquidSurfaceWidth)
                .height(14)
                .backgroundColor('#FFFFFF')
                .opacity(0.42)
                .borderRadius(10)
                .margin({ bottom: this.getBubbleLiquidSurfaceBottom() })
            }

            Text('')
              .width(72)
              .height(72)
              .backgroundColor('#FFFFFF')
              .opacity(0.18)
              .borderRadius(36)
              .margin({ bottom: 28, left: 40 + this.bubbleHighlightOffset })

            Text('')
              .width(44)
              .height(92)
              .backgroundColor('#FFFFFF')
              .opacity(0.16)
              .borderRadius(24)
              .margin({ bottom: 16, left: 38 })

            Text('')
              .width(84)
              .height(24)
              .backgroundColor('#FFFFFF')
              .opacity(0.48)
              .borderRadius(15)
              .margin({ bottom: 86 + this.bubbleHighlightOffset })
          }
          .width(126)
          .height(126)
          .translate({ x: 0, y: this.bubbleFloatOffset })

          Text('')
            .width(136)
            .height(136)
            .border({
              width: 7,
              color: this.getSelectedDateCalorieThemeColor()
            })
            .opacity(0.6)
            .borderRadius(68)
            .translate({ x: 0, y: this.bubbleFloatOffset })

          Text('')
            .width(150)
            .height(150)
            .border({
              width: 2,
              color: '#FFFFFF'
            })
            .opacity(0.3)
            .borderRadius(75)
            .translate({ x: 0, y: this.bubbleFloatOffset })

          Text('')
            .width(this.bubbleReflectSize)
            .height(this.bubbleReflectSize)
            .backgroundColor(this.getSelectedDateCalorieThemeColor())
            .opacity(0.88)
            .borderRadius(this.bubbleReflectSize / 2)
            .margin({ bottom: 158, right: 82 })
            .translate({ x: 0, y: this.bubbleFloatOffset })

          Text('')
            .width(12)
            .height(12)
            .backgroundColor('#FFFFFF')
            .opacity(0.74)
            .borderRadius(6)
            .margin({ bottom: 136, left: 90 })
            .translate({ x: 0, y: this.bubbleFloatOffset })

          Column({ space: 2 }) {
            Text(`${this.getSelectedDateCaloriePercent()}%`)
              .fontSize(32)
              .fontWeight(FontWeight.Bolder)
              .fontColor('#213244')

            Text('目标完成度')
              .fontSize(11)
              .fontColor('#6D8196')
          }
          .alignItems(HorizontalAlign.Center)
          .translate({ x: 0, y: this.bubbleFloatOffset })
        }
        .width('100%')
        .height(214)

        Row({ space: 10 }) {
          Column({ space: 4 }) {
            Text('目标热量')
              .fontSize(11)
              .fontColor('#86A4C7')

            Text(`${this.getDailyCalorieTarget()} kcal`)
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .padding(14)
          .backgroundColor('#203B57')
          .borderRadius(18)

          Column({ space: 4 }) {
            Text(this.getSelectedDateCalorieGapLabelText())
              .fontSize(11)
              .fontColor('#86A4C7')

            Text(this.getSelectedDateCalorieGapValueText())
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .padding(14)
          .backgroundColor('#203B57')
          .borderRadius(18)
        }
        .width('100%')
      }
      .alignItems(HorizontalAlign.Center)
      .width('100%')
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#17324D')
    .borderRadius(28)
  }

  @Builder
  buildDailyTargetButton() {
    Button() {
      Row() {
        Column({ space: 4 }) {
          Text('设定今日目标')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text(`当前 ${this.getDailyCalorieTarget()} kcal`)
            .fontSize(12)
            .fontColor(SECONDARY_TEXT_COLOR)
        }
        .alignItems(HorizontalAlign.Start)

        Text('去设置')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#17324D')
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor('#EEF3FF')
          .borderRadius(999)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 16, bottom: 16 })
    .backgroundColor(SURFACE_BACKGROUND_COLOR)
    .borderRadius(22)
    .onClick(() => {
      this.openDailyTargetDialog();
    })
  }

  @Builder
  buildDailyTargetDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Text('')
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')
        .opacity(0.38)
        .onClick(() => {
          this.closeDailyTargetDialog();
        })

      Column({ space: 16 }) {
        Column({ space: 6 }) {
          Text('设定今日目标')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text('填写今天想控制的热量，点击遮罩或取消都可以关闭。')
            .fontSize(13)
            .lineHeight(20)
            .fontColor(SECONDARY_TEXT_COLOR)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')

        Row({ space: 10 }) {
          TextInput({ placeholder: `${DEFAULT_DAILY_CALORIE_TARGET}`, text: this.dailyTargetDraftText })
            .layoutWeight(1)
            .height(46)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_TEXT_COLOR)
            .padding({ left: 14, right: 14 })
            .backgroundColor('#F5F7FB')
            .borderRadius(16)
            .onChange((value: string) => {
              this.dailyTargetDraftText = this.sanitizeDailyCalorieTargetInput(value);
            })

          Text('kcal')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor('#5B6B7F')
            .padding({ left: 14, right: 14, top: 13, bottom: 13 })
            .backgroundColor('#EFF3F8')
            .borderRadius(16)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(this.getDailyCalorieTargetHintTextByText(this.dailyTargetDraftText))
          .fontSize(11)
          .fontColor('#6C7D91')
          .width('100%')

        Row({ space: 12 }) {
          Button('取消')
            .layoutWeight(1)
            .height(42)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#5B6B7F')
            .backgroundColor('#EFF3F8')
            .borderRadius(21)
            .onClick(() => {
              this.closeDailyTargetDialog();
            })

          Button('保存')
            .layoutWeight(1)
            .height(42)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .backgroundColor('#17324D')
            .borderRadius(21)
            .onClick(() => {
              this.saveDailyTargetDialog();
            })
        }
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .width('84%')
      .padding(22)
      .backgroundColor('#FFFFFF')
      .borderRadius(26)
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 6 }) {
            Text('食物卡片')
              .fontSize(28)
              .fontWeight(FontWeight.Bolder)
              .fontColor(PRIMARY_TEXT_COLOR)

            Text('安排每天吃什么、统计热量，后续这里可以直接传给后端。')
              .fontSize(14)
              .fontColor(SECONDARY_TEXT_COLOR)
              .lineHeight(22)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')

          this.buildCalorieOverviewCard()
          this.buildDailyTargetButton()

          Column({ space: 12 }) {
            Row() {
              Column({ space: 4 }) {
                Text('拍照识别热量')
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(PRIMARY_TEXT_COLOR)

                Text('目前先提供入口，后续接拍照和识别逻辑。')
                  .fontSize(12)
                  .fontColor(SECONDARY_TEXT_COLOR)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Button('去拍照')
                .height(38)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#FFFFFF')
                .backgroundColor('#17324D')
                .borderRadius(19)
                .onClick(() => {
                  this.scannerNotice = '拍照识别入口已点击，后续这里可以接相机与热量识别接口。';
                })
            }
            .width('100%')

            Text(this.scannerNotice)
              .fontSize(13)
              .lineHeight(20)
              .fontColor('#4F6690')
              .padding(14)
              .width('100%')
              .backgroundColor('#EEF4FF')
              .borderRadius(18)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(18)
          .backgroundColor(SURFACE_BACKGROUND_COLOR)
          .borderRadius(24)

          this.buildCalendarCard()
          this.buildMealPlanCard()
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

      if (this.isDailyTargetDialogVisible) {
        this.buildDailyTargetDialog()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PAGE_BACKGROUND_COLOR)
  }
}
