import {
  PAGE_BACKGROUND_COLOR,
  PRIMARY_TEXT_COLOR,
  SECONDARY_TEXT_COLOR,
  SURFACE_BACKGROUND_COLOR
} from '../../constants/AppTheme';
import { FoodPlanItem } from '../../models/FoodPlan';
import { FoodMealOption, FOOD_MEAL_OPTIONS } from '../../models/FoodOption';
import { deserializeFoodPlans } from '../../utils/FoodHelper';
import { formatDate } from '../../utils/WeightRecordHelper';
import { EXERCISE_STORAGE_READY } from '../../utils/ExerciseStorage';

@Entry
@Component
struct FoodPlanPage {
  @StorageLink('foodPlanText') foodPlanText: string = '';
  @StorageLink('currentFoodPlanDateText') currentFoodPlanDateText: string = '';
  @StorageLink('currentFoodPlanMealTypeText') currentFoodPlanMealTypeText: string = '';

  @State selectedDate: string = formatDate(new Date());
  @State pageNotice: string = '先选择要安排的餐次，再进入卡片页挑选食物。';

  aboutToAppear(): void {
    EXERCISE_STORAGE_READY;
    if (this.currentFoodPlanDateText.trim().length > 0) {
      this.selectedDate = this.currentFoodPlanDateText;
    } else {
      this.currentFoodPlanDateText = this.selectedDate;
    }
  }

  private getAllFoodPlans(): FoodPlanItem[] {
    return deserializeFoodPlans(this.foodPlanText);
  }

  private goBack(): void {
    try {
      this.getUIContext().getRouter().back();
    } catch (error) {
      this.pageNotice = '返回失败，请重试。';
    }
  }

  private openMealSelection(mealType: string): void {
    this.currentFoodPlanMealTypeText = mealType;
    try {
      let routeTask: Promise<void> = this.getUIContext().getRouter().pushUrl({
        url: 'pages/food/FoodSelectionPage'
      });
      routeTask.catch(() => {
      });
    } catch (error) {
      this.pageNotice = '打开食物选择页失败，请重试。';
    }
  }

  private formatFriendlyDate(dateText: string): string {
    let fields: string[] = dateText.split('-');
    if (fields.length < 3) {
      return dateText;
    }
    return `${fields[0]}年${Number(fields[1])}月${Number(fields[2])}日`;
  }

  private getPlansForMeal(mealType: string): FoodPlanItem[] {
    let result: FoodPlanItem[] = [];
    let currentPlans: FoodPlanItem[] = this.getAllFoodPlans();
    for (let index = 0; index < currentPlans.length; index++) {
      if (currentPlans[index].date === this.selectedDate && currentPlans[index].mealType === mealType) {
        result.push(currentPlans[index]);
      }
    }
    return result;
  }

  private getMealCalories(mealType: string): number {
    let totalCalories: number = 0;
    let mealPlans: FoodPlanItem[] = this.getPlansForMeal(mealType);
    for (let index = 0; index < mealPlans.length; index++) {
      totalCalories += mealPlans[index].calories;
    }
    return totalCalories;
  }

  private getMealPreviewText(mealType: string): string {
    let mealPlans: FoodPlanItem[] = this.getPlansForMeal(mealType);
    if (mealPlans.length === 0) {
      return '还没安排食物，点击下方按钮去选择。';
    }

    let names: string[] = [];
    for (let index = 0; index < mealPlans.length && index < 3; index++) {
      names.push(mealPlans[index].name);
    }

    let joinedNames: string = names.join(' · ');
    if (mealPlans.length > 3) {
      return `${joinedNames} 等 ${mealPlans.length} 项`;
    }
    return joinedNames;
  }

  private getSelectedDatePlanCount(): number {
    let count: number = 0;
    let currentPlans: FoodPlanItem[] = this.getAllFoodPlans();
    for (let index = 0; index < currentPlans.length; index++) {
      if (currentPlans[index].date === this.selectedDate) {
        count += 1;
      }
    }
    return count;
  }

