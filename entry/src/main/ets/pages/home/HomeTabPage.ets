import {
  PAGE_BACKGROUND_COLOR,
  PRIMARY_TEXT_COLOR,
  SECONDARY_TEXT_COLOR,
  SURFACE_BACKGROUND_COLOR
} from '../../constants/AppTheme';
import {
  AI_TASK_DAILY_BRIEFING,
  AiAssistantConfig,
  getDefaultAiApiEndpoint,
  getDefaultAiApiKey,
  getDefaultAiModel
} from '../../models/AiAssistant';
import {
  AI_TAB_INDEX,
  EXERCISE_TAB_INDEX,
  FOOD_TAB_INDEX,
  RECORD_TAB_INDEX
} from '../../models/TabItem';
import { WeightRecord } from '../../models/WeightRecord';
import {
  HomeDashboardCaloriesSummary,
  HomeReminderItem,
  HomeWeightTrendSummary,
  getHomeReminderItems,
  getHomeWeightTrend,
  getTodayDashboardCalories
} from '../../utils/HomeDashboardHelper';
import {
  DailyBriefingSummary,
  buildDailyBriefingAiPrompt,
  buildDailyBriefingSummary,
  getCachedDailyBriefingAiText,
  upsertDailyBriefingAiCache
} from '../../utils/DailyBriefingHelper';
import {
  DEFAULT_TTS_ENDPOINT,
  DEFAULT_TTS_VOICE,
  TtsPlaybackState,
  getCachedTtsAudioUrl,
  pauseTtsPlayback,
  playTtsAudioUrl,
  requestTtsBriefing,
  resumeTtsPlayback,
  upsertTtsAudioCache
} from '../../utils/TtsService';
import { EXERCISE_STORAGE_READY } from '../../utils/ExerciseStorage';
import { deserializeUserProfile, deserializeWorkoutRecords } from '../../utils/ExerciseHelper';
import { deserializeFoodPlans } from '../../utils/FoodHelper';
import { deserializeWorkoutPlans } from '../../utils/WorkoutPlanHelper';
import { deserializeWeightRecords, formatDate } from '../../utils/WeightRecordHelper';
import { requestAiAssistant } from '../../utils/AiAssistantHelper';

interface HomeQuickEntryItem {
  id: string;
  icon: string;
  title: string;
  description: string;
  tabIndex: number;
  accentColor: string;
  surfaceColor: string;
}

const HOME_QUICK_ENTRIES: HomeQuickEntryItem[] = [
  {
    id: 'food',
    icon: '食',
    title: '饮食',
    description: '记录摄入',
    tabIndex: FOOD_TAB_INDEX,
    accentColor: '#F59E0B',
    surfaceColor: '#FFF7E7'
  },
  {
    id: 'exercise',
    icon: '动',
    title: '运动',
    description: '累计消耗',
    tabIndex: EXERCISE_TAB_INDEX,
    accentColor: '#FF8B61',
    surfaceColor: '#FFF2ED'
  },
  {
    id: 'record',
    icon: '重',
    title: '体重',
    description: '查看趋势',
    tabIndex: RECORD_TAB_INDEX,
    accentColor: '#15B8A6',
    surfaceColor: '#EDFFFB'
  },
  {
    id: 'assistant',
    icon: '智',
    title: '管家',
    description: '今日分析',
    tabIndex: AI_TAB_INDEX,
    accentColor: '#6F7CFF',
    surfaceColor: '#F2F1FF'
  }
];

@Component
export struct HomeTabPage {
  @Link currentTabIndex: number;
  @StorageLink('foodPlanText') foodPlanText: string = '';
  @StorageLink('workoutPlanText') workoutPlanText: string = '';
  @StorageLink('workoutRecordText') workoutRecordText: string = '';
  @StorageLink('weightRecordText') weightRecordText: string = '';
  @StorageLink('userProfileText') userProfileText: string = '';
  @StorageLink('dailyFoodCalorieTargetText') dailyFoodCalorieTargetText: string = '';
  @StorageLink('aiApiEndpointText') aiApiEndpointText: string = '';
  @StorageLink('aiApiKeyText') aiApiKeyText: string = '';
  @StorageLink('aiModelText') aiModelText: string = '';
  @StorageLink('dailyBriefingAiCacheText') dailyBriefingAiCacheText: string = '';
  @StorageLink('ttsAudioCacheText') ttsAudioCacheText: string = '';
  @StorageLink('authUserIdText') authUserIdText: string = '';

