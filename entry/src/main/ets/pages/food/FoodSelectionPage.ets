import {
  PAGE_BACKGROUND_COLOR,
  PRIMARY_TEXT_COLOR,
  SECONDARY_TEXT_COLOR,
  SURFACE_BACKGROUND_COLOR
} from '../../constants/AppTheme';
import { FoodPlanItem } from '../../models/FoodPlan';
import { FoodOption, PRESET_FOOD_OPTIONS } from '../../models/FoodOption';
import {
  createFoodPlanItem,
  deserializeCustomFoodOptions,
  deserializeFoodPlans,
  getFoodMealLabel,
  serializeCustomFoodOptions,
  serializeFoodPlans
} from '../../utils/FoodHelper';
import { formatDate } from '../../utils/WeightRecordHelper';
import { EXERCISE_STORAGE_READY } from '../../utils/ExerciseStorage';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { AuthSession, DEFAULT_API_BASE_URL, isAuthSessionValid } from '../../models/AuthSession';
import { deserializeAuthSession } from '../../utils/AuthStorageHelper';
import {
  createCustomFoodOptionRemote,
  createFoodPlanRemote,
  deleteFoodPlanRemote,
  fetchFoodOptions,
  fetchFoodPlans
} from '../../utils/ApiService';

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
    this.syncRemoteFoodData();
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
      this.customFoodOptions = remoteOptions;
      this.customFoodOptionText = serializeCustomFoodOptions(remoteOptions);
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
      image: plan.image,
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
    if (this.customFoodImage.trim().length === 0) {
      this.pageNotice = '请先从相册选择一张食物图片。';
      return;
    }

    let customOption: FoodOption = {
      id: `custom-food-${Date.now()}`,
      name: name,
      description: this.customFoodDescription.trim().length > 0 ? this.customFoodDescription.trim() : '自定义食物卡片',
      calories: caloriesValue,
      serving: serving,
      mealSuggestion: getFoodMealLabel(this.selectedMealType),
      image: this.customFoodImage.trim(),
      accentColor: this.getMealAccentColor()
    };

    let authSession = deserializeAuthSession(this.authSessionText);
    if (isAuthSessionValid(authSession)) {
      try {
        customOption = await createCustomFoodOptionRemote(this.apiBaseUrlText, authSession, {
          name: customOption.name,
          description: customOption.description,
          calories: customOption.calories,
          serving: customOption.serving,
          mealSuggestion: customOption.mealSuggestion,
          image: customOption.image,
          accentColor: customOption.accentColor
        });
      } catch (error) {
        this.pageNotice = `${error}`;
        return;
      }
    }

    let nextOptions: FoodOption[] = this.customFoodOptions.slice();
    nextOptions.unshift(customOption);
    this.saveCustomFoodOptions(nextOptions);

    if (addToMeal) {
      this.increaseDraftSelection(customOption);
      this.pageNotice = `已创建 ${customOption.name}，并加入待保存清单。`;
    } else {
      this.pageNotice = `已保存自定义食物卡：${customOption.name}。`;
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
    let authSession = deserializeAuthSession(this.authSessionText);
    if (isAuthSessionValid(authSession)) {
      try {
        for (let index = 0; index < savedMealPlans.length; index++) {
          await deleteFoodPlanRemote(this.apiBaseUrlText, authSession, savedMealPlans[index].id);
        }
        for (let index = 0; index < this.draftSelections.length; index++) {
          for (let countIndex = 0; countIndex < this.draftSelections[index].count; countIndex++) {
            nextMealPlans.push(await createFoodPlanRemote(this.apiBaseUrlText, authSession, {
              date: this.selectedDate,
              foodId: this.draftSelections[index].option.id,
              mealType: this.selectedMealType,
              notes: this.planNotesInput
            }));
          }
        }
      } catch (error) {
        this.pageNotice = `${error}`;
        return;
      }
    } else {
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
    }

    this.saveFoodPlans(nextMealPlans.concat(remainingPlans));
    this.quantitySheetVisible = false;
    this.customSheetVisible = false;
    this.pageNotice = nextMealPlans.length > 0
      ? `已保存今天${getFoodMealLabel(this.selectedMealType)}的选择，共 ${nextMealPlans.length} 份。`
      : `已清空今天${getFoodMealLabel(this.selectedMealType)}的选择。`;
    this.goBack();
  }

  private getSortedFoodOptions(): FoodOption[] {
    let result: FoodOption[] = [];
    let knownIds: string[] = [];
    for (let index = 0; index < PRESET_FOOD_OPTIONS.length; index++) {
      result.push(PRESET_FOOD_OPTIONS[index]);
      knownIds.push(PRESET_FOOD_OPTIONS[index].id);
    }
    for (let index = 0; index < this.customFoodOptions.length; index++) {
      if (knownIds.indexOf(this.customFoodOptions[index].id) >= 0) {
        continue;
      }
      result.push(this.customFoodOptions[index]);
      knownIds.push(this.customFoodOptions[index].id);
    }

    result.sort((left: FoodOption, right: FoodOption) => {
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
        image: 'https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=900&q=80',
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
    if (option.id.indexOf('custom-food-') === 0) {
      return '我的卡片';
    }
    return option.mealSuggestion === getFoodMealLabel(this.selectedMealType) ? '推荐' : '可选';
  }

  @Builder
  buildCreateFoodCard() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Image('https://images.unsplash.com/photo-1495195134817-aeb325a55b65?auto=format&fit=crop&w=900&q=80')
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

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
      .backgroundColor('#990D1628')
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
      Image(option.image)
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

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
                    Image(draft.option.image)
                      .width('100%')
                      .height(120)
                      .objectFit(ImageFit.Cover)
                      .borderRadius(18)

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

              Text('点击下面按钮，从相册里选一张食物图片')
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
              Text(`正在安排 ${getFoodMealLabel(this.selectedMealType)}`)
                .fontSize(24)
                .fontWeight(FontWeight.Bolder)
                .fontColor(PRIMARY_TEXT_COLOR)

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
