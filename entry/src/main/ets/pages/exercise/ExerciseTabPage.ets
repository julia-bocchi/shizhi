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
  createDraftFromSavedCustomWorkout,
  deserializeSavedCustomWorkouts,
  deserializeWorkoutRecords,
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

  @State savedCustomWorkouts: SavedCustomWorkout[] = [];
  @State workoutPlans: WorkoutPlanItem[] = [];
  @State selectedPlanDate: string = formatDate(new Date());
  @State calendarYear: number = new Date().getFullYear();
  @State calendarMonth: number = new Date().getMonth();
  @State planSectionExpanded: boolean = true;
  @State planPickerVisible: boolean = false;
  @State planTitleInput: string = '';
  @State planNotesInput: string = '';

  aboutToAppear(): void {
    EXERCISE_STORAGE_READY;
    this.syncSavedCustomWorkoutsFromStorage();
    this.syncWorkoutPlansFromStorage();
  }

  private syncSavedCustomWorkoutsFromStorage(): void {
    this.savedCustomWorkouts = deserializeSavedCustomWorkouts(this.savedCustomWorkoutText);
  }

  private syncWorkoutPlansFromStorage(): void {
    this.workoutPlans = deserializeWorkoutPlans(this.workoutPlanText);
  }

  private saveWorkoutPlans(nextPlans: WorkoutPlanItem[]): void {
    this.workoutPlans = nextPlans;
    this.workoutPlanText = serializeWorkoutPlans(nextPlans);
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

  private openDraft(draftText: string, savedWorkoutId: string): void {
    this.currentExerciseDraftText = draftText;
    this.currentExerciseProfileText = serializeUserProfile(this.userProfile);
    this.currentEditingSavedWorkoutIdText = savedWorkoutId;
    try {
      let routeTask: Promise<void> = this.getUIContext().getRouter().pushUrl({
        url: 'pages/exercise/ExerciseDetailPage'
      });
      routeTask.catch(() => {
      });
    } catch (error) {
    }
  }

  private openDraftFromWorkout(draft: ExerciseDraft, savedWorkoutId: string): void {
    this.openDraft(serializeExerciseDraft(draft), savedWorkoutId);
  }

  private selectExercise(optionId: string): void {
    let draft: ExerciseDraft = createDefaultExerciseDraft();
    draft.exerciseId = optionId;
    if (optionId !== 'custom') {
      draft.customName = '';
    }
    this.openDraftFromWorkout(draft, '');
  }

  private selectSavedCustomWorkout(savedWorkout: SavedCustomWorkout): void {
    let draft: ExerciseDraft = createDraftFromSavedCustomWorkout(savedWorkout);
    this.openDraftFromWorkout(draft, savedWorkout.id);
  }

  private addPlanFromDraft(draft: ExerciseDraft, savedWorkoutId: string): void {
    let nextPlans: WorkoutPlanItem[] = this.workoutPlans.slice();
    nextPlans.unshift(createWorkoutPlanItem(
      this.selectedPlanDate,
      draft,
      this.userProfile,
      this.planTitleInput,
      this.planNotesInput,
      savedWorkoutId
    ));

    this.saveWorkoutPlans(nextPlans);
    this.planPickerVisible = false;
    this.planTitleInput = '';
    this.planNotesInput = '';
  }

  private togglePlanSection(): void {
    this.planSectionExpanded = !this.planSectionExpanded;
  }

  private openPlanPicker(): void {
    this.planPickerVisible = true;
  }

  private closePlanPicker(): void {
    this.planPickerVisible = false;
  }

  private addPlanFromExercise(option: ExerciseOption): void {
    let draft: ExerciseDraft = createDefaultExerciseDraft();
    draft.exerciseId = option.id;
    if (option.id !== 'custom') {
      draft.customName = '';
    }
    this.addPlanFromDraft(draft, '');
  }

  private addPlanFromSavedWorkout(savedWorkout: SavedCustomWorkout): void {
    let draft: ExerciseDraft = createDraftFromSavedCustomWorkout(savedWorkout);
    this.addPlanFromDraft(draft, savedWorkout.id);
  }

  private removeWorkoutPlan(planId: string): void {
    let nextPlans: WorkoutPlanItem[] = [];
    for (let index = 0; index < this.workoutPlans.length; index++) {
      if (this.workoutPlans[index].id !== planId) {
        nextPlans.push(this.workoutPlans[index]);
      }
    }
    this.saveWorkoutPlans(nextPlans);
  }

  private openWorkoutPlan(plan: WorkoutPlanItem): void {
    this.openDraft(plan.draftText, plan.savedWorkoutId);
  }

  private getPlanCountByDate(dateText: string): number {
    let count: number = 0;
    for (let index = 0; index < this.workoutPlans.length; index++) {
      if (this.workoutPlans[index].date === dateText) {
        count += 1;
      }
    }
    return count;
  }

  private getPlansForSelectedDate(): WorkoutPlanItem[] {
    let result: WorkoutPlanItem[] = [];
    for (let index = 0; index < this.workoutPlans.length; index++) {
      if (this.workoutPlans[index].date === this.selectedPlanDate) {
        result.push(this.workoutPlans[index]);
      }
    }
    return result;
  }

  private getSelectedDatePlanCountText(): string {
    let count: number = this.getPlansForSelectedDate().length;
    return count > 0 ? `${count} 项计划` : '暂无计划';
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
    let todayText: string = formatDate(new Date());

    for (let index = 0; index < 42; index++) {
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
  buildPlanOverviewCard() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 4 }) {
          Text('训练日历与计划')
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
            .fontColor('#4F6690')
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor('#EEF3FF')
            .borderRadius(999)

          Button(this.planSectionExpanded ? '收起' : '展开')
            .height(34)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#17324D')
            .backgroundColor('#EEF3FF')
            .borderRadius(17)
            .onClick(() => {
              this.togglePlanSection();
            })
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)

      if (this.planSectionExpanded) {
        Column({ space: 14 }) {
          Row() {
            Button('<')
              .width(38)
              .height(38)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#17324D')
              .backgroundColor('#EEF3FF')
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
              .fontColor('#17324D')
              .backgroundColor('#EEF3FF')
              .borderRadius(19)
              .onClick(() => {
                this.changeCalendarMonth(1);
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)

          Row() {
            Text('日').layoutWeight(1).textAlign(TextAlign.Center).fontSize(12).fontColor('#7D8794')
            Text('一').layoutWeight(1).textAlign(TextAlign.Center).fontSize(12).fontColor('#7D8794')
            Text('二').layoutWeight(1).textAlign(TextAlign.Center).fontSize(12).fontColor('#7D8794')
            Text('三').layoutWeight(1).textAlign(TextAlign.Center).fontSize(12).fontColor('#7D8794')
            Text('四').layoutWeight(1).textAlign(TextAlign.Center).fontSize(12).fontColor('#7D8794')
            Text('五').layoutWeight(1).textAlign(TextAlign.Center).fontSize(12).fontColor('#7D8794')
            Text('六').layoutWeight(1).textAlign(TextAlign.Center).fontSize(12).fontColor('#7D8794')
          }
          .width('100%')

          Column({ space: 8 }) {
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
                            .backgroundColor('#1E6BFF')
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
                            .fontColor(this.isSelectedCalendarDay(day.dateText) ? '#EAF1FF' : (day.isToday ? '#1E6BFF' : '#98A2B3'))
                            .maxLines(1)
                        }
                        .alignItems(HorizontalAlign.Center)

                        if (day.planCount > 0) {
                          Text('')
                            .width(7)
                            .height(7)
                            .backgroundColor(this.isSelectedCalendarDay(day.dateText) ? '#FFFFFF' : '#1E6BFF')
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
                  .height(72)
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

          Column({ space: 12 }) {
            Row() {
              Column({ space: 4 }) {
                Text('当日计划')
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(PRIMARY_TEXT_COLOR)

                Text(this.getSelectedDatePlanCountText())
                  .fontSize(12)
                  .fontColor(SECONDARY_TEXT_COLOR)
              }
              .alignItems(HorizontalAlign.Start)

              Button('+ 添加')
                .height(36)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor('#FFFFFF')
                .backgroundColor('#17324D')
                .borderRadius(18)
                .onClick(() => {
                  this.openPlanPicker();
                })
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)

            if (this.getPlansForSelectedDate().length === 0) {
              Text('点击右上角“+ 添加”，从现有运动类型中加入当天计划。')
                .fontSize(13)
                .lineHeight(20)
                .fontColor(SECONDARY_TEXT_COLOR)
                .width('100%')
                .padding(14)
                .backgroundColor('#F6F8FB')
                .borderRadius(16)
            }

            ForEach(this.getPlansForSelectedDate(), (plan: WorkoutPlanItem) => {
              Column({ space: 10 }) {
                Row() {
                  Column({ space: 4 }) {
                    Text(plan.title)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(PRIMARY_TEXT_COLOR)

                    Text(plan.summary)
                      .fontSize(12)
                      .lineHeight(18)
                      .fontColor(SECONDARY_TEXT_COLOR)

                    if (plan.notes.trim().length > 0) {
                      Text(plan.notes)
                        .fontSize(12)
                        .lineHeight(18)
                        .fontColor('#4F6690')
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Text(this.formatFriendlyDate(plan.date))
                    .fontSize(11)
                    .fontColor('#7D8794')
                }
                .width('100%')
                .alignItems(VerticalAlign.Top)

                Row({ space: 10 }) {
                  Button('开始训练')
                    .layoutWeight(1)
                    .height(40)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#FFFFFF')
                    .backgroundColor(plan.accentColor)
                    .borderRadius(16)
                    .onClick(() => {
                      this.openWorkoutPlan(plan);
                    })

                  Button('删除')
                    .width(82)
                    .height(40)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#7A5C2E')
                    .backgroundColor('#F8EEDC')
                    .borderRadius(16)
                    .onClick(() => {
                      this.removeWorkoutPlan(plan.id);
                    })
                }
                .width('100%')
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding(16)
              .backgroundColor('#F6F8FB')
              .borderRadius(18)
            }, (plan: WorkoutPlanItem) => plan.id)
          }
          .width('100%')
        }
        .width('100%')
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
              .fontColor('#17324D')
              .backgroundColor('#EEF3FF')
              .borderRadius(17)
              .onClick(() => {
                this.closePlanPicker();
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)

          TextInput({ placeholder: '计划标题，可留空默认使用训练名', text: this.planTitleInput })
            .fontSize(15)
            .fontColor(PRIMARY_TEXT_COLOR)
            .height(46)
            .width('100%')
            .padding({ left: 12, right: 12 })
            .backgroundColor('#F6F8FB')
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
            .backgroundColor('#F6F8FB')
            .borderRadius(16)
            .onChange((value: string) => {
              this.planNotesInput = value;
            })

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

                  Button('添加')
                    .width(74)
                    .height(36)
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#FFFFFF')
                    .backgroundColor(option.accentColor)
                    .borderRadius(18)
                    .onClick(() => {
                      this.addPlanFromExercise(option);
                    })
                }
                .width('100%')
                .padding(14)
                .backgroundColor('#F6F8FB')
                .borderRadius(18)
              }, (option: ExerciseOption) => option.id)

              if (this.savedCustomWorkouts.length > 0) {
                Text('已保存模板')
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#667085')
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

                    Button('添加')
                      .width(74)
                      .height(36)
                      .fontSize(13)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#FFFFFF')
                      .backgroundColor('#7A5C2E')
                      .borderRadius(18)
                      .onClick(() => {
                        this.addPlanFromSavedWorkout(savedWorkout);
                      })
                  }
                  .width('100%')
                  .padding(14)
                  .backgroundColor('#FBF3E4')
                  .borderRadius(18)
                }, (savedWorkout: SavedCustomWorkout) => savedWorkout.id)
              }
            }
            .width('100%')
            .padding({ right: 2, bottom: 8 })
          }
          .width('100%')
          .height(320)
          .scrollable(ScrollDirection.Vertical)
          .scrollBar(BarState.Auto)
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

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Scroll() {
        Column({ space: 18 }) {
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
              .fontColor('#D8E5FF')

            Text(this.getTodayCaloriesText())
              .fontSize(34)
              .fontWeight(FontWeight.Bolder)
              .fontColor('#FFFFFF')

            Text(this.getTodayWorkoutCountText())
              .fontSize(13)
              .fontColor('#B7CAE8')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(18)
          .backgroundColor('#17324D')
          .borderRadius(24)

          this.buildPlanOverviewCard()

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
              .fontColor('#667085')

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
                    .backgroundColor('#EEF3FF')
                    .borderRadius(16)
                    .onClick(() => {
                      this.addPlanFromExercise(option);
                    })
                }
                .width('100%')
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding(16)
              .backgroundColor('#F6F8FB')
              .borderRadius(18)
            }, (option: ExerciseOption) => option.id)

            if (this.savedCustomWorkouts.length > 0) {
              Text('已保存模板')
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor('#667085')
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
                      .backgroundColor('#7A5C2E')
                      .borderRadius(16)
                      .onClick(() => {
                        this.selectSavedCustomWorkout(savedWorkout);
                      })

                    Button('加入计划')
                      .layoutWeight(1)
                      .height(40)
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#7A5C2E')
                      .backgroundColor('#F8EEDC')
                      .borderRadius(16)
                      .onClick(() => {
                        this.addPlanFromSavedWorkout(savedWorkout);
                      })
                  }
                  .width('100%')
                }
                .alignItems(HorizontalAlign.Start)
                .width('100%')
                .padding(14)
                .backgroundColor('#FBF3E4')
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