  @State dailyBriefingBusy: boolean = false;
  @State ttsBusy: boolean = false;
  @State ttsPlaybackState: TtsPlaybackState = 'idle';
  @State dailyBriefingNotice: string = '本地规则已生成今日简报。';

  aboutToAppear(): void {
    EXERCISE_STORAGE_READY;
  }

  private getTodayText(): string {
    return formatDate(new Date());
  }

  private getAiConfig(): AiAssistantConfig {
    return {
      apiEndpoint: this.aiApiEndpointText.trim().length > 0 ? this.aiApiEndpointText : getDefaultAiApiEndpoint(),
      apiKey: this.aiApiKeyText.trim().length > 0 ? this.aiApiKeyText : getDefaultAiApiKey(),
      model: this.aiModelText.trim().length > 0 ? this.aiModelText : getDefaultAiModel()
    };
  }

  private hasAiConfig(): boolean {
    let config = this.getAiConfig();
    return config.apiEndpoint.trim().length > 0 &&
      config.apiKey.trim().length > 0 &&
      config.model.trim().length > 0;
  }

  private getDailyBriefingSummary(): DailyBriefingSummary {
    return buildDailyBriefingSummary(
      this.foodPlanText,
      this.workoutPlanText,
      this.workoutRecordText,
      this.weightRecordText,
      this.dailyFoodCalorieTargetText,
      this.getTodayText()
    );
  }

  private getCachedAiBriefingText(): string {
    return getCachedDailyBriefingAiText(this.dailyBriefingAiCacheText, this.getTodayText());
  }

  private getVisibleBriefingText(): string {
    let cachedAiText = this.getCachedAiBriefingText();
    if (cachedAiText.trim().length > 0) {
      return cachedAiText;
    }
    return this.getDailyBriefingSummary().primaryAdvice;
  }

  private getBriefingSpeechText(): string {
    let cachedAiText = this.getCachedAiBriefingText();
    if (cachedAiText.trim().length > 0) {
      return `智卡管家今日解读。${cachedAiText}`;
    }
    return this.getDailyBriefingSummary().speechText;
  }

  private getTtsEndpoint(): string {
    // 当前测试环境固定使用代码层 TTS 地址，避免本地缓存的旧 IP 覆盖可用服务。
    return DEFAULT_TTS_ENDPOINT;
  }

  private isTtsPlaybackToggleEnabled(): boolean {
    return this.ttsPlaybackState === 'playing' || this.ttsPlaybackState === 'paused';
  }

  private getTtsPauseButtonText(): string {
    if (this.ttsPlaybackState === 'paused') {
      return '继续播报';
    }
    if (this.ttsPlaybackState === 'playing') {
      return '暂停播报';
    }
    return '暂停/继续';
  }

  private getTtsPauseButtonTextColor(): string {
    return this.isTtsPlaybackToggleEnabled() ? '#0E9F6E' : '#98A2B3';
  }

  private getTtsPauseButtonBackgroundColor(): string {
    return this.isTtsPlaybackToggleEnabled() ? '#E8FBF6' : '#F3F6FB';
  }

  private getBriefingUserId(): string {
    if (this.authUserIdText.trim().length > 0) {
      return this.authUserIdText.trim();
    }
    let profile = deserializeUserProfile(this.userProfileText);
    if (profile.nickname.trim().length > 0) {
      return profile.nickname.trim();
    }
    return 'local-user';
  }

  private openTab(tabIndex: number): void {
    this.currentTabIndex = tabIndex;
  }

  private getCalorieSummary(): HomeDashboardCaloriesSummary {
    return getTodayDashboardCalories(
      this.foodPlanText,
      this.workoutRecordText,
      this.dailyFoodCalorieTargetText,
      this.getTodayText()
    );
  }

  private getWeightTrendSummary(): HomeWeightTrendSummary {
    return getHomeWeightTrend(this.weightRecordText, this.getTodayText());
  }

  private getReminderItems(): HomeReminderItem[] {
    return getHomeReminderItems(
      this.userProfileText,
      this.foodPlanText,
      this.workoutRecordText,
      this.weightRecordText,
      this.getTodayText()
    );
  }

