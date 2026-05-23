import {
  PRIMARY_TEXT_COLOR,
  SECONDARY_TEXT_COLOR,
  SURFACE_BACKGROUND_COLOR
} from '../../constants/AppTheme';
import {
  AI_MESSAGE_STATUS_CANCELLED,
  AI_MESSAGE_STATUS_DONE,
  AI_MESSAGE_STATUS_ERROR,
  AI_MESSAGE_STATUS_THINKING,
  AI_ROLE_ASSISTANT,
  AI_ROLE_USER,
  AI_TASK_ANALYZE_WEIGHT,
  AI_TASK_CHAT,
  AI_TASK_DAILY_BRIEFING,
  AI_TASK_GENERATE_FULL_PLAN,
  AI_TASK_GENERATE_PLAN,
  AI_TASK_GENERATE_RECIPE,
  AiAssistantConfig,
  AiAssistantResponse,
  AiChatMessage,
  AiConversationRecord,
  AiGeneratedFoodPlanItem,
  AiGeneratedPlanItem,
  cloneAiChatMessage,
  createAiConversationRecord,
  createAiChatMessage,
  deserializeAiConversationHistory,
  getDefaultAiApiEndpoint,
  getDefaultAiApiKey,
  getDefaultAiModel,
  serializeAiConversationHistory
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
import { inferAiAssistantTaskFromPrompt, requestAiAssistant } from '../../utils/AiAssistantHelper';
import { buildDailyBriefingAiPrompt, buildDailyBriefingSummary } from '../../utils/DailyBriefingHelper';
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
  '我是智卡管家，可以结合你的体重、饮食和训练记录，解读今日状态并生成可执行计划。';
const ASSISTANT_DEFAULT_NOTICE: string = '可以直接发消息，也可以先点下面的管家快捷功能。';
const ASSISTANT_QUICK_ACTIONS: AssistantQuickActionItem[] = [
  { id: 'today', label: '今日解读' },
  { id: 'analyze', label: '体重趋势' },
  { id: 'plan', label: '训练安排' },
  { id: 'recipe', label: '饮食调整' },
  { id: 'full', label: '一周方案' }
];
const HISTORY_RESULT_LIMIT: number = 20;

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
  @StorageLink('aiConversationHistoryText') aiConversationHistoryText: string = '';

  @State questionInput: string = '';
  @State historyQuery: string = '';
  @State assistantBusy: boolean = false;
  @State assistantNotice: string = ASSISTANT_DEFAULT_NOTICE;
  @State chatMessages: AiChatMessage[] = [];
  @State chatMessagesRenderVersion: number = 0;
  @State conversationHistory: AiConversationRecord[] = [];
  @State activeConversationId: string = '';
  @State showConfigPanel: boolean = false;
  @State showHistoryPanel: boolean = false;

  private activeRequestToken: number = 0;
  private pendingAssistantMessageId: string = '';
  private cancelCurrentRequest?: () => void;

  aboutToAppear(): void {
    this.ensureDefaultAiConfig();
    this.loadConversationHistory();
    if (this.conversationHistory.length > 0) {
      this.openConversation(this.conversationHistory[0].id);
    } else if (this.chatMessages.length === 0) {
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
    if (this.assistantBusy) {
      this.interruptAssistantRequest('已中断当前请求，并开始一段新对话。');
    }
    this.questionInput = '';
    this.historyQuery = '';
    this.assistantBusy = false;
    this.activeConversationId = createAiConversationRecord().id;
    this.pendingAssistantMessageId = '';
    this.cancelCurrentRequest = undefined;
    this.chatMessages = [
      createAiChatMessage(AI_ROLE_ASSISTANT, ASSISTANT_WELCOME_MESSAGE)
    ];
    this.assistantNotice = ASSISTANT_DEFAULT_NOTICE;
    this.saveConversationSnapshot();
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
      return '智卡管家正在整理建议。发送按钮已切换为中断按钮。';
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
    if (this.showConfigPanel) {
      this.showHistoryPanel = false;
    }
  }

  private toggleHistoryPanel(): void {
    this.showHistoryPanel = !this.showHistoryPanel;
    if (this.showHistoryPanel) {
      this.showConfigPanel = false;
    }
  }

  private updateChatMessages(nextMessages: AiChatMessage[], refreshVisibleMessages: boolean = false): void {
    this.chatMessages = nextMessages;
    if (refreshVisibleMessages) {
      this.chatMessagesRenderVersion += 1;
    }
    this.saveConversationSnapshot();
  }

  private loadConversationHistory(): void {
    this.conversationHistory = deserializeAiConversationHistory(this.aiConversationHistoryText);
  }

  private cloneMessages(messages: AiChatMessage[]): AiChatMessage[] {
    let result: AiChatMessage[] = [];
    for (let index = 0; index < messages.length; index++) {
      result.push(cloneAiChatMessage(messages[index]));
    }
    return result;
  }

  private buildConversationTitle(messages: AiChatMessage[]): string {
    for (let index = 0; index < messages.length; index++) {
      let currentMessage = messages[index];
      if (currentMessage.role !== AI_ROLE_USER) {
        continue;
      }
      let trimmedContent = currentMessage.content.trim();
      if (trimmedContent.length === 0) {
        continue;
      }
      if (trimmedContent.length <= 18) {
        return trimmedContent;
      }
      return `${trimmedContent.substring(0, 18)}...`;
    }
    return '新对话';
  }

  private saveConversationSnapshot(): void {
    if (this.activeConversationId.trim().length === 0) {
      this.activeConversationId = createAiConversationRecord().id;
    }

    let createdAt: number = Date.now();
    let nextHistory: AiConversationRecord[] = [];
    for (let index = 0; index < this.conversationHistory.length; index++) {
      let currentRecord = this.conversationHistory[index];
      if (currentRecord.id !== this.activeConversationId) {
        nextHistory.push(currentRecord);
        continue;
      }
      createdAt = currentRecord.createdAt;
    }

    nextHistory.push({
      id: this.activeConversationId,
      title: this.buildConversationTitle(this.chatMessages),
      createdAt: createdAt,
      updatedAt: Date.now(),
      messages: this.cloneMessages(this.chatMessages)
    });
    nextHistory.sort((left: AiConversationRecord, right: AiConversationRecord) => right.updatedAt - left.updatedAt);
    this.conversationHistory = nextHistory;
    this.aiConversationHistoryText = serializeAiConversationHistory(nextHistory);
  }

  private getConversationPreview(record: AiConversationRecord): string {
    for (let index = record.messages.length - 1; index >= 0; index--) {
      let currentMessage = record.messages[index];
      let trimmedContent = currentMessage.content.trim();
      if (trimmedContent.length > 0) {
        return trimmedContent;
      }
      let trimmedThinking = currentMessage.thinkingContent.trim();
      if (trimmedThinking.length > 0) {
        return trimmedThinking;
      }
    }
    return '暂无消息内容';
  }

  private formatHistoryTime(timestamp: number): string {
    let date = new Date(timestamp);
    let month = `${date.getMonth() + 1}`.padStart(2, '0');
    let day = `${date.getDate()}`.padStart(2, '0');
    let hour = `${date.getHours()}`.padStart(2, '0');
    let minute = `${date.getMinutes()}`.padStart(2, '0');
    return `${month}-${day} ${hour}:${minute}`;
  }

  private getFilteredConversationHistory(): AiConversationRecord[] {
    let normalizedQuery = this.historyQuery.trim().toLowerCase();
    let result: AiConversationRecord[] = [];
    for (let index = 0; index < this.conversationHistory.length; index++) {
      let currentRecord = this.conversationHistory[index];
      if (normalizedQuery.length === 0) {
        result.push(currentRecord);
      } else {
        let titleText = currentRecord.title.toLowerCase();
        let previewText = this.getConversationPreview(currentRecord).toLowerCase();
        let contentMatched: boolean = false;
        for (let messageIndex = 0; messageIndex < currentRecord.messages.length; messageIndex++) {
          let currentMessage = currentRecord.messages[messageIndex];
          let searchableText = `${currentMessage.content} ${currentMessage.thinkingContent}`.toLowerCase();
          if (searchableText.indexOf(normalizedQuery) >= 0) {
            contentMatched = true;
            break;
          }
        }
        if (titleText.indexOf(normalizedQuery) >= 0 || previewText.indexOf(normalizedQuery) >= 0 || contentMatched) {
          result.push(currentRecord);
        }
      }
      if (result.length >= HISTORY_RESULT_LIMIT) {
        break;
      }
    }
    return result;
  }

  private openConversation(recordId: string): void {
    for (let index = 0; index < this.conversationHistory.length; index++) {
      let currentRecord = this.conversationHistory[index];
      if (currentRecord.id !== recordId) {
        continue;
      }

      if (this.assistantBusy) {
        this.interruptAssistantRequest('已中断当前请求，并切换到历史对话。');
      }
      this.activeConversationId = currentRecord.id;
      this.chatMessages = this.cloneMessages(currentRecord.messages);
      this.pendingAssistantMessageId = '';
      this.assistantBusy = false;
      this.showHistoryPanel = false;
      this.assistantNotice = `已载入 ${this.formatHistoryTime(currentRecord.updatedAt)} 的对话记录。`;
      return;
    }
  }

  private updateAssistantMessage(messageId: string, content: string, thinkingContent: string, status: string): void {
    let nextMessages: AiChatMessage[] = [];
    let matched: boolean = false;
    for (let index = 0; index < this.chatMessages.length; index++) {
      let currentMessage = this.chatMessages[index];
      if (currentMessage.id !== messageId) {
        nextMessages.push(cloneAiChatMessage(currentMessage));
        continue;
      }
      matched = true;
      let nextMessage = cloneAiChatMessage(currentMessage);
      nextMessage.role = AI_ROLE_ASSISTANT;
      nextMessage.content = content;
      nextMessage.thinkingContent = thinkingContent;
      nextMessage.status = status;
      nextMessages.push(nextMessage);
    }
    if (!matched) {
      nextMessages.push(createAiChatMessage(AI_ROLE_ASSISTANT, content, thinkingContent, status));
    }
    this.updateChatMessages(nextMessages, true);
  }

  private interruptAssistantRequest(noticeText: string = '已中断当前请求。'): void {
    if (this.cancelCurrentRequest) {
      this.cancelCurrentRequest();
    }
    if (this.pendingAssistantMessageId.trim().length > 0) {
      this.updateAssistantMessage(
        this.pendingAssistantMessageId,
        '这次请求已中断。',
        '已停止继续生成。你可以修改问题后重新发送。',
        AI_MESSAGE_STATUS_CANCELLED
      );
    }
    this.cancelCurrentRequest = undefined;
    this.pendingAssistantMessageId = '';
    this.assistantBusy = false;
    this.assistantNotice = noticeText;
  }

  private finishAssistantRequestIfActive(requestToken: number): void {
    if (this.activeRequestToken !== requestToken) {
      return;
    }
    this.assistantBusy = false;
    this.pendingAssistantMessageId = '';
    this.cancelCurrentRequest = undefined;
  }

  private getTaskLoadingNotice(task: string): string {
    if (task === AI_TASK_DAILY_BRIEFING) {
      return '正在解读今日健康计划...';
    }
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

  private getTaskThinkingHint(task: string): string {
    if (task === AI_TASK_DAILY_BRIEFING) {
      return '智卡管家正在综合今天的热量、训练和体重趋势。';
    }
    if (task === AI_TASK_GENERATE_PLAN) {
      return '智卡管家正在整理训练安排与强度节奏。';
    }
    if (task === AI_TASK_GENERATE_RECIPE) {
      return '智卡管家正在匹配餐次、热量与食材建议。';
    }
    if (task === AI_TASK_GENERATE_FULL_PLAN) {
      return '智卡管家正在同时协调训练与饮食计划。';
    }
    return '智卡管家正在理解问题并整理答复。';
  }

  private buildGeneratedResultNotice(task: string, workoutCount: number, foodCount: number): string {
    if (task === AI_TASK_DAILY_BRIEFING) {
      return '今日计划解读已更新。';
    }
    if (workoutCount > 0 && foodCount > 0) {
      return `智卡管家已生成 ${workoutCount} 条训练计划和 ${foodCount} 条饮食计划草案。`;
    }
    if (workoutCount > 0) {
      return `智卡管家已生成 ${workoutCount} 条训练计划草案，你可以先调整再导入。`;
    }
    if (foodCount > 0) {
      return `智卡管家已生成 ${foodCount} 条饮食计划草案，你可以先调整再导入。`;
    }
    if (task === AI_TASK_GENERATE_PLAN) {
      return '智卡管家这次没有返回可导入训练计划，可以换个问法再试一次。';
    }
    if (task === AI_TASK_GENERATE_RECIPE) {
      return '智卡管家这次没有返回可导入食谱，可以换个口味或目标再试一次。';
    }
    if (task === AI_TASK_GENERATE_FULL_PLAN) {
      return '智卡管家这次没有返回完整计划，可以补充更多需求后再试一次。';
    }
    return '智卡建议已更新。';
  }

  private buildAssistantVisibleReply(task: string, response: AiAssistantResponse): string {
    let trimmedResponse = response.reply.trim();
    if (trimmedResponse.length > 0) {
      return trimmedResponse;
    }
    if (!response.parseSucceeded && task === AI_TASK_CHAT) {
      return 'AI 返回了计划草案数据，但格式不完整。请直接说“帮我制定训练计划”或“帮我制定饮食计划”后重试。';
    }
    return this.buildGeneratedResultNotice(task, response.plans.length, response.foodPlans.length);
  }

  private buildAssistantErrorReply(errorText: string): string {
    let trimmedError = errorText.trim();
    if (trimmedError.length === 0) {
      return 'AI 请求失败，请检查网络、模型名和 API Key。';
    }
    return trimmedError;
  }

  private applyAssistantResponse(messageId: string, task: string, workoutPlans: AiGeneratedPlanItem[],
    foodPlans: AiGeneratedFoodPlanItem[]): void {
    let nextMessages: AiChatMessage[] = [];
    for (let index = 0; index < this.chatMessages.length; index++) {
      let currentMessage = this.chatMessages[index];
      if (currentMessage.id !== messageId) {
        nextMessages.push(cloneAiChatMessage(currentMessage));
        continue;
      }

      let nextMessage = cloneAiChatMessage(currentMessage);
      if (task === AI_TASK_GENERATE_PLAN) {
        nextMessage.generatedPlans = workoutPlans;
        nextMessage.generatedFoodPlans = [];
      } else if (task === AI_TASK_GENERATE_RECIPE) {
        nextMessage.generatedPlans = [];
        nextMessage.generatedFoodPlans = foodPlans;
      } else if (task === AI_TASK_GENERATE_FULL_PLAN) {
        nextMessage.generatedPlans = workoutPlans;
        nextMessage.generatedFoodPlans = foodPlans;
      } else {
        nextMessage.generatedPlans = workoutPlans;
        nextMessage.generatedFoodPlans = foodPlans;
      }
      nextMessages.push(nextMessage);
    }
    this.updateChatMessages(nextMessages, true);
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

    let nextMessages: AiChatMessage[] = this.chatMessages.slice();
    let userMessage: AiChatMessage = createAiChatMessage(AI_ROLE_USER, trimmedPrompt);
    let pendingMessage: AiChatMessage = createAiChatMessage(
      AI_ROLE_ASSISTANT,
      '',
      this.getTaskThinkingHint(task),
      AI_MESSAGE_STATUS_THINKING
    );
    nextMessages.push(userMessage);
    nextMessages.push(pendingMessage);
    this.updateChatMessages(nextMessages, true);
    this.questionInput = '';
    this.assistantBusy = true;
    this.assistantNotice = this.getTaskLoadingNotice(task);
    this.pendingAssistantMessageId = pendingMessage.id;
    this.activeRequestToken += 1;
    let requestToken: number = this.activeRequestToken;
    let requestHistoryMessages: AiChatMessage[] = nextMessages.slice(0, nextMessages.length - 1);

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
        historyMessages: requestHistoryMessages
      }, {
        onRequestCreated: (cancelHandler: () => void) => {
          if (this.activeRequestToken !== requestToken) {
            cancelHandler();
            return;
          }
          this.cancelCurrentRequest = cancelHandler;
        }
      });

      if (this.activeRequestToken !== requestToken) {
        return;
      }
      let visibleReply = this.buildAssistantVisibleReply(task, response);
      this.finishAssistantRequestIfActive(requestToken);
      this.updateAssistantMessage(
        pendingMessage.id,
        visibleReply,
        response.reasoningContent.trim(),
        AI_MESSAGE_STATUS_DONE
      );
      this.applyAssistantResponse(pendingMessage.id, task, response.plans, response.foodPlans);
      this.assistantNotice = this.buildGeneratedResultNotice(task, response.plans.length, response.foodPlans.length);
    } catch (error) {
      if (this.activeRequestToken !== requestToken) {
        return;
      }
      let errorText = `${error}`;
      if (errorText.trim().length === 0 || errorText === '[object Object]') {
        errorText = 'AI 请求失败，请检查网络、模型名和 API Key。';
      }
      let messageStatus: string = AI_MESSAGE_STATUS_ERROR;
      let messageThinking: string = '';
      let messageContent: string = this.buildAssistantErrorReply(errorText);
      if (errorText.indexOf('请求已中断') >= 0) {
        messageStatus = AI_MESSAGE_STATUS_CANCELLED;
        messageContent = '这次请求已中断。';
      }
      this.finishAssistantRequestIfActive(requestToken);
      this.updateAssistantMessage(pendingMessage.id, messageContent, messageThinking, messageStatus);
      this.assistantNotice = errorText;
    } finally {
      this.finishAssistantRequestIfActive(requestToken);
    }
  }

  private askAboutWeightTrend(): void {
    this.submitToAssistant(
      AI_TASK_ANALYZE_WEIGHT,
      `请结合${this.getUserName()}最近的体重变化，告诉我最近需要注意什么，并给出 3 条以内的训练和饮食建议。`
    );
  }

  private askAboutTodayBriefing(): void {
    let summary = buildDailyBriefingSummary(
      this.foodPlanText,
      this.workoutPlanText,
      this.workoutRecordText,
      this.weightRecordText,
      this.dailyFoodCalorieTargetText,
      formatDate(new Date())
    );
    this.submitToAssistant(AI_TASK_DAILY_BRIEFING, buildDailyBriefingAiPrompt(summary));
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
    this.submitToAssistant(inferAiAssistantTaskFromPrompt(this.questionInput), this.questionInput);
  }

  private handleQuickAction(actionId: string): void {
    if (actionId === 'today') {
      this.askAboutTodayBriefing();
      return;
    }
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
    if (actionId === 'today') {
      return '#EAF2FF';
    }
    if (actionId === 'plan' && this.getGeneratedPlanCount() > 0) {
      return '#F2F0FF';
    }
    if (actionId === 'recipe' && this.getGeneratedFoodPlanCount() > 0) {
      return '#FFF6E8';
    }
    if (actionId === 'full' && (this.getGeneratedPlanCount() > 0 || this.getGeneratedFoodPlanCount() > 0)) {
      return '#ECFFF4';
    }
    if (actionId === 'analyze') {
      return '#EAF2FF';
    }
    return '#F7FAFF';
  }

  private getQuickActionBorderColor(actionId: string): string {
    if (actionId === 'today') {
      return '#B7D5FF';
    }
    if (actionId === 'plan' && this.getGeneratedPlanCount() > 0) {
      return '#D7CCFF';
    }
    if (actionId === 'recipe' && this.getGeneratedFoodPlanCount() > 0) {
      return '#F5D8A8';
    }
    if (actionId === 'full' && (this.getGeneratedPlanCount() > 0 || this.getGeneratedFoodPlanCount() > 0)) {
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

  private getGeneratedPlanCount(): number {
    let count: number = 0;
    for (let index = 0; index < this.chatMessages.length; index++) {
      count += this.chatMessages[index].generatedPlans.length;
    }
    return count;
  }

  private getGeneratedFoodPlanCount(): number {
    let count: number = 0;
    for (let index = 0; index < this.chatMessages.length; index++) {
      count += this.chatMessages[index].generatedFoodPlans.length;
    }
    return count;
  }

  private getMessageGeneratedPlans(message: AiChatMessage): AiGeneratedPlanItem[] {
    return message.generatedPlans;
  }

  private getMessageGeneratedFoodPlans(message: AiChatMessage): AiGeneratedFoodPlanItem[] {
    return message.generatedFoodPlans;
  }

  private findChatMessage(messageId: string): AiChatMessage | undefined {
    for (let index = 0; index < this.chatMessages.length; index++) {
      if (this.chatMessages[index].id === messageId) {
        return this.chatMessages[index];
      }
    }
    return undefined;
  }

  private updateMessageGeneratedDrafts(messageId: string, generatedPlans?: AiGeneratedPlanItem[],
    generatedFoodPlans?: AiGeneratedFoodPlanItem[], refreshVisibleMessages: boolean = false): void {
    let nextMessages: AiChatMessage[] = [];
    for (let index = 0; index < this.chatMessages.length; index++) {
      let currentMessage = this.chatMessages[index];
      if (currentMessage.id !== messageId) {
        nextMessages.push(cloneAiChatMessage(currentMessage));
        continue;
      }

      let nextMessage = cloneAiChatMessage(currentMessage);
      if (generatedPlans !== undefined) {
        nextMessage.generatedPlans = generatedPlans;
      }
      if (generatedFoodPlans !== undefined) {
        nextMessage.generatedFoodPlans = generatedFoodPlans;
      }
      nextMessages.push(nextMessage);
    }
    this.updateChatMessages(nextMessages, refreshVisibleMessages);
  }

  private updateGeneratedPlanField(messageId: string, planId: string, field: string, value: string): void {
    let targetMessage = this.findChatMessage(messageId);
    if (!targetMessage) {
      return;
    }

    let nextPlans: AiGeneratedPlanItem[] = [];
    for (let index = 0; index < targetMessage.generatedPlans.length; index++) {
      let currentPlan = targetMessage.generatedPlans[index];
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
    this.updateMessageGeneratedDrafts(messageId, nextPlans, undefined);
  }

  private updateGeneratedFoodPlanField(messageId: string, planId: string, field: string, value: string): void {
    let targetMessage = this.findChatMessage(messageId);
    if (!targetMessage) {
      return;
    }

    let nextPlans: AiGeneratedFoodPlanItem[] = [];
    for (let index = 0; index < targetMessage.generatedFoodPlans.length; index++) {
      let currentPlan = targetMessage.generatedFoodPlans[index];
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
    this.updateMessageGeneratedDrafts(messageId, undefined, nextPlans);
  }

  private markPlanImported(messageId: string, planId: string): void {
    let targetMessage = this.findChatMessage(messageId);
    if (!targetMessage) {
      return;
    }

    let nextPlans: AiGeneratedPlanItem[] = [];
    for (let index = 0; index < targetMessage.generatedPlans.length; index++) {
      let currentPlan = targetMessage.generatedPlans[index];
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
    this.updateMessageGeneratedDrafts(messageId, nextPlans, undefined, true);
  }

  private markFoodPlanImported(messageId: string, planId: string): void {
    let targetMessage = this.findChatMessage(messageId);
    if (!targetMessage) {
      return;
    }

    let nextPlans: AiGeneratedFoodPlanItem[] = [];
    for (let index = 0; index < targetMessage.generatedFoodPlans.length; index++) {
      let currentPlan = targetMessage.generatedFoodPlans[index];
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
    this.updateMessageGeneratedDrafts(messageId, undefined, nextPlans, true);
  }

  private importGeneratedPlan(messageId: string, planId: string): void {
    let targetMessage = this.findChatMessage(messageId);
    if (!targetMessage) {
      this.assistantNotice = '没有找到这条训练计划草案，请重新生成一次。';
      return;
    }

    let targetPlan: AiGeneratedPlanItem | undefined = undefined;
    for (let index = 0; index < targetMessage.generatedPlans.length; index++) {
      if (targetMessage.generatedPlans[index].id === planId) {
        targetPlan = targetMessage.generatedPlans[index];
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
    this.markPlanImported(messageId, planId);
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

  private importGeneratedFoodPlan(messageId: string, planId: string): void {
    let targetMessage = this.findChatMessage(messageId);
    if (!targetMessage) {
      this.assistantNotice = '没有找到这条饮食计划草案，请重新生成一次。';
      return;
    }

    let targetPlan: AiGeneratedFoodPlanItem | undefined = undefined;
    for (let index = 0; index < targetMessage.generatedFoodPlans.length; index++) {
      if (targetMessage.generatedFoodPlans[index].id === planId) {
        targetPlan = targetMessage.generatedFoodPlans[index];
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
    this.markFoodPlanImported(messageId, planId);
    this.assistantNotice = `已导入食谱「${targetPlan.name}」，现在可以去饮食页查看。`;
  }

  private importAllGeneratedPlans(messageId: string): void {
    let targetMessage = this.findChatMessage(messageId);
    if (!targetMessage) {
      this.assistantNotice = '没有找到这组训练计划草案，请重新生成一次。';
      return;
    }

    let nextPlans: WorkoutPlanItem[] = this.getWorkoutPlans().slice();
    let importedCount: number = 0;

    for (let index = 0; index < targetMessage.generatedPlans.length; index++) {
      let currentPlan = targetMessage.generatedPlans[index];
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
    for (let index = 0; index < targetMessage.generatedPlans.length; index++) {
      let currentPlan = targetMessage.generatedPlans[index];
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
    this.updateMessageGeneratedDrafts(messageId, markedPlans, undefined, true);
    this.assistantNotice = `已导入 ${importedCount} 条训练计划草案。`;
  }

  private importAllGeneratedFoodPlans(messageId: string): void {
    let targetMessage = this.findChatMessage(messageId);
    if (!targetMessage) {
      this.assistantNotice = '没有找到这组饮食计划草案，请重新生成一次。';
      return;
    }

    let nextPlans: FoodPlanItem[] = this.getFoodPlans().slice();
    let importedCount: number = 0;

    for (let index = 0; index < targetMessage.generatedFoodPlans.length; index++) {
      let currentPlan = targetMessage.generatedFoodPlans[index];
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
    for (let index = 0; index < targetMessage.generatedFoodPlans.length; index++) {
      let currentPlan = targetMessage.generatedFoodPlans[index];
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
    this.updateMessageGeneratedDrafts(messageId, undefined, markedPlans, true);
    this.assistantNotice = `已导入 ${importedCount} 条饮食计划草案。`;
  }

  private clearGeneratedPlans(messageId: string): void {
    this.updateMessageGeneratedDrafts(messageId, [], undefined, true);
    this.assistantNotice = '已清空当前训练计划草案。';
  }

  private clearGeneratedFoodPlans(messageId: string): void {
    this.updateMessageGeneratedDrafts(messageId, undefined, [], true);
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

  private hasMessageThinkingContent(message: AiChatMessage): boolean {
    return message.thinkingContent.trim().length > 0;
  }

  private getChatMessageRenderKey(message: AiChatMessage): string {
    return `${message.id}-${this.chatMessagesRenderVersion}`;
  }

  private getAssistantMessageStatusLabel(message: AiChatMessage): string {
    if (message.status === AI_MESSAGE_STATUS_THINKING) {
      return '思考中';
    }
    if (message.status === AI_MESSAGE_STATUS_CANCELLED) {
      return '已中断';
    }
    if (message.status === AI_MESSAGE_STATUS_ERROR) {
      return '失败';
    }
    return '已完成';
  }

  private getAssistantMessageStatusColor(message: AiChatMessage): string {
    if (message.status === AI_MESSAGE_STATUS_THINKING) {
      return '#0F6BFF';
    }
    if (message.status === AI_MESSAGE_STATUS_CANCELLED) {
      return '#C76B12';
    }
    if (message.status === AI_MESSAGE_STATUS_ERROR) {
      return '#D14343';
    }
    return '#5373A6';
  }

  private getAssistantDetailLabel(message: AiChatMessage): string {
    if (message.status === AI_MESSAGE_STATUS_THINKING) {
      return '管家思考中';
    }
    if (message.status === AI_MESSAGE_STATUS_ERROR) {
      return '错误信息';
    }
    if (message.status === AI_MESSAGE_STATUS_CANCELLED) {
      return '中断信息';
    }
    return '本次推理';
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

          TextInput({ placeholder: '请输入 SiliconFlow API Key', text: this.aiApiKeyText })
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

      Text('IndexTTS2 语音播报使用代码层固定地址，当前页面不提供 TTS IP 修改入口。')
        .fontSize(12)
        .lineHeight(18)
        .fontColor(SECONDARY_TEXT_COLOR)
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
  buildHistoryPanel() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 4 }) {
          Text('聊天记录')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text(`最近 ${Math.min(this.conversationHistory.length, HISTORY_RESULT_LIMIT)} 条会话，可按标题或内容筛选`)
            .fontSize(12)
            .fontColor(SECONDARY_TEXT_COLOR)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button('收起')
          .height(32)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#5373A6')
          .backgroundColor('#F5F8FF')
          .borderRadius(16)
          .padding({ left: 14, right: 14 })
          .onClick(() => {
            this.showHistoryPanel = false;
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      TextInput({ placeholder: '搜索聊天标题或最后一条消息...', text: this.historyQuery })
        .fontSize(14)
        .fontColor(PRIMARY_TEXT_COLOR)
        .height(42)
        .width('100%')
        .padding({ left: 12, right: 12 })
        .backgroundColor('#F5F8FF')
        .borderRadius(14)
        .onChange((value: string) => {
          this.historyQuery = value;
        })

      if (this.getFilteredConversationHistory().length === 0) {
        Text('还没有匹配到聊天记录。')
          .fontSize(13)
          .fontColor(SECONDARY_TEXT_COLOR)
          .width('100%')
      } else {
        Column({ space: 10 }) {
          ForEach(this.getFilteredConversationHistory(), (record: AiConversationRecord) => {
            Button() {
              Column({ space: 6 }) {
                Row() {
                  Text(record.title)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(PRIMARY_TEXT_COLOR)
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  Text(this.formatHistoryTime(record.updatedAt))
                    .fontSize(11)
                    .fontColor('#5373A6')
                }
                .width('100%')

                Text(this.getConversationPreview(record))
                  .fontSize(12)
                  .lineHeight(18)
                  .fontColor(SECONDARY_TEXT_COLOR)
                  .width('100%')
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text(`${record.messages.length} 条消息`)
                  .fontSize(11)
                  .fontColor('#98A2B3')
                  .width('100%')
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding(14)
            }
            .width('100%')
            .backgroundColor(record.id === this.activeConversationId ? '#EAF2FF' : '#FFFFFF')
            .borderRadius(18)
            .border({
              color: record.id === this.activeConversationId ? '#BFD6FF' : '#D8E4F2',
              width: 1
            })
            .onClick(() => {
              this.openConversation(record.id);
            })
          }, (record: AiConversationRecord) => record.id)
        }
        .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFFFF')
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

      Text('直接输入你的问题，或者先用下方的今日解读、体重趋势、训练安排和饮食调整。')
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
            Row() {
              Text(this.isAssistantMessage(message) ? '智卡管家' : this.getUserName())
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.isAssistantMessage(message) ? '#5373A6' : '#98A2B3')

              if (this.isAssistantMessage(message)) {
                Text(this.getAssistantMessageStatusLabel(message))
                  .fontSize(10)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.getAssistantMessageStatusColor(message))
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .backgroundColor('#FFFFFF')
                  .borderRadius(999)
              }
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
            .alignItems(VerticalAlign.Center)

            if (this.isAssistantMessage(message) && this.hasMessageThinkingContent(message)) {
              Column({ space: 6 }) {
                Text(this.getAssistantDetailLabel(message))
                  .fontSize(11)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.getAssistantMessageStatusColor(message))

                Text(message.thinkingContent)
                  .fontSize(12)
                  .lineHeight(19)
                  .fontColor('#5373A6')
                  .width('100%')
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding(12)
              .backgroundColor('#FFFFFF')
              .borderRadius(18)
            }

            if (!this.isAssistantMessage(message) || message.content.trim().length > 0) {
              Text(message.content)
                .fontSize(14)
                .lineHeight(22)
                .fontColor(this.isAssistantMessage(message) ? PRIMARY_TEXT_COLOR : '#FFFFFF')
                .width('100%')
            }

            if (this.isAssistantMessage(message) && this.getMessageGeneratedPlans(message).length > 0) {
              this.buildGeneratedPlansSection(message)
            }

            if (this.isAssistantMessage(message) && this.getMessageGeneratedFoodPlans(message).length > 0) {
              this.buildGeneratedFoodPlansSection(message)
            }
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
      }, (message: AiChatMessage) => this.getChatMessageRenderKey(message))
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  @Builder
  buildGeneratedPlanCard(messageId: string, plan: AiGeneratedPlanItem) {
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
          this.updateGeneratedPlanField(messageId, plan.id, 'date', value);
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
          this.updateGeneratedPlanField(messageId, plan.id, 'title', value);
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
          this.updateGeneratedPlanField(messageId, plan.id, 'notes', value);
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
            this.importGeneratedPlan(messageId, plan.id);
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
  buildGeneratedFoodPlanCard(messageId: string, plan: AiGeneratedFoodPlanItem) {
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
            this.updateGeneratedFoodPlanField(messageId, plan.id, 'date', value);
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
            this.updateGeneratedFoodPlanField(messageId, plan.id, 'mealType', value);
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
          this.updateGeneratedFoodPlanField(messageId, plan.id, 'name', value);
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
            this.updateGeneratedFoodPlanField(messageId, plan.id, 'serving', value);
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
            this.updateGeneratedFoodPlanField(messageId, plan.id, 'calories', value);
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
          this.updateGeneratedFoodPlanField(messageId, plan.id, 'notes', value);
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
            this.importGeneratedFoodPlan(messageId, plan.id);
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
  buildGeneratedPlansSection(message: AiChatMessage) {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 4 }) {
          Text('训练计划草案')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text(`${this.getMessageGeneratedPlans(message).length} 条待处理草案`)
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
              this.importAllGeneratedPlans(message.id);
            })

          Button('清空')
            .height(34)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#7B61FF')
            .backgroundColor('#F2F0FF')
            .borderRadius(17)
            .onClick(() => {
              this.clearGeneratedPlans(message.id);
            })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      ForEach(this.getMessageGeneratedPlans(message), (plan: AiGeneratedPlanItem) => {
        this.buildGeneratedPlanCard(message.id, plan)
      }, (plan: AiGeneratedPlanItem) => plan.id)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 6, bottom: 2 })
  }

  @Builder
  buildGeneratedFoodPlansSection(message: AiChatMessage) {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 4 }) {
          Text('饮食计划草案')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text(`${this.getMessageGeneratedFoodPlans(message).length} 条待处理草案`)
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
              this.importAllGeneratedFoodPlans(message.id);
            })

          Button('清空')
            .height(34)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#C76B12')
            .backgroundColor('#FFF1D9')
            .borderRadius(17)
            .onClick(() => {
              this.clearGeneratedFoodPlans(message.id);
            })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      ForEach(this.getMessageGeneratedFoodPlans(message), (plan: AiGeneratedFoodPlanItem) => {
        this.buildGeneratedFoodPlanCard(message.id, plan)
      }, (plan: AiGeneratedFoodPlanItem) => plan.id)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 6, bottom: 2 })
  }

  @Builder
  buildQuickActionStrip(actions: AssistantQuickActionItem[]) {
    Scroll() {
      Row({ space: 10 }) {
        ForEach(actions, (item: AssistantQuickActionItem) => {
          Button(item.label)
            .height(40)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_TEXT_COLOR)
            .padding({ left: 18, right: 18 })
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
      .padding({ right: 20 })
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .opacity(this.assistantBusy ? 0.65 : 1)
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
          Text('智卡管家')
            .fontSize(24)
            .fontWeight(FontWeight.Bolder)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text(this.assistantBusy ? '智卡正在生成内容' : '开始一段管家对话')
            .fontSize(12)
            .fontColor(SECONDARY_TEXT_COLOR)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Row({ space: 8 }) {
          Button('记录')
            .height(34)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#0F6BFF')
            .backgroundColor(this.showHistoryPanel ? '#DCEBFF' : '#EAF2FF')
            .borderRadius(17)
            .padding({ left: 14, right: 14 })
            .onClick(() => {
              this.toggleHistoryPanel();
            })

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
          if (this.showHistoryPanel) {
            this.buildHistoryPanel()
          }

          if (this.showConfigPanel) {
            this.buildConfigPanel()
          }

          if (this.hasOnlyWelcomeMessage() && !this.showConfigPanel && !this.showHistoryPanel) {
            this.buildEmptyConversationState()
          } else {
            this.buildConversationFeed()
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

        this.buildQuickActionStrip(ASSISTANT_QUICK_ACTIONS)

        Row({ space: 8 }) {
          TextInput({ placeholder: '给智卡管家发送消息...', text: this.questionInput })
            .layoutWeight(1)
            .height(44)
            .fontSize(15)
            .fontColor(this.assistantBusy ? '#98A2B3' : PRIMARY_TEXT_COLOR)
            .padding({ left: 8, right: 8 })
            .backgroundColor('#00000000')
            .onChange((value: string) => {
              this.questionInput = value;
            })

          Button(this.showConfigPanel ? '×' : '+')
            .width(44)
            .height(44)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0F6BFF')
            .backgroundColor('#EAF2FF')
            .borderRadius(22)
            .onClick(() => {
              this.toggleConfigPanel();
            })

          Button(this.assistantBusy ? '■' : '↑')
            .width(46)
            .height(46)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.assistantBusy || this.questionInput.trim().length > 0 ? '#FFFFFF' : '#98A2B3')
            .backgroundColor(this.assistantBusy || this.questionInput.trim().length > 0 ? '#0F6BFF' : '#F3F6FB')
            .borderRadius(23)
            .onClick(() => {
              if (this.assistantBusy) {
                this.interruptAssistantRequest();
                return;
              }
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
