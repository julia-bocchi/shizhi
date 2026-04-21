import {
  PRIMARY_TEXT_COLOR,
  SECONDARY_TEXT_COLOR,
  SURFACE_BACKGROUND_COLOR
} from '../../constants/AppTheme';
import {
  AI_ROLE_ASSISTANT,
  AI_ROLE_USER,
  AI_TASK_ANALYZE_WEIGHT,
  AI_TASK_CHAT,
  AI_TASK_GENERATE_FULL_PLAN,
  AI_TASK_GENERATE_PLAN,
  AI_TASK_GENERATE_RECIPE,
  AiAssistantConfig,
  AiChatMessage,
  AiGeneratedFoodPlanItem,
  AiGeneratedPlanItem,
  createAiChatMessage,
  getDefaultAiApiEndpoint,
  getDefaultAiApiKey,
  getDefaultAiModel
} from '../../models/AiAssistant';
import { EXERCISE_TAB_INDEX, FOOD_TAB_INDEX, HOME_TAB_INDEX } from '../../models/TabItem';
import { UserProfile } from '../../models/UserProfile';
import { SavedCustomWorkout } from '../../models/ExerciseOption';
import { FoodPlanItem } from '../../models/FoodPlan';
import { WorkoutPlanItem } from '../../models/WorkoutPlan';
import { WeightRecord } from '../../models/WeightRecord';
import { WorkoutRecord } from '../../models/WorkoutRecord';
import {
  deserializeExerciseDraft,
  deserializeSavedCustomWorkouts,
  deserializeWorkoutRecords
} from '../../utils/ExerciseHelper';
import { requestAiAssistant } from '../../utils/AiAssistantHelper';
import {
  deserializeFoodPlans,
  serializeFoodPlans
} from '../../utils/FoodHelper';
import {
  deserializeWeightRecords,
  formatDate
} from '../../utils/WeightRecordHelper';
import {
  createWorkoutPlanItem,
  deserializeWorkoutPlans,
  serializeWorkoutPlans
} from '../../utils/WorkoutPlanHelper';

interface AssistantQuickActionItem {
  id: string;
  label: string;
}

const ASSISTANT_WELCOME_MESSAGE: string =
  '我是你的 AI 健身饮食助手。我可以分析近期体重变化，也能生成训练计划、定制食谱，以及整套运动和饮食计划。';
const ASSISTANT_DEFAULT_NOTICE: string = '可以直接发消息，也可以先点下面的快捷功能。';
const ASSISTANT_QUICK_ACTIONS: AssistantQuickActionItem[] = [
  { id: 'analyze', label: '趋势分析' },
  { id: 'plan', label: '训练计划' },
  { id: 'recipe', label: '定制食谱' },
  { id: 'full', label: '全套计划' }
];
const ASSISTANT_PRIMARY_ACTIONS: AssistantQuickActionItem[] = [
  ASSISTANT_QUICK_ACTIONS[0],
  ASSISTANT_QUICK_ACTIONS[1]
];
const ASSISTANT_SECONDARY_ACTIONS: AssistantQuickActionItem[] = [
  ASSISTANT_QUICK_ACTIONS[2],
  ASSISTANT_QUICK_ACTIONS[3]
];

@Component
export struct AiAssistantTabPage {
  @Link currentTabIndex: number;
  @Link userProfile: UserProfile;
  @StorageLink('weightRecordText') weightRecordText: string = '';
  @StorageLink('workoutPlanText') workoutPlanText: string = '';
  @StorageLink('workoutRecordText') workoutRecordText: string = '';
  @StorageLink('savedCustomWorkoutText') savedCustomWorkoutText: string = '';
  @StorageLink('foodPlanText') foodPlanText: string = '';
  @StorageLink('dailyFoodCalorieTargetText') dailyFoodCalorieTargetText: string = '';
  @StorageLink('aiApiEndpointText') aiApiEndpointText: string = '';
  @StorageLink('aiApiKeyText') aiApiKeyText: string = '';
  @StorageLink('aiModelText') aiModelText: string = '';

  @State questionInput: string = '';
  @State assistantBusy: boolean = false;
  @State assistantNotice: string = ASSISTANT_DEFAULT_NOTICE;
  @State chatMessages: AiChatMessage[] = [];
  @State generatedPlans: AiGeneratedPlanItem[] = [];
  @State generatedFoodPlans: AiGeneratedFoodPlanItem[] = [];
  @State showConfigPanel: boolean = false;

  aboutToAppear(): void {
    this.ensureDefaultAiConfig();
    if (this.chatMessages.length === 0) {
      this.resetConversation();
    }
  }

  private ensureDefaultAiConfig(): void {
    if (this.aiApiEndpointText.trim().length === 0) {
      this.aiApiEndpointText = getDefaultAiApiEndpoint();
    }
    if (this.aiModelText.trim().length === 0) {
      this.aiModelText = getDefaultAiModel();
    }
    if (this.aiApiKeyText.trim().length === 0) {
      this.aiApiKeyText = getDefaultAiApiKey();
    }
  }

  private restoreDefaultAiConfig(): void {
    this.aiApiEndpointText = getDefaultAiApiEndpoint();
    this.aiModelText = getDefaultAiModel();
    this.aiApiKeyText = getDefaultAiApiKey();
    this.assistantNotice = '已恢复默认模型配置。';
  }