  private getPrimaryReminder(): HomeReminderItem {
    return this.getReminderItems()[0];
  }

  private getUserHeadline(): string {
    let profile = deserializeUserProfile(this.userProfileText);
    if (profile.nickname.trim().length > 0) {
      return `${profile.nickname.trim()} 的今日概览`;
    }
    return '今日概览';
  }

  private getHeroAccentColor(): string {
    let summary = this.getCalorieSummary();
    if (summary.intakeCalories <= 0 && summary.burnedCalories <= 0) {
      return '#8EBBFF';
    }
    if (summary.netCalories < 0) {
      return '#4ED19A';
    }
    if (summary.netCalories <= 350) {
      return '#8EBBFF';
    }
    return '#FF8B61';
  }

  private getHeroBadgeText(): string {
    let summary = this.getCalorieSummary();
    if (summary.intakeCalories <= 0 && summary.burnedCalories <= 0) {
      return '等待记录';
    }
    if (summary.netCalories < 0) {
      return '消耗领先';
    }
    if (summary.netCalories === 0) {
      return '摄消平衡';
    }
    return '今日净热量';
  }

  private getNetCalorieValueText(): string {
    return `${Math.round(this.getCalorieSummary().netCalories)}`;
  }

  private getAdaptiveCalorieFontSize(valueText: string, largeSize: number, mediumSize: number, smallSize: number): number {
    let length = valueText.trim().length;
    if (length >= 7) {
      return smallSize;
    }
    if (length >= 5) {
      return mediumSize;
    }
    return largeSize;
  }

  private getNetCalorieFontSize(): number {
    return this.getAdaptiveCalorieFontSize(this.getNetCalorieValueText(), 34, 28, 22);
  }

  private getSideCalorieNumberText(type: string): string {
    let summary = this.getCalorieSummary();
    if (type === 'intake') {
      return `${Math.round(summary.intakeCalories)}`;
    }
    return `${Math.round(summary.burnedCalories)}`;
  }

  private getSideCalorieFontSize(type: string): number {
    return this.getAdaptiveCalorieFontSize(this.getSideCalorieNumberText(type), 24, 20, 17);
  }

  private getNetCalorieDescriptionText(): string {
    let summary = this.getCalorieSummary();
    if (summary.intakeCalories <= 0 && summary.burnedCalories <= 0) {
      return '先去记录饮食或训练，首页会自动同步今天的数据。';
    }
    if (summary.netCalories < 0) {
      return `今天训练消耗比摄入多 ${Math.round(Math.abs(summary.netCalories))} kcal。`;
    }
    if (summary.netCalories === 0) {
      return '摄入和消耗刚好持平。';
    }
    return `摄入减去消耗后，还剩 ${Math.round(summary.netCalories)} kcal。`;
  }

  private getTargetStatusText(): string {
    let summary = this.getCalorieSummary();
    if (summary.intakeCalories <= 0) {
      return `饮食目标 ${summary.targetCalories} kcal`;
    }
    if (summary.remainingTargetCalories >= 0) {
      return `距目标还差 ${Math.round(summary.remainingTargetCalories)} kcal`;
    }
    return `已超过目标 ${Math.round(Math.abs(summary.remainingTargetCalories))} kcal`;
  }

  private getProgressWidthText(): string {
    let ratio = Math.round(this.getCalorieSummary().intakeProgress * 100);
    if (ratio <= 0) {
      return '0%';
    }
    if (ratio < 12) {
      return '12%';
    }
    return `${ratio}%`;
  }

  private getIntakeStatusText(): string {
    if (this.getCalorieSummary().intakeCalories > 0) {
      return '已开始记录';
    }
    return '待补充饮食';
  }

  private getBurnedStatusText(): string {
    if (this.getCalorieSummary().burnedCalories > 0) {
      return '训练已累计';
    }
    return '待开始训练';
  }

  private getWeightTrendBadgeText(): string {
    let trendSummary = this.getWeightTrendSummary();
    if (trendSummary.recentRecords.length < 2) {
      return '待形成趋势';
    }
    if (trendSummary.changeValue <= -0.3) {
      return '近 7 次下降';
    }
    if (trendSummary.changeValue >= 0.3) {
      return '近 7 次回升';
    }
    return '近 7 次平稳';
  }