  private getSelectedDateCalories(): number {
    let totalCalories: number = 0;
    let currentPlans: FoodPlanItem[] = this.getAllFoodPlans();
    for (let index = 0; index < currentPlans.length; index++) {
      if (currentPlans[index].date === this.selectedDate) {
        totalCalories += currentPlans[index].calories;
      }
    }
    return totalCalories;
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
      return '#FFF7E8';
    }
    if (mealType === 'lunch') {
      return '#EDFDF5';
    }
    if (mealType === 'dinner') {
      return '#EEF4FF';
    }
    return '#F5EEFF';
  }

  @Builder
  buildMealPlanCard(meal: FoodMealOption) {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 6 }) {
          Text(meal.label)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text(`${this.getPlansForMeal(meal.id).length} 张卡片 · ${Math.round(this.getMealCalories(meal.id))} kcal`)
            .fontSize(12)
            .fontColor('#4F6690')
        }
        .alignItems(HorizontalAlign.Start)

        Text(this.getPlansForMeal(meal.id).length > 0 ? '已安排' : '待选择')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getMealAccentColor(meal.id))
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('#FFFFFF')
          .borderRadius(999)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)

      Text(this.getMealPreviewText(meal.id))
        .fontSize(13)
        .lineHeight(20)
        .fontColor(SECONDARY_TEXT_COLOR)
        .width('100%')

      if (this.getPlansForMeal(meal.id).length > 0) {
        Row({ space: 8 }) {
          ForEach(this.getPlansForMeal(meal.id).slice(0, 2), (plan: FoodPlanItem) => {
            Text(plan.name)
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getMealAccentColor(meal.id))
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor('#FFFFFF')
              .borderRadius(999)
          }, (plan: FoodPlanItem) => plan.id)
        }
        .width('100%')
      }

      Button(`选择${meal.label}食物`)
        .width('100%')
        .height(42)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .backgroundColor(this.getMealAccentColor(meal.id))
        .borderRadius(20)
        .onClick(() => {
          this.openMealSelection(meal.id);
        })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(18)
    .backgroundColor(this.getMealSurfaceColor(meal.id))
    .borderRadius(24)
  }

  build() {
    Column() {
      Row() {
        Image($r('sys.media.ohos_ic_back'))
          .width(22)
          .height(22)
          .borderRadius(21)
          .onClick(() => {
            this.goBack();
          })

        Text('制定饮食计划')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(PRIMARY_TEXT_COLOR)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Text('')
          .width(22)
          .height(22)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .padding({ left: 16, right: 16, top: 12, bottom: 14 })
      .backgroundColor(SURFACE_BACKGROUND_COLOR)
      .border({ color: '#E3EAF4', width: { top: 1 } })

      Scroll() {
        Column({ space: 18 }) {
          Column({ space: 12 }) {
            Text(this.formatFriendlyDate(this.selectedDate))
              .fontSize(24)
              .fontWeight(FontWeight.Bolder)
              .fontColor(PRIMARY_TEXT_COLOR)

            Text(`当天共安排 ${this.getSelectedDatePlanCount()} 张卡片 · ${Math.round(this.getSelectedDateCalories())} kcal`)
              .fontSize(13)
              .fontColor(SECONDARY_TEXT_COLOR)

            Text(this.pageNotice)
              .fontSize(13)
              .lineHeight(20)
              .fontColor('#4F6690')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(18)
          .backgroundColor(SURFACE_BACKGROUND_COLOR)
          .borderRadius(24)

          Column({ space: 14 }) {
            ForEach(FOOD_MEAL_OPTIONS, (meal: FoodMealOption) => {
              this.buildMealPlanCard(meal)
            }, (meal: FoodMealOption) => meal.id)
          }
          .width('100%')
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
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PAGE_BACKGROUND_COLOR)
  }
}