  private resetConversation(): void {
    this.questionInput = '';
    this.generatedPlans = [];
    this.generatedFoodPlans = [];
    this.assistantBusy = false;
    this.chatMessages = [
      createAiChatMessage(AI_ROLE_ASSISTANT, ASSISTANT_WELCOME_MESSAGE)
    ];
    this.assistantNotice = ASSISTANT_DEFAULT_NOTICE;
  }

  private getAiConfig(): AiAssistantConfig {
    return {
      apiEndpoint: this.aiApiEndpointText,
      apiKey: this.aiApiKeyText,
      model: this.aiModelText
    };
  }

  private getWeightRecords(): WeightRecord[] {
    return deserializeWeightRecords(this.weightRecordText);
  }

  private getWorkoutPlans(): WorkoutPlanItem[] {
    return deserializeWorkoutPlans(this.workoutPlanText);
  }

  private getFoodPlans(): FoodPlanItem[] {
    return deserializeFoodPlans(this.foodPlanText);
  }

  private getWorkoutRecords(): WorkoutRecord[] {
    return deserializeWorkoutRecords(this.workoutRecordText);
  }

  private getSavedCustomWorkouts(): SavedCustomWorkout[] {
    return deserializeSavedCustomWorkouts(this.savedCustomWorkoutText);
  }

  private getDailyFoodCalorieTarget(): number {
    let targetValue: number = Number(this.dailyFoodCalorieTargetText.trim());
    if (isNaN(targetValue) || targetValue <= 0) {
      return 2000;
    }
    return targetValue;
  }

  private hasAiConfig(): boolean {
    return this.aiApiEndpointText.trim().length > 0 &&
      this.aiApiKeyText.trim().length > 0 &&
      this.aiModelText.trim().length > 0;
  }

  private getUserName(): string {
    return this.userProfile.nickname.trim().length > 0 ? this.userProfile.nickname.trim() : '你';
  }

  private getAssistantStatusText(): string {
    if (this.assistantBusy) {
      return 'AI 正在整理建议，请稍等。';
    }
    if (!this.hasAiConfig()) {
      return '还没填好接口配置，先补上 API 地址、模型和 Key。';
    }
    return this.assistantNotice;
  }

  private hasOnlyWelcomeMessage(): boolean {
    return this.chatMessages.length === 1 &&
      this.chatMessages[0].role === AI_ROLE_ASSISTANT &&
      this.chatMessages[0].content === ASSISTANT_WELCOME_MESSAGE;
  }

  private isAssistantMessage(message: AiChatMessage): boolean {
    return message.role === AI_ROLE_ASSISTANT;
  }

  private toggleConfigPanel(): void {
    this.showConfigPanel = !this.showConfigPanel;
  }

  private addChatMessage(role: string, content: string): void {
    let nextMessages: AiChatMessage[] = this.chatMessages.slice();
    nextMessages.push(createAiChatMessage(role, content));
    this.chatMessages = nextMessages;
  }

  private getTaskLoadingNotice(task: string): string {
    if (task === AI_TASK_GENERATE_PLAN) {
      return '正在生成训练计划草案...';
    }
    if (task === AI_TASK_GENERATE_RECIPE) {
      return '正在生成定制食谱...';
    }
    if (task === AI_TASK_GENERATE_FULL_PLAN) {
      return '正在生成运动和饮食全套计划...';
    }
    return '正在分析你的数据...';
  }

  private buildGeneratedResultNotice(task: string, workoutCount: number, foodCount: number): string {
    if (workoutCount > 0 && foodCount > 0) {
      return `AI 已生成 ${workoutCount} 条训练计划和 ${foodCount} 条饮食计划草案。`;
    }
    if (workoutCount > 0) {
      return `AI 已生成 ${workoutCount} 条训练计划草案，你可以先调整再导入。`;
    }
    if (foodCount > 0) {
      return `AI 已生成 ${foodCount} 条饮食计划草案，你可以先调整再导入。`;
    }
    if (task === AI_TASK_GENERATE_PLAN) {
      return 'AI 这次没有返回可导入训练计划，可以换个问法再试一次。';
    }
    if (task === AI_TASK_GENERATE_RECIPE) {
      return 'AI 这次没有返回可导入食谱，可以换个口味或目标再试一次。';
    }
    if (task === AI_TASK_GENERATE_FULL_PLAN) {
      return 'AI 这次没有返回完整计划，可以补充更多需求后再试一次。';
    }
    return 'AI 建议已更新。';
  }

  private applyAssistantResponse(task: string, workoutPlans: AiGeneratedPlanItem[],
    foodPlans: AiGeneratedFoodPlanItem[]): void {
    if (task === AI_TASK_GENERATE_PLAN) {
      this.generatedPlans = workoutPlans;
    } else if (task === AI_TASK_GENERATE_RECIPE) {
      this.generatedFoodPlans = foodPlans;
    } else if (task === AI_TASK_GENERATE_FULL_PLAN) {
      this.generatedPlans = workoutPlans;
      this.generatedFoodPlans = foodPlans;
    } else {
      if (workoutPlans.length > 0) {
        this.generatedPlans = workoutPlans;
      }
      if (foodPlans.length > 0) {
        this.generatedFoodPlans = foodPlans;
      }
    }
  }

