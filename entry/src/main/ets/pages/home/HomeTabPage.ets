import {
  PAGE_BACKGROUND_COLOR,
  PRIMARY_TEXT_COLOR,
  SECONDARY_TEXT_COLOR,
  SURFACE_BACKGROUND_COLOR
} from '../../constants/AppTheme';
import {
  AI_ROLE_ASSISTANT,
  AI_ROLE_USER,
  AI_TASK_ANALYZE_WEIGHT,
  AI_TASK_CHAT,
  AI_TASK_GENERATE_PLAN,
  AiAssistantConfig,
  AiChatMessage,
  AiGeneratedPlanItem,
  createAiChatMessage,
  getDefaultAiApiEndpoint,
  getDefaultAiModel,
  getDefaultAiApiKey
} from '../../models/AiAssistant';
import { EXERCISE_TAB_INDEX } from '../../models/TabItem';
import { UserProfile } from '../../models/UserProfile';
import { SavedCustomWorkout } from '../../models/ExerciseOption';
import { WorkoutPlanItem } from '../../models/WorkoutPlan';
import { WeightRecord } from '../../models/WeightRecord';
import { WorkoutRecord } from '../../models/WorkoutRecord';
import { deserializeExerciseDraft, deserializeSavedCustomWorkouts, deserializeWorkoutRecords } from '../../utils/ExerciseHelper';
import { requestAiAssistant } from '../../utils/AiAssistantHelper';
import {
  deserializeWeightRecords,
  formatDate,
  getAverageWeight,
  getLatestWeightRecord,
  getRecentWeightRecords,
  getWeightChange
} from '../../utils/WeightRecordHelper';
import {
  createWorkoutPlanItem,
  deserializeWorkoutPlans,
  serializeWorkoutPlans
} from '../../utils/WorkoutPlanHelper';

@Component
export struct HomeTabPage {
  @Link currentTabIndex: number;
  @Link userProfile: UserProfile;
  @StorageLink('weightRecordText') weightRecordText: string = '';
  @StorageLink('workoutPlanText') workoutPlanText: string = '';
  @StorageLink('workoutRecordText') workoutRecordText: string = '';
  @StorageLink('savedCustomWorkoutText') savedCustomWorkoutText: string = '';
  @StorageLink('aiApiEndpointText') aiApiEndpointText: string = '';
  @StorageLink('aiApiKeyText') aiApiKeyText: string = '';
  @StorageLink('aiModelText') aiModelText: string = '';

  @State questionInput: string = '';
  @State assistantBusy: boolean = false;
  @State assistantNotice: string = '配置好接口后，就可以让 AI 分析近期体重并生成可导入训练计划。';
  @State chatMessages: AiChatMessage[] = [];
  @State generatedPlans: AiGeneratedPlanItem[] = [];