  private getLatestWeightText(): string {
    let latestRecord = this.getWeightTrendSummary().latestRecord;
    if (!latestRecord) {
      return '--';
    }
    return `${latestRecord.weight.toFixed(1)} kg`;
  }

  private getWeightChangeText(): string {
    let trendSummary = this.getWeightTrendSummary();
    if (trendSummary.recentRecords.length < 2) {
      return '继续记录形成趋势';
    }
    return `${trendSummary.changeValue <= 0 ? '下降' : '上升'} ${Math.abs(trendSummary.changeValue).toFixed(1)} kg`;
  }

  private getWeightSublineText(): string {
    let trendSummary = this.getWeightTrendSummary();
    if (!trendSummary.latestRecord) {
      return '开始记录后，这里会自动展示最近 7 条体重变化。';
    }
    if (trendSummary.hasTodayRecord) {
      return `今日已记录 · 近期均值 ${trendSummary.averageWeight.toFixed(1)} kg`;
    }
    return `最近记录 ${trendSummary.latestRecord.date} · 近期均值 ${trendSummary.averageWeight.toFixed(1)} kg`;
  }

  private getWeightMinValue(): number {
    let records = this.getWeightTrendSummary().recentRecords;
    if (records.length === 0) {
      return 0;
    }

    let minValue = records[0].weight;
    for (let index = 1; index < records.length; index++) {
      if (records[index].weight < minValue) {
        minValue = records[index].weight;
      }
    }
    return minValue;
  }

  private getWeightMaxValue(): number {
    let records = this.getWeightTrendSummary().recentRecords;
    if (records.length === 0) {
      return 0;
    }

    let maxValue = records[0].weight;
    for (let index = 1; index < records.length; index++) {
      if (records[index].weight > maxValue) {
        maxValue = records[index].weight;
      }
    }
    return maxValue;
  }

  private getWeightBarHeight(record: WeightRecord): number {
    let minValue = this.getWeightMinValue();
    let maxValue = this.getWeightMaxValue();
    let range = maxValue - minValue;
    if (range <= 0) {
      return 66;
    }
    let ratio = (record.weight - minValue) / range;
    return 38 + Math.round(ratio * 54);
  }

  private getWeightBarColor(record: WeightRecord): string {
    let latestRecord = this.getWeightTrendSummary().latestRecord;
    if (latestRecord && latestRecord.id === record.id) {
      return '#8EBBFF';
    }
    return '#D8E8FF';
  }

  private getWeightShortDate(dateText: string): string {
    if (dateText.length < 10) {
      return dateText;
    }
    return `${dateText.substring(5, 7)}/${dateText.substring(8, 10)}`;
  }

  private getQuickEntryStatusText(entryId: string): string {
    let calorieSummary = this.getCalorieSummary();
    let trendSummary = this.getWeightTrendSummary();

    if (entryId === 'food') {
      return calorieSummary.intakeCalories > 0 ? `${Math.round(calorieSummary.intakeCalories)} kcal` : '待记录';
    }
    if (entryId === 'exercise') {
      return calorieSummary.burnedCalories > 0 ? `${Math.round(calorieSummary.burnedCalories)} kcal` : '待训练';
    }
    if (entryId === 'record') {
      if (trendSummary.hasTodayRecord && trendSummary.latestRecord) {
        return `${trendSummary.latestRecord.weight.toFixed(1)} kg`;
      }
      return '待记录';
    }
    if (this.getPrimaryReminder().id === 'assistant') {
      return '可直接分析';
    }
    return '查看建议';
  }