  private async submitToAssistant(task: string, promptText: string): Promise<void> {
    let trimmedPrompt = promptText.trim();
    if (trimmedPrompt.length === 0) {
      this.assistantNotice = '先输入你想问 AI 的内容。';
      return;
    }
    if (this.assistantBusy) {
      this.assistantNotice = 'AI 还在处理中，稍等一下再发下一条。';
      return;
    }

    this.addChatMessage(AI_ROLE_USER, trimmedPrompt);
    this.questionInput = '';
    this.assistantBusy = true;
    this.assistantNotice = this.getTaskLoadingNotice(task);

    try {
      let savedWorkoutNames: string[] = [];
      let savedWorkouts: SavedCustomWorkout[] = this.getSavedCustomWorkouts();
      for (let index = 0; index < savedWorkouts.length; index++) {
        savedWorkoutNames.push(savedWorkouts[index].name);
      }

      let response = await requestAiAssistant(this.getAiConfig(), {
        task: task,
        userPrompt: trimmedPrompt,
        profile: this.userProfile,
        weightRecords: this.getWeightRecords(),
        workoutRecords: this.getWorkoutRecords(),
        existingPlanCount: this.getWorkoutPlans().length,
        existingFoodPlanCount: this.getFoodPlans().length,
        dailyFoodCalorieTarget: this.getDailyFoodCalorieTarget(),
        savedWorkoutNames: savedWorkoutNames,
        historyMessages: this.chatMessages
      });

      this.addChatMessage(AI_ROLE_ASSISTANT, response.reply);
      this.applyAssistantResponse(task, response.plans, response.foodPlans);
      this.assistantNotice = this.buildGeneratedResultNotice(task, response.plans.length, response.foodPlans.length);
    } catch (error) {
      let errorText = `${error}`;
      if (errorText.trim().length === 0 || errorText === '[object Object]') {
        errorText = 'AI 请求失败，请检查网络、模型名和 API Key。';
      }
      this.addChatMessage(AI_ROLE_ASSISTANT, `这次没有成功：${errorText}`);
      this.assistantNotice = errorText;
    } finally {
      this.assistantBusy = false;
    }
  }

  private askAboutWeightTrend(): void {
    this.submitToAssistant(
      AI_TASK_ANALYZE_WEIGHT,
      `请结合${this.getUserName()}最近的体重变化，告诉我最近需要注意什么，并给出 3 条以内的训练和饮食建议。`
    );
  }

  private generateWorkoutPlanDrafts(): void {
    this.submitToAssistant(
      AI_TASK_GENERATE_PLAN,
      `请结合${this.getUserName()}最近的体重和训练情况，为我生成接下来几天适合导入 App 的训练计划。`
    );
  }

  private generateRecipeDrafts(): void {
    this.submitToAssistant(
      AI_TASK_GENERATE_RECIPE,
      `请结合${this.getUserName()}当前的身体状态和热量目标，为我定制几份可直接导入的食谱和饮食安排。`
    );
  }

  private generateFullPlanDrafts(): void {
    this.submitToAssistant(
      AI_TASK_GENERATE_FULL_PLAN,
      `请结合${this.getUserName()}最近的体重变化、训练情况和饮食目标，为我定制接下来几天的运动计划和饮食计划。`
    );
  }

  private sendFreeQuestion(): void {
    this.submitToAssistant(AI_TASK_CHAT, this.questionInput);
  }

  private handleQuickAction(actionId: string): void {
    if (actionId === 'analyze') {
      this.askAboutWeightTrend();
      return;
    }
    if (actionId === 'plan') {
      this.generateWorkoutPlanDrafts();
      return;
    }
    if (actionId === 'recipe') {
      this.generateRecipeDrafts();
      return;
    }
    this.generateFullPlanDrafts();
  }

  private getQuickActionBackgroundColor(actionId: string): string {
    if (actionId === 'plan' && this.generatedPlans.length > 0) {
      return '#F2F0FF';
    }
    if (actionId === 'recipe' && this.generatedFoodPlans.length > 0) {
      return '#FFF6E8';
    }
    if (actionId === 'full' && (this.generatedPlans.length > 0 || this.generatedFoodPlans.length > 0)) {
      return '#ECFFF4';
    }
    if (actionId === 'analyze') {
      return '#EAF2FF';
    }
    return '#F7FAFF';
  }

  private getQuickActionBorderColor(actionId: string): string {
    if (actionId === 'plan' && this.generatedPlans.length > 0) {
      return '#D7CCFF';
    }
    if (actionId === 'recipe' && this.generatedFoodPlans.length > 0) {
      return '#F5D8A8';
    }
    if (actionId === 'full' && (this.generatedPlans.length > 0 || this.generatedFoodPlans.length > 0)) {
      return '#BEE5CC';
    }
    if (actionId === 'analyze') {
      return '#C8DBFF';
    }
    return '#D8E4F2';
  }

  private getMealLabel(mealType: string): string {
    if (mealType === 'breakfast') {
      return '早餐';
    }
    if (mealType === 'lunch') {
      return '午餐';
    }
    if (mealType === 'dinner') {
      return '晚餐';
    }
    if (mealType === 'snack') {
      return '加餐';
    }
    return '早餐';
  }

  private normalizeFoodMealType(mealType: string): string {
    let trimmedMealType = mealType.trim().toLowerCase();
    if (trimmedMealType === 'breakfast' || trimmedMealType === 'lunch' ||
      trimmedMealType === 'dinner' || trimmedMealType === 'snack') {
      return trimmedMealType;
    }
    return 'breakfast';
  }

  private parseFoodCalories(value: string, fallbackValue: number): number {
    let parsedValue: number = Number(value.trim());
    if (isNaN(parsedValue) || parsedValue < 0) {
      return fallbackValue;
    }
    return parsedValue;
  }