  aboutToAppear(): void {
    this.ensureDefaultAiConfig();
    if (this.chatMessages.length === 0) {
      this.chatMessages = [
        createAiChatMessage(
          AI_ROLE_ASSISTANT,
          '我是你的 AI 训练助手。我可以结合最近体重变化回答问题，也能生成训练计划草案，导入后会自动出现在训练页。'
        )
      ];
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
    this.assistantNotice = '已恢复 BigModel 默认配置，默认值来自 AiAssistant.ets。';
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

  private getWorkoutRecords(): WorkoutRecord[] {
    return deserializeWorkoutRecords(this.workoutRecordText);
  }

  private getSavedCustomWorkouts(): SavedCustomWorkout[] {
    return deserializeSavedCustomWorkouts(this.savedCustomWorkoutText);
  }

  private hasAiConfig(): boolean {
    return this.aiApiEndpointText.trim().length > 0 &&
      this.aiApiKeyText.trim().length > 0 &&
      this.aiModelText.trim().length > 0;
  }

  private getUserName(): string {
    return this.userProfile.nickname.trim().length > 0 ? this.userProfile.nickname.trim() : '你';
  }

  private getLatestWeightText(): string {
    let latestRecord = getLatestWeightRecord(this.getWeightRecords());
    if (!latestRecord) {
      return '--';
    }
    return `${latestRecord.weight.toFixed(1)} kg`;
  }

  private getWeightTrendText(): string {
    let recentRecords = getRecentWeightRecords(this.getWeightRecords(), 7);
    if (recentRecords.length < 2) {
      return '至少记录 2 次体重后，AI 会更容易看出趋势。';
    }

    let changeValue = getWeightChange(recentRecords);
    let directionText = changeValue <= 0 ? '下降' : '上升';
    return `最近 ${recentRecords.length} 次整体${directionText} ${Math.abs(changeValue).toFixed(1)} kg，平均 ${getAverageWeight(recentRecords).toFixed(1)} kg。`;
  }

  private getPlanCounterText(): string {
    let planCount = this.getWorkoutPlans().length;
    return planCount > 0 ? `训练页已保存 ${planCount} 条计划` : '训练页还没有已保存计划';
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

  private addChatMessage(role: string, content: string): void {
    let nextMessages: AiChatMessage[] = this.chatMessages.slice();
    nextMessages.push(createAiChatMessage(role, content));
    this.chatMessages = nextMessages;
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
    this.assistantNotice = task === AI_TASK_GENERATE_PLAN ? '正在生成训练计划草案...' : '正在分析你的数据...';

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
        savedWorkoutNames: savedWorkoutNames,
        historyMessages: this.chatMessages
      });

      this.addChatMessage(AI_ROLE_ASSISTANT, response.reply);
      if (response.plans.length > 0) {
        this.generatedPlans = response.plans;
        this.assistantNotice = `AI 已生成 ${response.plans.length} 条计划草案，你可以先调整再导入。`;
      } else if (task === AI_TASK_GENERATE_PLAN) {
        this.generatedPlans = [];
        this.assistantNotice = 'AI 这次没有返回可导入计划，可以换个问法再试一次。';
      } else {
        this.assistantNotice = 'AI 建议已更新。';
      }
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

  private generatePlanDrafts(): void {
    this.submitToAssistant(
      AI_TASK_GENERATE_PLAN,
      `请结合${this.getUserName()}最近的体重和训练情况，为我生成接下来几天适合导入 App 的训练计划。`
    );
  }

  private sendFreeQuestion(): void {
    this.submitToAssistant(AI_TASK_CHAT, this.questionInput);
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

  private importGeneratedPlan(planId: string): void {
    let targetPlan: AiGeneratedPlanItem | undefined = undefined;
    for (let index = 0; index < this.generatedPlans.length; index++) {
      if (this.generatedPlans[index].id === planId) {
        targetPlan = this.generatedPlans[index];
        break;
      }
    }

    if (!targetPlan) {
      this.assistantNotice = '没有找到这条计划草案，请重新生成一次。';
      return;
    }
    if (targetPlan.imported) {
      this.assistantNotice = '这条计划已经导入过了。';
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
    this.assistantNotice = `已导入计划「${targetPlan.title}」，现在可以去训练页查看。`;
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
      this.assistantNotice = '没有新的计划需要导入。';
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
    this.assistantNotice = `已导入 ${importedCount} 条计划草案。`;
  }

  private clearGeneratedPlans(): void {
    this.generatedPlans = [];
    this.assistantNotice = '已清空当前计划草案。';
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

  private isAssistantMessage(message: AiChatMessage): boolean {
    return message.role === AI_ROLE_ASSISTANT;
  }

  @Builder
  buildConfigCard() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 4 }) {
          Text('AI 接口配置')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text('默认会从 AiAssistant.ets 读取 BigModel 的接口地址、模型和 API Key，也可以在页面里临时修改。')
            .fontSize(12)
            .lineHeight(18)
            .fontColor(SECONDARY_TEXT_COLOR)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.hasAiConfig() ? '可调用' : '待配置')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.hasAiConfig() ? '#2E8B57' : '#C95F34')
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor(this.hasAiConfig() ? '#EAF5EE' : '#FFF1E8')
        .borderRadius(999)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Button('恢复 BigModel 默认')
        .width('100%')
        .height(40)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#17324D')
        .backgroundColor('#EEF3FF')
        .borderRadius(18)
        .onClick(() => {
          this.restoreDefaultAiConfig();
        })

      Column({ space: 8 }) {
        Text('接口地址')
          .fontSize(12)
          .fontColor('#4F6690')
        TextInput({ placeholder: getDefaultAiApiEndpoint(), text: this.aiApiEndpointText })
          .fontSize(15)
          .fontColor(PRIMARY_TEXT_COLOR)
          .height(46)
          .width('100%')
          .padding({ left: 12, right: 12 })
          .backgroundColor('#F6F8FB')
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
            .fontColor('#4F6690')
          TextInput({ placeholder: getDefaultAiModel(), text: this.aiModelText })
            .fontSize(15)
            .fontColor(PRIMARY_TEXT_COLOR)
            .height(46)
            .width('100%')
            .padding({ left: 12, right: 12 })
            .backgroundColor('#F6F8FB')
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
            .fontColor('#4F6690')
          TextInput({ placeholder: getDefaultAiApiKey(), text: this.aiApiKeyText })
            .fontSize(15)
            .fontColor(PRIMARY_TEXT_COLOR)
            .height(46)
            .width('100%')
            .padding({ left: 12, right: 12 })
            .backgroundColor('#F6F8FB')
            .borderRadius(16)
            .onChange((value: string) => {
              this.aiApiKeyText = value;
            })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      Text('提示：页面初始值来自 AiAssistant.ets；当前仍是本地持久化存储，方便调试，但不适合生产环境。')
        .fontSize(12)
        .lineHeight(18)
        .fontColor('#667085')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(18)
    .backgroundColor(SURFACE_BACKGROUND_COLOR)
    .borderRadius(24)
  }

  @Builder
  buildChatCard() {
    Column({ space: 14 }) {
      Column({ space: 4 }) {
        Text('对话与建议')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(PRIMARY_TEXT_COLOR)

        Text(this.getAssistantStatusText())
          .fontSize(12)
          .lineHeight(18)
          .fontColor(SECONDARY_TEXT_COLOR)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      Row({ space: 10 }) {
        Button('分析体重趋势')
          .layoutWeight(1)
          .height(40)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#17324D')
          .backgroundColor('#EEF3FF')
          .borderRadius(16)
          .onClick(() => {
            this.askAboutWeightTrend();
          })

        Button('生成计划草案')
          .layoutWeight(1)
          .height(40)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor('#17324D')
          .borderRadius(16)
          .onClick(() => {
            this.generatePlanDrafts();
          })
      }
      .width('100%')

      Column({ space: 10 }) {
        ForEach(this.chatMessages, (message: AiChatMessage) => {
          Column({ space: 6 }) {
            Text(this.isAssistantMessage(message) ? 'AI 助手' : this.getUserName())
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.isAssistantMessage(message) ? '#4F6690' : '#816A47')

            Text(message.content)
              .fontSize(14)
              .lineHeight(22)
              .fontColor(PRIMARY_TEXT_COLOR)
              .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(14)
          .backgroundColor(this.isAssistantMessage(message) ? '#F6F8FB' : '#FBF3E4')
          .borderRadius(18)
        }, (message: AiChatMessage) => message.id)
      }
      .width('100%')

      TextInput({ placeholder: '例如：我最近体重有点反弹，训练应该怎么调？', text: this.questionInput })
        .fontSize(15)
        .fontColor(PRIMARY_TEXT_COLOR)
        .height(46)
        .width('100%')
        .padding({ left: 12, right: 12 })
        .backgroundColor('#F6F8FB')
        .borderRadius(16)
        .onChange((value: string) => {
          this.questionInput = value;
        })

      Row({ space: 10 }) {
        Button('发送问题')
          .layoutWeight(1)
          .height(42)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor(this.assistantBusy ? '#98A2B3' : '#D86C3D')
          .borderRadius(18)
          .onClick(() => {
            this.sendFreeQuestion();
          })

        Button('去训练页')
          .width(112)
          .height(42)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#17324D')
          .backgroundColor('#EEF3FF')
          .borderRadius(18)
          .onClick(() => {
            this.openExerciseTab();
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

  @Builder
  buildGeneratedPlanCard() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 4 }) {
          Text('训练计划草案')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text(this.generatedPlans.length > 0 ? `${this.generatedPlans.length} 条待处理草案` : 'AI 返回的计划会先显示在这里，确认后再导入。')
            .fontSize(12)
            .lineHeight(18)
            .fontColor(SECONDARY_TEXT_COLOR)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (this.generatedPlans.length > 0) {
          Button('全部导入')
            .height(36)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .backgroundColor('#17324D')
            .borderRadius(18)
            .onClick(() => {
              this.importAllGeneratedPlans();
            })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      if (this.generatedPlans.length === 0) {
        Text('先点击“生成计划草案”，或在对话里直接让 AI 帮你安排一周训练。')
          .fontSize(13)
          .lineHeight(20)
          .fontColor(SECONDARY_TEXT_COLOR)
          .width('100%')
          .padding(14)
          .backgroundColor('#F6F8FB')
          .borderRadius(18)
      }

      ForEach(this.generatedPlans, (plan: AiGeneratedPlanItem) => {
        Column({ space: 10 }) {
          Row() {
            Text(plan.imported ? '已导入' : '待确认')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(plan.imported ? '#2E8B57' : '#4F6690')
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .backgroundColor(plan.imported ? '#EAF5EE' : '#EEF3FF')
              .borderRadius(999)

            Text(plan.summary)
              .layoutWeight(1)
              .fontSize(12)
              .fontColor(SECONDARY_TEXT_COLOR)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          TextInput({ placeholder: '计划日期 YYYY-MM-DD', text: plan.date })
            .fontSize(14)
            .fontColor(PRIMARY_TEXT_COLOR)
            .height(42)
            .width('100%')
            .padding({ left: 12, right: 12 })
            .backgroundColor('#F6F8FB')
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
            .backgroundColor('#F6F8FB')
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
            .backgroundColor('#F6F8FB')
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
              .fontColor('#17324D')
              .backgroundColor('#EEF3FF')
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
        .backgroundColor('#FFFDF8')
        .borderRadius(20)
        .border({
          color: '#E5E9F0',
          width: 1
        })
      }, (plan: AiGeneratedPlanItem) => plan.id)

      if (this.generatedPlans.length > 0) {
        Button('清空草案')
          .width('100%')
          .height(40)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#7A5C2E')
          .backgroundColor('#F8EEDC')
          .borderRadius(18)
          .onClick(() => {
            this.clearGeneratedPlans();
          })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(18)
    .backgroundColor(SURFACE_BACKGROUND_COLOR)
    .borderRadius(24)
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Column({ space: 8 }) {
          Text('AI 训练助手')
            .fontSize(30)
            .fontWeight(FontWeight.Bolder)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text('先看体重趋势，再向 AI 追问建议，最后把计划草案导入训练页。')
            .fontSize(14)
            .lineHeight(22)
            .fontColor(SECONDARY_TEXT_COLOR)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')

        Column({ space: 8 }) {
          Text(`${this.getUserName()} 的近期状态`)
            .fontSize(14)
            .fontColor('#D8E5FF')

          Text(this.getLatestWeightText())
            .fontSize(34)
            .fontWeight(FontWeight.Bolder)
            .fontColor('#FFFFFF')

          Text(this.getWeightTrendText())
            .fontSize(13)
            .lineHeight(20)
            .fontColor('#D8E5FF')

          Text(this.getPlanCounterText())
            .fontSize(12)
            .fontColor('#B7CAE8')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(18)
        .backgroundColor('#17324D')
        .borderRadius(24)

        this.buildConfigCard()
        this.buildChatCard()
        this.buildGeneratedPlanCard()
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
}