  private async analyzeDailyBriefing(): Promise<void> {
    if (this.dailyBriefingBusy) {
      return;
    }
    if (!this.hasAiConfig()) {
      this.dailyBriefingNotice = '请先在智卡管家里配置 AI 接口和 API Key。';
      return;
    }

    let summary = this.getDailyBriefingSummary();
    this.dailyBriefingBusy = true;
    this.dailyBriefingNotice = '智卡管家正在解读今日计划...';
    try {
      let response = await requestAiAssistant(this.getAiConfig(), {
        task: AI_TASK_DAILY_BRIEFING,
        userPrompt: buildDailyBriefingAiPrompt(summary),
        profile: deserializeUserProfile(this.userProfileText),
        weightRecords: deserializeWeightRecords(this.weightRecordText),
        workoutRecords: deserializeWorkoutRecords(this.workoutRecordText),
        existingPlanCount: deserializeWorkoutPlans(this.workoutPlanText).length,
        existingFoodPlanCount: deserializeFoodPlans(this.foodPlanText).length,
        dailyFoodCalorieTarget: summary.targetCalories,
        savedWorkoutNames: [],
        historyMessages: []
      });
      let replyText = response.reply.trim();
      if (replyText.length === 0) {
        replyText = summary.primaryAdvice;
      }
      this.dailyBriefingAiCacheText = upsertDailyBriefingAiCache(
        this.dailyBriefingAiCacheText,
        this.getTodayText(),
        replyText
      );
      this.dailyBriefingNotice = '今日解读已更新，并已缓存到当天。';
    } catch (error) {
      this.dailyBriefingNotice = `${error}`;
    } finally {
      this.dailyBriefingBusy = false;
    }
  }

  private async speakDailyBriefing(): Promise<void> {
    if (this.ttsBusy) {
      return;
    }
    let endpoint = this.getTtsEndpoint();
    if (endpoint.trim().length === 0) {
      this.dailyBriefingNotice = '请先在智卡管家配置 IndexTTS2 本地服务地址。';
      return;
    }

    let speechText = this.getBriefingSpeechText();
    this.ttsBusy = true;
    this.dailyBriefingNotice = '正在准备智卡语音...';
    try {
      let cachedAudioUrl = getCachedTtsAudioUrl(
        this.ttsAudioCacheText,
        this.getTodayText(),
        speechText,
        DEFAULT_TTS_VOICE
      );
      if (cachedAudioUrl.trim().length > 0) {
        await playTtsAudioUrl(cachedAudioUrl, (state: TtsPlaybackState): void => {
          this.ttsPlaybackState = state;
        });
        this.dailyBriefingNotice = '已播放当天缓存语音。';
        return;
      }

      let ttsResponse = await requestTtsBriefing(endpoint, {
        userId: this.getBriefingUserId(),
        date: this.getTodayText(),
        text: speechText,
        voice: DEFAULT_TTS_VOICE
      });
      this.ttsAudioCacheText = upsertTtsAudioCache(
        this.ttsAudioCacheText,
        this.getTodayText(),
        speechText,
        DEFAULT_TTS_VOICE,
        ttsResponse
      );
      await playTtsAudioUrl(ttsResponse.audioUrl, (state: TtsPlaybackState): void => {
        this.ttsPlaybackState = state;
      });
      this.dailyBriefingNotice = ttsResponse.cached ? '已播放 IndexTTS2 缓存语音。' : 'IndexTTS2 语音已生成并播放。';
    } catch (error) {
      this.ttsPlaybackState = 'idle';
      this.dailyBriefingNotice = `${error}`;
    } finally {
      this.ttsBusy = false;
    }
  }

  private async toggleTtsPlaybackPause(): Promise<void> {
    if (!this.isTtsPlaybackToggleEnabled()) {
      this.dailyBriefingNotice = '当前没有正在播放或暂停的语音。';
      return;
    }
    try {
      if (this.ttsPlaybackState === 'paused') {
        let resumed = await resumeTtsPlayback();
        this.ttsPlaybackState = resumed ? 'playing' : 'idle';
        this.dailyBriefingNotice = resumed ? '已继续播放语音。' : '当前没有可继续的语音。';
        return;
      }
      let paused = await pauseTtsPlayback();
      this.ttsPlaybackState = paused ? 'paused' : 'idle';
      this.dailyBriefingNotice = paused ? '已暂停语音播报。' : '当前没有可暂停的语音。';
    } catch (error) {
      this.ttsPlaybackState = 'idle';
      this.dailyBriefingNotice = `${error}`;
    }
  }