  private updateGeneratedPlanField(planId: string, field: string, value: string): void {
    let nextPlans: AiGeneratedPlanItem[] = [];
    for (let index = 0; index < this.generatedPlans.length; index++) {
      let currentPlan = this.generatedPlans[index];
      if (currentPlan.id !== planId) {
        nextPlans.push(currentPlan);
        continue;
      }

      nextPlans.push({
        id: currentPlan.id,
        date: field === 'date' ? value : currentPlan.date,
        title: field === 'title' ? value : currentPlan.title,
        summary: currentPlan.summary,
        notes: field === 'notes' ? value : currentPlan.notes,
        draftText: currentPlan.draftText,
        accentColor: currentPlan.accentColor,
        imported: currentPlan.imported
      });
    }
    this.generatedPlans = nextPlans;
  }

  private updateGeneratedFoodPlanField(planId: string, field: string, value: string): void {
    let nextPlans: AiGeneratedFoodPlanItem[] = [];
    for (let index = 0; index < this.generatedFoodPlans.length; index++) {
      let currentPlan = this.generatedFoodPlans[index];
      if (currentPlan.id !== planId) {
        nextPlans.push(currentPlan);
        continue;
      }

      nextPlans.push({
        id: currentPlan.id,
        date: field === 'date' ? value : currentPlan.date,
        mealType: field === 'mealType' ? value : currentPlan.mealType,
        name: field === 'name' ? value : currentPlan.name,
        description: currentPlan.description,
        calories: field === 'calories' ? this.parseFoodCalories(value, currentPlan.calories) : currentPlan.calories,
        serving: field === 'serving' ? value : currentPlan.serving,
        notes: field === 'notes' ? value : currentPlan.notes,
        image: currentPlan.image,
        accentColor: currentPlan.accentColor,
        imported: currentPlan.imported
      });
    }
    this.generatedFoodPlans = nextPlans;
  }

  private markPlanImported(planId: string): void {
    let nextPlans: AiGeneratedPlanItem[] = [];
    for (let index = 0; index < this.generatedPlans.length; index++) {
      let currentPlan = this.generatedPlans[index];
      nextPlans.push({
        id: currentPlan.id,
        date: currentPlan.date,
        title: currentPlan.title,
        summary: currentPlan.summary,
        notes: currentPlan.notes,
        draftText: currentPlan.draftText,
        accentColor: currentPlan.accentColor,
        imported: currentPlan.id === planId ? true : currentPlan.imported
      });
    }
    this.generatedPlans = nextPlans;
  }

  private markFoodPlanImported(planId: string): void {
    let nextPlans: AiGeneratedFoodPlanItem[] = [];
    for (let index = 0; index < this.generatedFoodPlans.length; index++) {
      let currentPlan = this.generatedFoodPlans[index];
      nextPlans.push({
        id: currentPlan.id,
        date: currentPlan.date,
        mealType: currentPlan.mealType,
        name: currentPlan.name,
        description: currentPlan.description,
        calories: currentPlan.calories,
        serving: currentPlan.serving,
        notes: currentPlan.notes,
        image: currentPlan.image,
        accentColor: currentPlan.accentColor,
        imported: currentPlan.id === planId ? true : currentPlan.imported
      });
    }
    this.generatedFoodPlans = nextPlans;
  }

  private importGeneratedPlan(planId: string): void {
    let targetPlan: AiGeneratedPlanItem | undefined = undefined;
    for (let index = 0; index < this.generatedPlans.length; index++) {
      if (this.generatedPlans[index].id === planId) {
        targetPlan = this.generatedPlans[index];
        break;
      }
    }

    if (!targetPlan) {
      this.assistantNotice = '没有找到这条训练计划草案，请重新生成一次。';
      return;
    }
    if (targetPlan.imported) {
      this.assistantNotice = '这条训练计划已经导入过了。';
      return;
    }

    let nextPlans: WorkoutPlanItem[] = this.getWorkoutPlans().slice();
    let createdPlan = createWorkoutPlanItem(
      this.normalizePlanDateText(targetPlan.date),
      deserializeExerciseDraft(targetPlan.draftText),
      this.userProfile,
      targetPlan.title,
      targetPlan.notes
    );
    createdPlan.summary = targetPlan.summary.trim().length > 0 ? targetPlan.summary.trim() : createdPlan.summary;
    createdPlan.accentColor = targetPlan.accentColor;
    nextPlans.unshift(createdPlan);
    this.workoutPlanText = serializeWorkoutPlans(nextPlans);
    this.markPlanImported(planId);
    this.assistantNotice = `已导入训练计划「${targetPlan.title}」，现在可以去训练页查看。`;
  }

  private createFoodPlanFromGenerated(item: AiGeneratedFoodPlanItem): FoodPlanItem {
    return {
      id: `${Date.now()}-${Math.round(Math.random() * 1000)}`,
      date: this.normalizePlanDateText(item.date),
      foodId: `ai-food-${item.id}`,
      name: item.name.trim().length > 0 ? item.name.trim() : `${this.getMealLabel(this.normalizeFoodMealType(item.mealType))}推荐`,
      description: item.description.trim().length > 0 ? item.description.trim() : 'AI 为你生成的一条饮食建议。',
      calories: item.calories > 0 ? item.calories : 0,
      serving: item.serving.trim().length > 0 ? item.serving.trim() : '1 份',
      mealType: this.normalizeFoodMealType(item.mealType),
      image: item.image,
      notes: item.notes.trim(),
      accentColor: item.accentColor
    };
  }

  private importGeneratedFoodPlan(planId: string): void {
    let targetPlan: AiGeneratedFoodPlanItem | undefined = undefined;
    for (let index = 0; index < this.generatedFoodPlans.length; index++) {
      if (this.generatedFoodPlans[index].id === planId) {
        targetPlan = this.generatedFoodPlans[index];
        break;
      }
    }

    if (!targetPlan) {
      this.assistantNotice = '没有找到这条饮食计划草案，请重新生成一次。';
      return;
    }
    if (targetPlan.imported) {
      this.assistantNotice = '这条饮食计划已经导入过了。';
      return;
    }

    let nextPlans: FoodPlanItem[] = this.getFoodPlans().slice();
    nextPlans.unshift(this.createFoodPlanFromGenerated(targetPlan));
    this.foodPlanText = serializeFoodPlans(nextPlans);
    this.markFoodPlanImported(planId);
    this.assistantNotice = `已导入食谱「${targetPlan.name}」，现在可以去饮食页查看。`;
  }

  private importAllGeneratedPlans(): void {
    let nextPlans: WorkoutPlanItem[] = this.getWorkoutPlans().slice();
    let importedCount: number = 0;

    for (let index = 0; index < this.generatedPlans.length; index++) {
      let currentPlan = this.generatedPlans[index];
      if (currentPlan.imported) {
        continue;
      }

      let createdPlan = createWorkoutPlanItem(
        this.normalizePlanDateText(currentPlan.date),
        deserializeExerciseDraft(currentPlan.draftText),
        this.userProfile,
        currentPlan.title,
        currentPlan.notes
      );
      createdPlan.summary = currentPlan.summary.trim().length > 0 ? currentPlan.summary.trim() : createdPlan.summary;
      createdPlan.accentColor = currentPlan.accentColor;
      nextPlans.unshift(createdPlan);
      importedCount += 1;
    }

    if (importedCount === 0) {
      this.assistantNotice = '没有新的训练计划需要导入。';
      return;
    }

    this.workoutPlanText = serializeWorkoutPlans(nextPlans);
    let markedPlans: AiGeneratedPlanItem[] = [];
    for (let index = 0; index < this.generatedPlans.length; index++) {
      let currentPlan = this.generatedPlans[index];
      markedPlans.push({
        id: currentPlan.id,
        date: currentPlan.date,
        title: currentPlan.title,
        summary: currentPlan.summary,
        notes: currentPlan.notes,
        draftText: currentPlan.draftText,
        accentColor: currentPlan.accentColor,
        imported: true
      });
    }
    this.generatedPlans = markedPlans;
    this.assistantNotice = `已导入 ${importedCount} 条训练计划草案。`;
  }

  private importAllGeneratedFoodPlans(): void {
    let nextPlans: FoodPlanItem[] = this.getFoodPlans().slice();
    let importedCount: number = 0;

    for (let index = 0; index < this.generatedFoodPlans.length; index++) {
      let currentPlan = this.generatedFoodPlans[index];
      if (currentPlan.imported) {
        continue;
      }
      nextPlans.unshift(this.createFoodPlanFromGenerated(currentPlan));
      importedCount += 1;
    }

    if (importedCount === 0) {
      this.assistantNotice = '没有新的饮食计划需要导入。';
      return;
    }

    this.foodPlanText = serializeFoodPlans(nextPlans);
    let markedPlans: AiGeneratedFoodPlanItem[] = [];
    for (let index = 0; index < this.generatedFoodPlans.length; index++) {
      let currentPlan = this.generatedFoodPlans[index];
      markedPlans.push({
        id: currentPlan.id,
        date: currentPlan.date,
        mealType: currentPlan.mealType,
        name: currentPlan.name,
        description: currentPlan.description,
        calories: currentPlan.calories,
        serving: currentPlan.serving,
        notes: currentPlan.notes,
        image: currentPlan.image,
        accentColor: currentPlan.accentColor,
        imported: true
      });
    }
    this.generatedFoodPlans = markedPlans;
    this.assistantNotice = `已导入 ${importedCount} 条饮食计划草案。`;
  }

  private clearGeneratedPlans(): void {
    this.generatedPlans = [];
    this.assistantNotice = '已清空当前训练计划草案。';
  }

  private clearGeneratedFoodPlans(): void {
    this.generatedFoodPlans = [];
    this.assistantNotice = '已清空当前饮食计划草案。';
  }

  private normalizePlanDateText(dateText: string): string {
    let trimmedDate = dateText.trim();
    let datePattern = /^\d{4}-\d{2}-\d{2}$/;
    if (datePattern.test(trimmedDate)) {
      return trimmedDate;
    }
    return formatDate(new Date());
  }

  private openExerciseTab(): void {
    this.currentTabIndex = EXERCISE_TAB_INDEX;
  }

  private openFoodTab(): void {
    this.currentTabIndex = FOOD_TAB_INDEX;
  }