  @Builder
  private buildBriefingMetric(label: string, valueText: string, subText: string, accentColor: string) {
    Column({ space: 5 }) {
      Text(label)
        .fontSize(11)
        .fontColor('#6F84A3')

      Text(valueText)
        .fontSize(this.getAdaptiveCalorieFontSize(valueText, 20, 17, 14))
        .fontWeight(FontWeight.Bolder)
        .fontColor(PRIMARY_TEXT_COLOR)
        .maxLines(1)

      Text(subText)
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(accentColor)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .padding(12)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
  }

  @Builder
  private buildDailyBriefingCard() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 4 }) {
          Text('智卡今日简报')
            .fontSize(20)
            .fontWeight(FontWeight.Bolder)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text(this.getCachedAiBriefingText().trim().length > 0 ? '已使用今日 AI 解读缓存' : '本地规则实时判断')
            .fontSize(12)
            .fontColor(SECONDARY_TEXT_COLOR)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.dailyBriefingBusy ? '解读中' : '管家')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor('#6F7CFF')
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('#F2F1FF')
          .borderRadius(999)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Row({ space: 10 }) {
        this.buildBriefingMetric(
          '热量账本',
          `${Math.round(this.getDailyBriefingSummary().remainingTargetCalories)}`,
          '剩余 kcal',
          this.getDailyBriefingSummary().remainingTargetCalories >= 0 ? '#10B981' : '#FF5A7A'
        )

        this.buildBriefingMetric(
          '计划状态',
          `${this.getDailyBriefingSummary().completedWorkoutPlanCount}/${this.getDailyBriefingSummary().workoutPlanCount}`,
          '训练完成',
          '#FF8B61'
        )

        this.buildBriefingMetric(
          '体重趋势',
          this.getDailyBriefingSummary().latestWeightText,
          this.getDailyBriefingSummary().latestWeightText === '--' ? '待记录' : '最新',
          '#15B8A6'
        )
      }
      .width('100%')

      Column({ space: 8 }) {
        Text('管家建议')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#5373A6')

        Text(this.getVisibleBriefingText())
          .fontSize(14)
          .lineHeight(22)
          .fontColor(PRIMARY_TEXT_COLOR)
          .width('100%')

        Text(`${this.getDailyBriefingSummary().calorieStatusText} ${this.getDailyBriefingSummary().foodStatusText} ${this.getDailyBriefingSummary().workoutStatusText}`)
          .fontSize(12)
          .lineHeight(18)
          .fontColor(SECONDARY_TEXT_COLOR)
          .maxLines(3)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(14)
      .backgroundColor('#FFFFFF')
      .borderRadius(18)

      Text(this.dailyBriefingNotice)
        .fontSize(12)
        .lineHeight(18)
        .fontColor(SECONDARY_TEXT_COLOR)
        .width('100%')

      Column({ space: 10 }) {
        Button(this.dailyBriefingBusy ? '解读中' : '解读今日计划')
          .width('100%')
          .height(46)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor(this.dailyBriefingBusy ? '#98A2B3' : '#6F7CFF')
          .borderRadius(16)
          .onClick(() => {
            this.analyzeDailyBriefing();
          })

        Row({ space: 10 }) {
          Button(this.ttsBusy ? '生成中' : '语音播报')
            .layoutWeight(1)
            .height(48)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#0F6BFF')
            .backgroundColor('#EAF2FF')
            .borderRadius(16)
            .onClick(() => {
              this.speakDailyBriefing();
            })

          Button(this.getTtsPauseButtonText())
            .layoutWeight(1)
            .height(48)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.getTtsPauseButtonTextColor())
            .backgroundColor(this.getTtsPauseButtonBackgroundColor())
            .borderRadius(16)
            .opacity(this.isTtsPlaybackToggleEnabled() ? 1 : 0.7)
            .onClick(() => {
              this.toggleTtsPlaybackPause();
            })
        }
        .width('100%')

        Button(this.getDailyBriefingSummary().suggestedActionText)
          .width('100%')
          .height(48)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#D97706')
          .backgroundColor('#FFF4E4')
          .borderRadius(16)
          .onClick(() => {
            this.openTab(this.getDailyBriefingSummary().suggestedActionTabIndex);
          })
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(18)
    .backgroundColor('#F7F6FF')
    .borderRadius(24)
    .border({
      color: '#DDD9FF',
      width: 1
    })
  }

  @Builder
  private buildEnergySideStat(title: string, calorieType: string, statusText: string, accentColor: string) {
    Column({ space: 8 }) {
      Text(title)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#6680A8')

      Column({ space: 2 }) {
        Text(this.getSideCalorieNumberText(calorieType))
          .fontSize(this.getSideCalorieFontSize(calorieType))
          .fontWeight(FontWeight.Bolder)
          .fontColor(PRIMARY_TEXT_COLOR)
          .maxLines(1)

        Text('kcal')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor('#6F84A3')
      }
      .alignItems(HorizontalAlign.Center)

      Text(statusText)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(accentColor)
        .padding({ left: 8, right: 8, top: 5, bottom: 5 })
        .backgroundColor('#FFFFFF')
        .borderRadius(999)
    }
    .alignItems(HorizontalAlign.Center)
    .layoutWeight(1)
  }

  @Builder
  private buildEnergyHeroCard() {
    Column({ space: 18 }) {
      Row() {
        Column({ space: 4 }) {
          Text(this.getUserHeadline())
            .fontSize(24)
            .fontWeight(FontWeight.Bolder)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text(this.getTodayText())
            .fontSize(12)
            .fontColor(SECONDARY_TEXT_COLOR)
        }
        .alignItems(HorizontalAlign.Start)

        Text(this.getHeroBadgeText())
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor('#6D8EBB')
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('#FFFFFF')
          .borderRadius(999)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Top)

      Row({ space: 10 }) {
        this.buildEnergySideStat(
          '摄入',
          'intake',
          this.getIntakeStatusText(),
          '#F59E0B'
        )

        Stack({ alignContent: Alignment.Center }) {
          Text('')
            .width(188)
            .height(188)
            .backgroundColor(this.getHeroAccentColor())
            .opacity(0.16)
            .borderRadius(94)

          Text('')
            .width(160)
            .height(160)
            .backgroundColor(this.getHeroAccentColor())
            .opacity(0.2)
            .borderRadius(80)

          Text('')
            .width(142)
            .height(142)
            .backgroundColor('#FFFFFF')
            .borderRadius(71)

          Text('')
            .width(130)
            .height(130)
            .border({
              width: 7,
              color: this.getHeroAccentColor()
            })
            .opacity(0.92)
            .borderRadius(65)

          Column({ space: 4 }) {
            Text(this.getNetCalorieValueText())
              .fontSize(this.getNetCalorieFontSize())
              .fontWeight(FontWeight.Bolder)
              .fontColor(PRIMARY_TEXT_COLOR)
              .maxLines(1)

            Text('kcal')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#6F84A3')

            Text('净热量')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#6F84A3')

            Text(this.getHeroBadgeText())
              .fontSize(10)
              .fontColor('#7A91B2')
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .backgroundColor('#EEF5FF')
              .borderRadius(999)
          }
          .alignItems(HorizontalAlign.Center)
        }

        this.buildEnergySideStat(
          '消耗',
          'burned',
          this.getBurnedStatusText(),
          '#FF8B61'
        )
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Column({ space: 8 }) {
        Row() {
          Text(this.getNetCalorieDescriptionText())
            .fontSize(12)
            .fontColor('#6A7B91')
            .layoutWeight(1)
            .maxLines(2)

          Text(this.getTargetStatusText())
            .fontSize(12)
            .fontColor('#6A7B91')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Stack({ alignContent: Alignment.Start }) {
          Text('')
            .width('100%')
            .height(8)
            .backgroundColor('#E5EEF9')
            .borderRadius(999)

          Text('')
            .width(this.getProgressWidthText())
            .height(8)
            .backgroundColor(this.getHeroAccentColor())
            .borderRadius(999)
        }
        .width('100%')
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(20)
    .backgroundColor('#F5FAFF')
    .borderRadius(28)
  }

  @Builder
  private buildWeightTrendCard() {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 4 }) {
          Text('本周体重')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text(this.getWeightSublineText())
            .fontSize(12)
            .fontColor(SECONDARY_TEXT_COLOR)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.getWeightTrendBadgeText())
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor('#7AA5E8')
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('#F1F6FF')
          .borderRadius(999)
      }
      .width('100%')

      Row({ space: 10 }) {
        Column({ space: 4 }) {
          Text('最新体重')
            .fontSize(11)
            .fontColor('#90A0B4')

          Text(this.getLatestWeightText())
            .fontSize(24)
            .fontWeight(FontWeight.Bolder)
            .fontColor(PRIMARY_TEXT_COLOR)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .padding(14)
        .backgroundColor('#F8FBFF')
        .borderRadius(18)

        Column({ space: 4 }) {
          Text('近 7 次变化')
            .fontSize(11)
            .fontColor('#90A0B4')

          Text(this.getWeightChangeText())
            .fontSize(22)
            .fontWeight(FontWeight.Bolder)
            .fontColor(this.getWeightTrendSummary().changeValue <= 0 ? '#22B573' : '#FF8B61')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .padding(14)
        .backgroundColor('#F8FBFF')
        .borderRadius(18)
      }
      .width('100%')

      if (this.getWeightTrendSummary().recentRecords.length > 0) {
        Row({ space: 8 }) {
          ForEach(this.getWeightTrendSummary().recentRecords, (record: WeightRecord) => {
            Column({ space: 8 }) {
              Text(record.weight.toFixed(1))
                .fontSize(10)
                .fontColor('#90A0B4')

              Column() {
                Text('')
                  .width('100%')
                  .height(this.getWeightBarHeight(record))
                  .backgroundColor(this.getWeightBarColor(record))
                  .borderRadius(12)
              }
              .width(26)
              .height(96)
              .justifyContent(FlexAlign.End)
              .backgroundColor('#EEF4FF')
              .borderRadius(12)

              Text(this.getWeightShortDate(record.date))
                .fontSize(10)
                .fontColor('#90A0B4')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
          }, (record: WeightRecord) => `${record.id}-${record.date}-${record.weight.toFixed(1)}`)
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)
      } else {
        Text('开始记录体重后，这里会自动展示最近 7 条趋势。')
          .fontSize(13)
          .lineHeight(20)
          .fontColor(SECONDARY_TEXT_COLOR)
          .padding(14)
          .width('100%')
          .backgroundColor('#F8FBFF')
          .borderRadius(18)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(18)
    .backgroundColor(SURFACE_BACKGROUND_COLOR)
    .borderRadius(24)
  }

  @Builder
  private buildQuickEntryCard() {
    Column({ space: 14 }) {
      Row() {
        Text('快捷入口')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(PRIMARY_TEXT_COLOR)

        Text('从首页直接进入常用页面')
          .fontSize(12)
          .fontColor(SECONDARY_TEXT_COLOR)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Row({ space: 10 }) {
        ForEach(HOME_QUICK_ENTRIES, (entry: HomeQuickEntryItem) => {
          Button() {
            Column({ space: 8 }) {
              Text(entry.icon)
                .fontSize(entry.icon.length > 1 ? 14 : 18)
                .fontWeight(FontWeight.Bold)
                .fontColor(entry.accentColor)
                .width(38)
                .height(38)
                .textAlign(TextAlign.Center)
                .padding({ top: 8, bottom: 8 })
                .backgroundColor('#FFFFFF')
                .borderRadius(19)

              Text(entry.title)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(PRIMARY_TEXT_COLOR)

              Text(this.getQuickEntryStatusText(entry.id))
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor(entry.accentColor)
                .maxLines(1)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          }
          .layoutWeight(1)
          .padding({ left: 8, right: 8, top: 14, bottom: 14 })
          .backgroundColor(entry.surfaceColor)
          .borderRadius(18)
          .onClick(() => {
            this.openTab(entry.tabIndex);
          })
        }, (entry: HomeQuickEntryItem) => entry.id)
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
  private buildReminderCard(reminderItem: HomeReminderItem) {
    Button() {
      Row({ space: 12 }) {
        Text('')
          .width(10)
          .height(10)
          .backgroundColor(reminderItem.accentColor)
          .borderRadius(5)

        Column({ space: 4 }) {
          Text(reminderItem.title)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text(reminderItem.description)
            .fontSize(12)
            .lineHeight(18)
            .fontColor(SECONDARY_TEXT_COLOR)
            .maxLines(2)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text('去处理')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(reminderItem.accentColor)
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('#FFFFFF')
          .borderRadius(999)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(18)
    .backgroundColor(SURFACE_BACKGROUND_COLOR)
    .borderRadius(24)
    .onClick(() => {
      this.openTab(reminderItem.targetTabIndex);
    })
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        this.buildEnergyHeroCard()
        this.buildDailyBriefingCard()
        this.buildWeightTrendCard()
        this.buildQuickEntryCard()
        this.buildReminderCard(this.getPrimaryReminder())
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 28 })
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