  @Builder
  buildConfigPanel() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 4 }) {
          Text('模型设置')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text('默认值来自 AiAssistant.ets，保存在本地，方便你直接联调。')
            .fontSize(12)
            .lineHeight(18)
            .fontColor(SECONDARY_TEXT_COLOR)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.hasAiConfig() ? '已配置' : '待配置')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.hasAiConfig() ? '#10B981' : '#FF5A7A')
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(this.hasAiConfig() ? '#ECFFF4' : '#FFF0F6')
          .borderRadius(999)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Button('恢复默认配置')
        .width('100%')
        .height(40)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#0F6BFF')
        .backgroundColor('#EAF2FF')
        .borderRadius(18)
        .onClick(() => {
          this.restoreDefaultAiConfig();
        })

      Column({ space: 8 }) {
        Text('接口地址')
          .fontSize(12)
          .fontColor('#5373A6')

        TextInput({ placeholder: getDefaultAiApiEndpoint(), text: this.aiApiEndpointText })
          .fontSize(15)
          .fontColor(PRIMARY_TEXT_COLOR)
          .height(46)
          .width('100%')
          .padding({ left: 12, right: 12 })
          .backgroundColor('#F5F8FF')
          .borderRadius(16)
          .onChange((value: string) => {
            this.aiApiEndpointText = value;
          })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      Row({ space: 12 }) {
        Column({ space: 8 }) {
          Text('模型')
            .fontSize(12)
            .fontColor('#5373A6')

          TextInput({ placeholder: getDefaultAiModel(), text: this.aiModelText })
            .fontSize(15)
            .fontColor(PRIMARY_TEXT_COLOR)
            .height(46)
            .width('100%')
            .padding({ left: 12, right: 12 })
            .backgroundColor('#F5F8FF')
            .borderRadius(16)
            .onChange((value: string) => {
              this.aiModelText = value;
            })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Column({ space: 8 }) {
          Text('API Key')
            .fontSize(12)
            .fontColor('#5373A6')

          TextInput({ placeholder: getDefaultAiApiKey(), text: this.aiApiKeyText })
            .fontSize(15)
            .fontColor(PRIMARY_TEXT_COLOR)
            .height(46)
            .width('100%')
            .padding({ left: 12, right: 12 })
            .backgroundColor('#F5F8FF')
            .borderRadius(16)
            .onChange((value: string) => {
              this.aiApiKeyText = value;
            })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(18)
    .backgroundColor(SURFACE_BACKGROUND_COLOR)
    .borderRadius(24)
    .border({
      color: '#D8E4F2',
      width: 1
    })
  }

  @Builder
  buildEmptyConversationState() {
    Column({ space: 12 }) {
      Text('开始新对话')
        .fontSize(28)
        .fontWeight(FontWeight.Bolder)
        .fontColor(PRIMARY_TEXT_COLOR)

      Text('直接输入你的问题，或者先用下方的趋势分析、训练计划、定制食谱和全套计划。')
        .fontSize(14)
        .lineHeight(22)
        .fontColor(SECONDARY_TEXT_COLOR)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ top: 80, bottom: 80, left: 20, right: 20 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildConversationFeed() {
    Column({ space: 16 }) {
      ForEach(this.chatMessages, (message: AiChatMessage) => {
        Row() {
          Column({ space: 6 }) {
            Text(this.isAssistantMessage(message) ? 'AI 助手' : this.getUserName())
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.isAssistantMessage(message) ? '#5373A6' : '#98A2B3')

            Text(message.content)
              .fontSize(14)
              .lineHeight(22)
              .fontColor(this.isAssistantMessage(message) ? PRIMARY_TEXT_COLOR : '#FFFFFF')
              .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .width('78%')
          .padding(16)
          .backgroundColor(this.isAssistantMessage(message) ? '#F5F8FF' : '#0F6BFF')
          .borderRadius(24)
          .border({
            color: this.isAssistantMessage(message) ? '#D8E4F2' : '#0F6BFF',
            width: 1
          })
        }
        .width('100%')
        .justifyContent(this.isAssistantMessage(message) ? FlexAlign.Start : FlexAlign.End)
      }, (message: AiChatMessage) => message.id)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  @Builder
  buildGeneratedPlanCard(plan: AiGeneratedPlanItem) {
    Column({ space: 12 }) {
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
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(plan.imported ? '已导入' : '待导入')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(plan.imported ? '#10B981' : '#5373A6')
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor(plan.imported ? '#ECFFF4' : '#EAF2FF')
          .borderRadius(999)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      TextInput({ placeholder: '计划日期 YYYY-MM-DD', text: plan.date })
        .fontSize(14)
        .fontColor(PRIMARY_TEXT_COLOR)
        .height(42)
        .width('100%')
        .padding({ left: 12, right: 12 })
        .backgroundColor('#F5F8FF')
        .borderRadius(14)
        .onChange((value: string) => {
          this.updateGeneratedPlanField(plan.id, 'date', value);
        })

      TextInput({ placeholder: '计划标题', text: plan.title })
        .fontSize(15)
        .fontColor(PRIMARY_TEXT_COLOR)
        .height(42)
        .width('100%')
        .padding({ left: 12, right: 12 })
        .backgroundColor('#F5F8FF')
        .borderRadius(14)
        .onChange((value: string) => {
          this.updateGeneratedPlanField(plan.id, 'title', value);
        })

      TextInput({ placeholder: '备注，可继续补充训练安排', text: plan.notes })
        .fontSize(14)
        .fontColor(PRIMARY_TEXT_COLOR)
        .height(42)
        .width('100%')
        .padding({ left: 12, right: 12 })
        .backgroundColor('#F5F8FF')
        .borderRadius(14)
        .onChange((value: string) => {
          this.updateGeneratedPlanField(plan.id, 'notes', value);
        })

      Row({ space: 10 }) {
        Button(plan.imported ? '已导入' : '导入计划')
          .layoutWeight(1)
          .height(40)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor(plan.imported ? '#98A2B3' : plan.accentColor)
          .borderRadius(16)
          .onClick(() => {
            this.importGeneratedPlan(plan.id);
          })

        Button('打开训练页')
          .width(112)
          .height(40)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#0F6BFF')
          .backgroundColor('#EAF2FF')
          .borderRadius(16)
          .onClick(() => {
            this.openExerciseTab();
          })
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(22)
    .border({
      color: '#D8E4F2',
      width: 1
    })
  }

  @Builder
  buildGeneratedFoodPlanCard(plan: AiGeneratedFoodPlanItem) {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 4 }) {
          Text(plan.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text(plan.description)
            .fontSize(12)
            .lineHeight(18)
            .fontColor(SECONDARY_TEXT_COLOR)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column({ space: 8 }) {
          Text(this.getMealLabel(this.normalizeFoodMealType(plan.mealType)))
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(plan.accentColor)
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor('#FFF7EA')
            .borderRadius(999)

          Text(plan.imported ? '已导入' : '待导入')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(plan.imported ? '#10B981' : '#5373A6')
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor(plan.imported ? '#ECFFF4' : '#EAF2FF')
            .borderRadius(999)
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Row({ space: 10 }) {
        TextInput({ placeholder: '日期 YYYY-MM-DD', text: plan.date })
          .layoutWeight(1)
          .fontSize(14)
          .fontColor(PRIMARY_TEXT_COLOR)
          .height(42)
          .padding({ left: 12, right: 12 })
          .backgroundColor('#F5F8FF')
          .borderRadius(14)
          .onChange((value: string) => {
            this.updateGeneratedFoodPlanField(plan.id, 'date', value);
          })

        TextInput({ placeholder: '餐次 breakfast/lunch/dinner/snack', text: plan.mealType })
          .layoutWeight(1)
          .fontSize(14)
          .fontColor(PRIMARY_TEXT_COLOR)
          .height(42)
          .padding({ left: 12, right: 12 })
          .backgroundColor('#F5F8FF')
          .borderRadius(14)
          .onChange((value: string) => {
            this.updateGeneratedFoodPlanField(plan.id, 'mealType', value);
          })
      }
      .width('100%')

      TextInput({ placeholder: '食谱名称', text: plan.name })
        .fontSize(15)
        .fontColor(PRIMARY_TEXT_COLOR)
        .height(42)
        .width('100%')
        .padding({ left: 12, right: 12 })
        .backgroundColor('#F5F8FF')
        .borderRadius(14)
        .onChange((value: string) => {
          this.updateGeneratedFoodPlanField(plan.id, 'name', value);
        })

      Row({ space: 10 }) {
        TextInput({ placeholder: '份量', text: plan.serving })
          .layoutWeight(1)
          .fontSize(14)
          .fontColor(PRIMARY_TEXT_COLOR)
          .height(42)
          .padding({ left: 12, right: 12 })
          .backgroundColor('#F5F8FF')
          .borderRadius(14)
          .onChange((value: string) => {
            this.updateGeneratedFoodPlanField(plan.id, 'serving', value);
          })

        TextInput({ placeholder: '热量 kcal', text: `${Math.round(plan.calories)}` })
          .width(120)
          .fontSize(14)
          .fontColor(PRIMARY_TEXT_COLOR)
          .height(42)
          .padding({ left: 12, right: 12 })
          .backgroundColor('#F5F8FF')
          .borderRadius(14)
          .onChange((value: string) => {
            this.updateGeneratedFoodPlanField(plan.id, 'calories', value);
          })
      }
      .width('100%')

      TextInput({ placeholder: '备注，可补充烹饪或搭配建议', text: plan.notes })
        .fontSize(14)
        .fontColor(PRIMARY_TEXT_COLOR)
        .height(42)
        .width('100%')
        .padding({ left: 12, right: 12 })
        .backgroundColor('#F5F8FF')
        .borderRadius(14)
        .onChange((value: string) => {
          this.updateGeneratedFoodPlanField(plan.id, 'notes', value);
        })

      Row({ space: 10 }) {
        Button(plan.imported ? '已导入' : '导入食谱')
          .layoutWeight(1)
          .height(40)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor(plan.imported ? '#98A2B3' : plan.accentColor)
          .borderRadius(16)
          .onClick(() => {
            this.importGeneratedFoodPlan(plan.id);
          })

        Button('打开饮食页')
          .width(112)
          .height(40)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#C76B12')
          .backgroundColor('#FFF1D9')
          .borderRadius(16)
          .onClick(() => {
            this.openFoodTab();
          })
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(22)
    .border({
      color: '#F0D9B4',
      width: 1
    })
  }

  @Builder
  buildGeneratedPlansSection() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 4 }) {
          Text('训练计划草案')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text(`${this.generatedPlans.length} 条待处理草案`)
            .fontSize(12)
            .fontColor(SECONDARY_TEXT_COLOR)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Row({ space: 8 }) {
          Button('全部导入')
            .height(34)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .backgroundColor('#0F6BFF')
            .borderRadius(17)
            .onClick(() => {
              this.importAllGeneratedPlans();
            })

          Button('清空')
            .height(34)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#7B61FF')
            .backgroundColor('#F2F0FF')
            .borderRadius(17)
            .onClick(() => {
              this.clearGeneratedPlans();
            })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      ForEach(this.generatedPlans, (plan: AiGeneratedPlanItem) => {
        this.buildGeneratedPlanCard(plan)
      }, (plan: AiGeneratedPlanItem) => plan.id)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(18)
    .backgroundColor(SURFACE_BACKGROUND_COLOR)
    .borderRadius(24)
  }

  @Builder
  buildGeneratedFoodPlansSection() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 4 }) {
          Text('饮食计划草案')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text(`${this.generatedFoodPlans.length} 条待处理草案`)
            .fontSize(12)
            .fontColor(SECONDARY_TEXT_COLOR)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Row({ space: 8 }) {
          Button('全部导入')
            .height(34)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .backgroundColor('#D97706')
            .borderRadius(17)
            .onClick(() => {
              this.importAllGeneratedFoodPlans();
            })

          Button('清空')
            .height(34)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#C76B12')
            .backgroundColor('#FFF1D9')
            .borderRadius(17)
            .onClick(() => {
              this.clearGeneratedFoodPlans();
            })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      ForEach(this.generatedFoodPlans, (plan: AiGeneratedFoodPlanItem) => {
        this.buildGeneratedFoodPlanCard(plan)
      }, (plan: AiGeneratedFoodPlanItem) => plan.id)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(18)
    .backgroundColor('#FFFDFC')
    .borderRadius(24)
    .border({
      color: '#F5E6CF',
      width: 1
    })
  }

  @Builder
  buildQuickActionRow(actions: AssistantQuickActionItem[]) {
    Row({ space: 10 }) {
      ForEach(actions, (item: AssistantQuickActionItem) => {
        Button(item.label)
          .layoutWeight(1)
          .height(40)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(PRIMARY_TEXT_COLOR)
          .backgroundColor(this.getQuickActionBackgroundColor(item.id))
          .borderRadius(18)
          .border({
            color: this.getQuickActionBorderColor(item.id),
            width: 1
          })
          .onClick(() => {
            this.handleQuickAction(item.id);
          })
      }, (item: AssistantQuickActionItem) => item.id)
    }
    .width('100%')
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        Image($r('sys.media.ohos_ic_back'))
          .width(22)
          .height(22)
          .margin({ right: 12 })
          .onClick(() => {
            this.currentTabIndex = HOME_TAB_INDEX;
          })

        Column({ space: 4 }) {
          Text('AI 助手')
            .fontSize(24)
            .fontWeight(FontWeight.Bolder)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text(this.assistantBusy ? 'AI 正在生成内容' : '开始一段新对话')
            .fontSize(12)
            .fontColor(SECONDARY_TEXT_COLOR)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Row({ space: 8 }) {
          Button('配置')
            .height(34)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#0F6BFF')
            .backgroundColor(this.showConfigPanel ? '#DCEBFF' : '#EAF2FF')
            .borderRadius(17)
            .padding({ left: 14, right: 14 })
            .onClick(() => {
              this.toggleConfigPanel();
            })

          Button('新建')
            .height(34)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#0F6BFF')
            .backgroundColor('#F5F8FF')
            .borderRadius(17)
            .padding({ left: 14, right: 14 })
            .onClick(() => {
              this.resetConversation();
            })
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 18, bottom: 10 })
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Column({ space: 18 }) {
          if (this.showConfigPanel) {
            this.buildConfigPanel()
          }

          if (this.hasOnlyWelcomeMessage() && !this.showConfigPanel) {
            this.buildEmptyConversationState()
          } else {
            this.buildConversationFeed()
          }

          if (this.generatedPlans.length > 0) {
            this.buildGeneratedPlansSection()
          }

          if (this.generatedFoodPlans.length > 0) {
            this.buildGeneratedFoodPlansSection()
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 8, bottom: 18 })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
      .friction(0.6)
      .backgroundColor('#FFFFFF')

      Column({ space: 10 }) {
        Text(this.getAssistantStatusText())
          .fontSize(12)
          .lineHeight(18)
          .fontColor(SECONDARY_TEXT_COLOR)
          .width('100%')

        Column({ space: 10 }) {
          this.buildQuickActionRow(ASSISTANT_PRIMARY_ACTIONS)
          this.buildQuickActionRow(ASSISTANT_SECONDARY_ACTIONS)
        }
        .width('100%')

        Row({ space: 8 }) {
          TextInput({ placeholder: '给 AI 发送消息...', text: this.questionInput })
            .layoutWeight(1)
            .height(44)
            .fontSize(15)
            .fontColor(PRIMARY_TEXT_COLOR)
            .padding({ left: 8, right: 8 })
            .backgroundColor('#00000000')
            .onChange((value: string) => {
              this.questionInput = value;
            })

          Button('+')
            .width(36)
            .height(36)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F6BFF')
            .backgroundColor('#EAF2FF')
            .borderRadius(18)
            .onClick(() => {
              this.toggleConfigPanel();
            })

          Button('发')
            .width(36)
            .height(36)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.questionInput.trim().length > 0 ? '#FFFFFF' : '#98A2B3')
            .backgroundColor(this.questionInput.trim().length > 0 ? '#0F6BFF' : '#F3F6FB')
            .borderRadius(18)
            .onClick(() => {
              if (this.questionInput.trim().length === 0) {
                return;
              }
              this.sendFreeQuestion();
            })
        }
        .width('100%')
        .padding({ left: 12, right: 8, top: 4, bottom: 4 })
        .backgroundColor('#FFFFFF')
        .borderRadius(22)
        .border({
          color: '#D8E4F2',
          width: 1
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 10, bottom: 16 })
      .backgroundColor('#FFFFFF')
      .border({
        color: '#D8E4F2',
        width: {
          top: 1
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
