import {
  PAGE_BACKGROUND_COLOR,
  PRIMARY_TEXT_COLOR,
  SECONDARY_TEXT_COLOR,
  SURFACE_BACKGROUND_COLOR
} from '../../constants/AppTheme';
import { WeightRecord } from '../../models/WeightRecord';
import {
  CHART_BAR_MAX_HEIGHT,
  CHART_BAR_MIN_HEIGHT,
  CHART_BAR_TRACK_HEIGHT,
  CHART_MIN_SPAN,
  CHART_SCALE_STEP,
  clamp,
  compareRecordDate,
  deserializeWeightRecords,
  formatDate,
  getNextWeightRecordId,
  roundDownToStep,
  roundUpToStep,
  serializeWeightRecords
} from '../../utils/WeightRecordHelper';
import {
  buildMonthCalendarRows,
  CALENDAR_WEEK_LABELS,
  CalendarMonthCell,
  formatMonthTitle,
  shiftCalendarMonth
} from '../../utils/MonthCalendarHelper';
import { DEFAULT_API_BASE_URL, isAuthSessionValid } from '../../models/AuthSession';
import { deserializeAuthSession } from '../../utils/AuthStorageHelper';
import {
  createEmptyRemoteWeightSummary,
  fetchWeightRecords,
  fetchWeightSummary,
  RemoteWeightSummary,
  upsertWeightRecordRemote
} from '../../utils/ApiService';

const CHART_BAR_GROUP_WIDTH: number = 40;
const CHART_BAR_GROUP_SPACING: number = 12;

interface CalendarDayItem extends CalendarMonthCell {
  hasRecord: boolean;
}

@Component
export struct RecordTabPage {
  @StorageLink('weightRecordText') weightRecordText: string = '';
  @StorageLink('apiBaseUrlText') apiBaseUrlText: string = '';
  @StorageLink('authSessionText') authSessionText: string = '';
  @State records: WeightRecord[] = [];
  @State weightInput: string = '';
  @State noticeText: string = '只能记录今天的体重；当天多次提交会覆盖当天记录。';
  @State nextId: string = '1';
  @State useEmojiTag: boolean = true;
  // 记录更新后递增版本号，确保列表 key 能稳定刷新。
  @State recordsVersion: number = 0;
  @State calendarYear: number = new Date().getFullYear();
  @State calendarMonth: number = new Date().getMonth();
  @State remoteSyncing: boolean = false;
  @State remoteSummary: RemoteWeightSummary = createEmptyRemoteWeightSummary();

  aboutToAppear(): void {
    if (this.apiBaseUrlText.trim().length === 0) {
      this.apiBaseUrlText = DEFAULT_API_BASE_URL;
    }
    this.syncRecordsFromStorage();
    this.syncRemoteWeightData();
  }

  private syncRecordsFromStorage(): void {
    this.records = deserializeWeightRecords(this.weightRecordText);
    this.nextId = getNextWeightRecordId(this.records);
  }

  getSortedRecords(): WeightRecord[] {
    let sortedRecords = this.records.slice();
    sortedRecords.sort((left: WeightRecord, right: WeightRecord) => compareRecordDate(left, right));
    return sortedRecords;
  }

  getRecentRecords(): WeightRecord[] {
    let sortedRecords = this.getSortedRecords();
    if (sortedRecords.length <= 7) {
      return sortedRecords;
    }
    return sortedRecords.slice(sortedRecords.length - 7, sortedRecords.length);
  }

  getLatestRecord(): WeightRecord | undefined {
    let sortedRecords = this.getSortedRecords();
    if (sortedRecords.length === 0) {
      return undefined;
    }
    return sortedRecords[sortedRecords.length - 1];
  }

  getPreviousRecord(): WeightRecord | undefined {
    let sortedRecords = this.getSortedRecords();
    if (sortedRecords.length < 2) {
      return undefined;
    }
    return sortedRecords[sortedRecords.length - 2];
  }

  getWeeklyAverage(): number {
    if (this.remoteSummary.recentCount > 0) {
      return this.remoteSummary.averageWeight;
    }
    let recentRecords = this.getRecentRecords();
    if (recentRecords.length === 0) {
      return 0;
    }

    let totalWeight = 0;
    for (let index = 0; index < recentRecords.length; index++) {
      totalWeight += recentRecords[index].weight;
    }
    return totalWeight / recentRecords.length;
  }

  getWeeklyChange(): number {
    if (this.remoteSummary.recentCount > 0) {
      return this.remoteSummary.changeInRange;
    }
    let recentRecords = this.getRecentRecords();
    if (recentRecords.length < 2) {
      return 0;
    }
    return recentRecords[recentRecords.length - 1].weight - recentRecords[0].weight;
  }

  getTodayChange(): number {
    if (this.remoteSummary.recentCount > 0) {
      return this.remoteSummary.changeFromPrevious;
    }
    let latestRecord = this.getLatestRecord();
    let previousRecord = this.getPreviousRecord();
    if (!latestRecord || !previousRecord) {
      return 0;
    }
    return latestRecord.weight - previousRecord.weight;
  }

  getCurrentWeightText(): string {
    let latestRecord = this.getLatestRecord();
    if (!latestRecord) {
      return '--';
    }
    return `${latestRecord.weight.toFixed(1)} kg`;
  }

  getCurrentDateText(): string {
    let latestRecord = this.getLatestRecord();
    if (!latestRecord) {
      return '还没有体重记录';
    }
    return `最新记录：${latestRecord.date}`;
  }

  getWeeklyChangeText(): string {
    let change = this.getWeeklyChange();
    let direction = change <= 0 ? '下降' : '上升';
    return `${direction} ${Math.abs(change).toFixed(1)} kg`;
  }

  getAverageText(): string {
    let recentRecords = this.getRecentRecords();
    if (recentRecords.length === 0) {
      return '--';
    }
    return `${this.getWeeklyAverage().toFixed(1)} kg`;
  }

  getFeedbackTitle(): string {
    let weeklyChange = this.getWeeklyChange();
    if (this.getRecentRecords().length < 3) {
      return '先连续记录几天';
    }
    if (weeklyChange <= -0.5) {
      return '近期趋势不错';
    }
    if (weeklyChange >= 0.5) {
      return '近期有回升';
    }
    return '整体比较平稳';
  }

  getFeedbackText(): string {
    let recentRecords = this.getRecentRecords();
    if (recentRecords.length < 3) {
      return '连续记录 3 天以上后，我会基于近期波动给出更可靠的反馈。';
    }

    let weeklyChange = this.getWeeklyChange();
    let todayChange = this.getTodayChange();
    let averageWeight = this.getWeeklyAverage();
    let latestRecord = this.getLatestRecord();

    if (!latestRecord) {
      return '先补充今天的体重记录。';
    }

    if (weeklyChange <= -0.5 && latestRecord.weight <= averageWeight) {
      return `最近 7 次记录整体下降 ${Math.abs(weeklyChange).toFixed(1)} kg，当前体重也低于近期均值，保持现在的作息和饮食节奏即可。`;
    }

    if (weeklyChange >= 0.5 && todayChange >= 0.2) {
      return `最近走势有明显回升，今天又比上一次高 ${Math.abs(todayChange).toFixed(1)} kg。建议先检查晚餐、零食和近两天活动量。`;
    }

    if (Math.abs(weeklyChange) < 0.5) {
      return '最近一周整体比较平稳。如果你正在减脂，可以继续稳定记录，再观察睡眠、饮水和盐分摄入对波动的影响。';
    }

    return `今天比上一次${todayChange <= 0 ? '下降' : '上升'} ${Math.abs(todayChange).toFixed(1)} kg。继续记录，优先看周趋势，不要只盯单日波动。`;
  }

  getFeedbackBackgroundColor(): string {
    let weeklyChange = this.getWeeklyChange();
    if (weeklyChange <= -0.5) {
      return '#ECFFF4';
    }
    if (weeklyChange >= 0.5) {
      return '#FFF0F6';
    }
    return '#EAF2FF';
  }

  getFeedbackAccentColor(): string {
    let weeklyChange = this.getWeeklyChange();
    if (weeklyChange <= -0.5) {
      return '#10B981';
    }
    if (weeklyChange >= 0.5) {
      return '#FF7A59';
    }
    return '#0F6BFF';
  }

  getChartBounds(): number[] {
    let recentRecords = this.getRecentRecords();
    if (recentRecords.length === 0) {
      return [0, CHART_MIN_SPAN];
    }

    let minWeight = recentRecords[0].weight;
    let maxWeight = recentRecords[0].weight;
    for (let index = 1; index < recentRecords.length; index++) {
      if (recentRecords[index].weight < minWeight) {
        minWeight = recentRecords[index].weight;
      }
      if (recentRecords[index].weight > maxWeight) {
        maxWeight = recentRecords[index].weight;
      }
    }

    let rawRange = maxWeight - minWeight;
    let padding = Math.max(0.6, rawRange * 0.15);
    let displayMin = roundDownToStep(minWeight - padding, CHART_SCALE_STEP);
    let displayMax = roundUpToStep(maxWeight + padding, CHART_SCALE_STEP);

    if (displayMax - displayMin < CHART_MIN_SPAN) {
      let centerWeight = (maxWeight + minWeight) / 2;
      displayMin = roundDownToStep(centerWeight - CHART_MIN_SPAN / 2, CHART_SCALE_STEP);
      displayMax = roundUpToStep(centerWeight + CHART_MIN_SPAN / 2, CHART_SCALE_STEP);
    }

    displayMin = Math.max(0, displayMin);
    if (displayMax - displayMin < CHART_MIN_SPAN) {
      displayMax = displayMin + CHART_MIN_SPAN;
    }

    return [displayMin, displayMax];
  }

  getChartMinWeight(): number {
    return this.getChartBounds()[0];
  }

  getChartMaxWeight(): number {
    return this.getChartBounds()[1];
  }

  getBarHeight(record: WeightRecord): number {
    let minWeight = this.getChartMinWeight();
    let maxWeight = this.getChartMaxWeight();
    let range = maxWeight - minWeight;

    if (range <= 0) {
      return CHART_BAR_MIN_HEIGHT;
    }

    let normalizedValue = clamp((record.weight - minWeight) / range, 0, 1);
    return CHART_BAR_MIN_HEIGHT + normalizedValue * (CHART_BAR_MAX_HEIGHT - CHART_BAR_MIN_HEIGHT);
  }

  getShortDate(date: string): string {
    if (date.length < 10) {
      return date;
    }
    return `${date.substring(5, 7)}/${date.substring(8, 10)}`;
  }

  getDisplayRecords(): WeightRecord[] {
    let sortedRecords = this.getSortedRecords();
    sortedRecords.reverse();
    if (sortedRecords.length <= 5) {
      return sortedRecords;
    }
    return sortedRecords.slice(0, 5);
  }

  isLatestRecord(record: WeightRecord): boolean {
    let latestRecord = this.getLatestRecord();
    if (!latestRecord) {
      return false;
    }
    return latestRecord.id === record.id;
  }

  getRecordRenderKey(record: WeightRecord): string {
    return `${record.id}-${this.recordsVersion}`;
  }

  getTodayDate(): string {
    return formatDate(new Date());
  }

  getTodayWeekdayText(): string {
    const weekNames: string[] = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];
    return weekNames[new Date().getDay()];
  }

  getRecordDelta(record: WeightRecord): number {
    let recentRecords = this.getRecentRecords();
    for (let index = 0; index < recentRecords.length; index++) {
      if (recentRecords[index].id === record.id) {
        if (index === 0) {
          return 0;
        }
        return record.weight - recentRecords[index - 1].weight;
      }
    }
    return 0;
  }

  getRecordTextTag(record: WeightRecord): string {
    if (this.isLatestRecord(record)) {
      return '最新';
    }

    let delta = this.getRecordDelta(record);
    if (delta <= -0.2) {
      return '下降';
    }
    if (delta >= 0.2) {
      return '上升';
    }
    return '平稳';
  }

  getRecordEmojiTag(record: WeightRecord): string {
    if (this.isLatestRecord(record)) {
      return '⭐';
    }

    let delta = this.getRecordDelta(record);
    if (delta <= -0.2) {
      return '😎';
    }
    if (delta >= 0.2) {
      return '😅';
    }
    return '🙂';
  }

  getRecordTag(record: WeightRecord): string {
    if (this.useEmojiTag) {
      return this.getRecordEmojiTag(record);
    }
    return this.getRecordTextTag(record);
  }

  getRecordTagModeText(): string {
    return this.useEmojiTag ? '表情' : '文字';
  }

  getRecordTagToggleText(): string {
    return this.useEmojiTag ? '切到文字' : '切到表情';
  }

  getRecordTagFontSize(): number {
    return this.useEmojiTag ? 18 : 12;
  }

  getCalendarTitle(): string {
    return formatMonthTitle(this.calendarYear, this.calendarMonth);
  }

  private changeCalendarMonth(step: number): void {
    let nextCursor = shiftCalendarMonth(this.calendarYear, this.calendarMonth, step);
    this.calendarYear = nextCursor.year;
    this.calendarMonth = nextCursor.month;
    this.syncRemoteWeightData();
  }

  private getMonthPrefix(): string {
    return `${this.calendarYear}-${this.calendarMonth + 1 < 10 ? `0${this.calendarMonth + 1}` : `${this.calendarMonth + 1}`}-`;
  }

  private hasRecordOnDate(dateText: string): boolean {
    for (let index = 0; index < this.records.length; index++) {
      if (this.records[index].date === dateText) {
        return true;
      }
    }
    return false;
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
          hasRecord: currentCell.isCurrentMonth ? this.hasRecordOnDate(currentCell.dateText) : false
        });
      }
      rows.push(nextRow);
    }

    return rows;
  }

  private getMonthRecordCount(): number {
    let monthPrefix: string = this.getMonthPrefix();
    let count: number = 0;
    for (let index = 0; index < this.records.length; index++) {
      if (this.records[index].date.startsWith(monthPrefix)) {
        count += 1;
      }
    }
    return count;
  }

  private getMonthLatestRecord(): WeightRecord | undefined {
    let latestRecord: WeightRecord | undefined = undefined;
    let monthPrefix: string = this.getMonthPrefix();
    for (let index = 0; index < this.records.length; index++) {
      if (!this.records[index].date.startsWith(monthPrefix)) {
        continue;
      }
      latestRecord = this.records[index];
    }
    return latestRecord;
  }

  private getMonthAverageText(): string {
    let monthPrefix: string = this.getMonthPrefix();
    let totalWeight: number = 0;
    let count: number = 0;
    for (let index = 0; index < this.records.length; index++) {
      if (this.records[index].date.startsWith(monthPrefix)) {
        totalWeight += this.records[index].weight;
        count += 1;
      }
    }
    if (count <= 0) {
      return '--';
    }
    return `${(totalWeight / count).toFixed(1)} kg`;
  }

  private getMonthChangeText(): string {
    let firstRecord: WeightRecord | undefined = undefined;
    let lastRecord: WeightRecord | undefined = undefined;
    let monthPrefix: string = this.getMonthPrefix();

    for (let index = 0; index < this.records.length; index++) {
      if (!this.records[index].date.startsWith(monthPrefix)) {
        continue;
      }
      if (!firstRecord) {
        firstRecord = this.records[index];
      }
      lastRecord = this.records[index];
    }

    if (!firstRecord || !lastRecord || firstRecord.id === lastRecord.id) {
      return '--';
    }

    let delta: number = lastRecord.weight - firstRecord.weight;
    return `${delta <= 0 ? '下降' : '上升'} ${Math.abs(delta).toFixed(1)} kg`;
  }

  private getMonthLatestRecordText(): string {
    let latestRecord = this.getMonthLatestRecord();
    if (!latestRecord) {
      return '本月暂时还没有体重记录。';
    }
    return `本月最近记录：${latestRecord.date} · ${latestRecord.weight.toFixed(1)} kg`;
  }

  private getWeightRangeDateRange(): string[] {
    let today = new Date();
    let rollingStart = new Date(today.getTime());
    rollingStart.setDate(rollingStart.getDate() - 120);
    let monthStart = new Date(this.calendarYear, this.calendarMonth, 1);
    let monthEnd = new Date(this.calendarYear, this.calendarMonth + 1, 0);
    let startDate = rollingStart.getTime() < monthStart.getTime() ? rollingStart : monthStart;
    let endDate = today.getTime() > monthEnd.getTime() ? today : monthEnd;
    return [formatDate(startDate), formatDate(endDate)];
  }

  private async syncRemoteWeightData(): Promise<void> {
    let authSession = deserializeAuthSession(this.authSessionText);
    if (!isAuthSessionValid(authSession)) {
      return;
    }
    this.remoteSyncing = true;
    try {
      let dateRange = this.getWeightRangeDateRange();
      let remoteRecords = await fetchWeightRecords(this.apiBaseUrlText, authSession, dateRange[0], dateRange[1]);
      this.records = remoteRecords;
      this.weightRecordText = serializeWeightRecords(remoteRecords);
      this.nextId = getNextWeightRecordId(remoteRecords);
      this.remoteSummary = await fetchWeightSummary(this.apiBaseUrlText, authSession, 7);
      this.recordsVersion += 1;
    } catch (error) {
      this.noticeText = `${error}`;
    } finally {
      this.remoteSyncing = false;
    }
  }

  addOrUpdateRecord(): void {
    let dateValue = this.getTodayDate();
    let weightValue = this.weightInput.trim();

    let parsedWeight = Number(weightValue);
    if (isNaN(parsedWeight) || parsedWeight < 20 || parsedWeight > 300) {
      this.noticeText = '体重请输入 20 到 300 之间的数字，例如 68.5。';
      return;
    }

    let updatedRecords: WeightRecord[] = [];
    let hasUpdated = false;

    for (let index = 0; index < this.records.length; index++) {
      let currentRecord = this.records[index];
      if (currentRecord.date === dateValue) {
        updatedRecords.push({
          id: currentRecord.id,
          date: dateValue,
          weight: parsedWeight
        });
        hasUpdated = true;
      } else {
        updatedRecords.push({
          id: currentRecord.id,
          date: currentRecord.date,
          weight: currentRecord.weight
        });
      }
    }

    if (!hasUpdated) {
      updatedRecords.push({
        id: this.nextId,
        date: dateValue,
        weight: parsedWeight
      });
      this.nextId = `${Date.now()}`;
    }

    updatedRecords.sort((left: WeightRecord, right: WeightRecord) => compareRecordDate(left, right));
    this.records = updatedRecords;
    this.weightRecordText = serializeWeightRecords(updatedRecords);
    this.recordsVersion += 1;
    this.weightInput = '';
    this.noticeText = hasUpdated
      ? `已覆盖今天 ${dateValue} 的体重记录。`
      : `已记录今天 ${dateValue} 的体重：${parsedWeight.toFixed(1)} kg。`;
  }

  private async submitWeightRecord(): Promise<void> {
    let dateValue = this.getTodayDate();
    let weightValue = this.weightInput.trim();
    let parsedWeight = Number(weightValue);
    if (isNaN(parsedWeight) || parsedWeight < 20 || parsedWeight > 300) {
      this.noticeText = '体重请输入 20 到 300 之间的数字，例如 68.5。';
      return;
    }

    let authSession = deserializeAuthSession(this.authSessionText);
    if (!isAuthSessionValid(authSession)) {
      this.addOrUpdateRecord();
      return;
    }

    this.remoteSyncing = true;
    try {
      await upsertWeightRecordRemote(this.apiBaseUrlText, authSession, dateValue, parsedWeight);
      this.weightInput = '';
      await this.syncRemoteWeightData();
      this.noticeText = `已同步今天 ${dateValue} 的体重：${parsedWeight.toFixed(1)} kg。`;
    } catch (error) {
      this.noticeText = `${error}`;
    } finally {
      this.remoteSyncing = false;
    }
  }

  @Builder
  buildCalendarOverviewCard() {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 4 }) {
          Text('体重月历')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text('仅做月度概览，录入规则仍然保持只记录今天。')
            .fontSize(12)
            .fontColor(SECONDARY_TEXT_COLOR)
        }
        .alignItems(HorizontalAlign.Start)

        Text(`${this.getMonthRecordCount()} 天已记录`)
          .fontSize(12)
          .fontColor('#6A8AB2')
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('#F2F5FA')
          .borderRadius(999)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)

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
                    .fontWeight(day.isToday ? FontWeight.Bold : FontWeight.Medium)
                    .fontColor(day.isToday ? '#0F6BFF' : (day.isCurrentMonth ? PRIMARY_TEXT_COLOR : '#C8D0DC'))

                  Text(day.isToday && day.isCurrentMonth ? '今' : '')
                    .fontSize(10)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#89AFFF')
                }
                .width('100%')
                .alignItems(HorizontalAlign.Center)
                .margin({ top: 8 })

                if (day.hasRecord && day.isCurrentMonth) {
                  Text('')
                    .width(6)
                    .height(6)
                    .backgroundColor('#8EBBFF')
                    .borderRadius(3)
                    .margin({ top: 37, left: 24 })
                }
              }
              .layoutWeight(1)
              .height(52)
              .backgroundColor(day.isToday ? '#EEF5FF' : '#FFFFFF')
              .borderRadius(14)
              .border({
                width: 1,
                color: day.isToday ? '#CFE2FF' : '#EEF2F7'
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

          Text(`${this.getMonthRecordCount()} 天`)
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
          Text('月均体重')
            .fontSize(11)
            .fontColor('#8A95A5')

          Text(this.getMonthAverageText())
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
          Text('月度变化')
            .fontSize(11)
            .fontColor('#8A95A5')

          Text(this.getMonthChangeText())
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(PRIMARY_TEXT_COLOR)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .padding(12)
        .backgroundColor('#F7F9FD')
        .borderRadius(16)
      }
      .width('100%')

      Text(this.getMonthLatestRecordText())
        .fontSize(12)
        .fontColor('#6A7B91')
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
        Column({ space: 6 }) {
          Text('体重追踪')
            .fontSize(30)
            .fontWeight(FontWeight.Bolder)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text('记录每日体重、观察近 7 次变化，并根据趋势给出简单反馈。')
            .fontSize(14)
            .fontColor(SECONDARY_TEXT_COLOR)
            .lineHeight(22)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')

        Column({ space: 14 }) {
          Row() {
            Column({ space: 8 }) {
              Text('当前体重')
                .fontSize(13)
                .fontColor('#E3EEFF')

              Text(this.getCurrentWeightText())
                .fontSize(28)
                .fontWeight(FontWeight.Bolder)
                .fontColor('#FFFFFF')

              Text(this.getCurrentDateText())
                .fontSize(12)
                .fontColor('#C8DBFF')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)

            Text(this.remoteSyncing ? '同步中' : '近 7 次概览')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor('#C8DBFF')
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor('#2C7CFF')
              .borderRadius(999)
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .alignItems(VerticalAlign.Top)

          Row({ space: 10 }) {
            Column({ space: 4 }) {
              Text('近 7 次')
                .fontSize(11)
                .fontColor('#C8DBFF')

              Text(this.getWeeklyChangeText())
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.getWeeklyChange() <= 0 ? '#B9F7D7' : '#FFD1DC')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            .padding(12)
            .backgroundColor('#2C7CFF')
            .borderRadius(18)

            Column({ space: 4 }) {
              Text('近 7 次均值')
                .fontSize(11)
                .fontColor('#C8DBFF')

              Text(this.getAverageText())
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            .padding(12)
            .backgroundColor('#2C7CFF')
            .borderRadius(18)
          }
          .width('100%')
        }
        .width('100%')
        .padding(18)
        .backgroundColor('#0F6BFF')
        .borderRadius(24)

        this.buildCalendarOverviewCard()

        Column({ space: 14 }) {
          Text('记录今日体重')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_TEXT_COLOR)

          Column({ space: 10 }) {
            Column({ space: 8 }) {
              Row({ space: 6 }) {
                Text('今日')
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#5373A6')

                Text('记录日期')
                  .fontSize(12)
                  .fontColor('#5373A6')
              }

              Text(this.getTodayDate())
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(PRIMARY_TEXT_COLOR)

              Text(`仅支持今天 · ${this.getTodayWeekdayText()}`)
                .fontSize(12)
                .fontColor('#5373A6')
            }
            .alignItems(HorizontalAlign.Start)
            .justifyContent(FlexAlign.Center)
            .width('100%')
            .padding(14)
            .backgroundColor('#F5F8FF')
            .borderRadius(22)

            Column({ space: 8 }) {
              Row({ space: 6 }) {
                Text('录入')
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#5373A6')

                Text('输入体重')
                  .fontSize(12)
                  .fontColor('#5373A6')
              }

              Row({ space: 8 }) {
                TextInput({ placeholder: '68.5', text: this.weightInput })
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(PRIMARY_TEXT_COLOR)
                  .height(46)
                  .width('76%')
                  .padding({ left: 12, right: 12 })
                  .backgroundColor('#FFFFFF')
                  .borderRadius(14)
                  .onChange((value: string) => {
                    this.weightInput = value;
                  })

                Text('kg')
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#0F6BFF')
                  .padding({ left: 10, right: 10, top: 10, bottom: 10 })
                  .backgroundColor('#DCEBFF')
                  .borderRadius(14)
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)

              Text('支持小数，例如 68.5')
                .fontSize(12)
                .fontColor('#5373A6')
            }
            .alignItems(HorizontalAlign.Start)
            .justifyContent(FlexAlign.Center)
            .width('100%')
            .padding(14)
            .backgroundColor('#EAF2FF')
            .borderRadius(22)
          }
          .width('100%')

          Button('记录或更新')
            .width('100%')
            .height(50)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .backgroundColor('#0F6BFF')
            .borderRadius(18)
            .onClick(() => {
              this.submitWeightRecord();
            })

          Text(this.noticeText)
            .fontSize(13)
            .lineHeight(20)
            .fontColor(SECONDARY_TEXT_COLOR)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(18)
        .backgroundColor(SURFACE_BACKGROUND_COLOR)
        .borderRadius(24)

        Column({ space: 14 }) {
          Row() {
            Column({ space: 4 }) {
              Text('近期走势')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor(PRIMARY_TEXT_COLOR)

              Text(`${this.getRecentRecords().length} 条记录`)
                .fontSize(12)
                .fontColor('#94A0B4')
            }
            .alignItems(HorizontalAlign.Start)

            Column({ space: 6 }) {
              Text(`柱顶标签：${this.getRecordTagModeText()}`)
                .fontSize(11)
                .fontColor('#94A0B4')

              Button(this.getRecordTagToggleText())
                .height(32)
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor('#0F6BFF')
                .backgroundColor('#E6F0FF')
                .borderRadius(16)
                .padding({ left: 12, right: 12 })
                .onClick(() => {
                  this.useEmojiTag = !this.useEmojiTag;
                })
            }
            .alignItems(HorizontalAlign.End)
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .alignItems(VerticalAlign.Center)

          Text(`图表范围 ${this.getChartMinWeight().toFixed(1)} kg - ${this.getChartMaxWeight().toFixed(1)} kg`)
            .fontSize(12)
            .fontColor('#94A0B4')

          Row({ space: CHART_BAR_GROUP_SPACING }) {
            ForEach(this.getRecentRecords(), (record: WeightRecord) => {
              Column({ space: 8 }) {
                Text(this.getRecordTag(record))
                  .fontSize(this.getRecordTagFontSize())
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.isLatestRecord(record) ? '#0F6BFF' : '#94A0B4')
                  .maxLines(1)
                  .width('100%')
                  .textAlign(TextAlign.Center)

                Column() {
                  Text('')
                    .width('100%')
                    .height(this.getBarHeight(record))
                    .backgroundColor(this.isLatestRecord(record) ? '#0F6BFF' : '#8CC4FF')
                    .borderRadius(16)
                }
                .width(28)
                .height(CHART_BAR_TRACK_HEIGHT)
                .justifyContent(FlexAlign.End)
                .backgroundColor('#E6F0FF')
                .borderRadius(16)

                Text(this.getShortDate(record.date))
                  .fontSize(11)
                  .fontColor('#94A0B4')

                Text(record.weight.toFixed(1))
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(PRIMARY_TEXT_COLOR)
              }
              .width(CHART_BAR_GROUP_WIDTH)
              .alignItems(HorizontalAlign.Center)
            }, (record: WeightRecord) => this.getRecordRenderKey(record))
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
          .alignItems(VerticalAlign.Bottom)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(18)
        .backgroundColor(SURFACE_BACKGROUND_COLOR)
        .borderRadius(24)

        Column({ space: 10 }) {
          Text(this.getFeedbackTitle())
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.getFeedbackAccentColor())

          Text(this.getFeedbackText())
            .fontSize(14)
            .lineHeight(22)
            .fontColor('#344054')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(18)
        .backgroundColor(this.getFeedbackBackgroundColor())
        .borderRadius(24)

        Column({ space: 12 }) {
          Text('最近记录')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_TEXT_COLOR)

          ForEach(this.getDisplayRecords(), (record: WeightRecord) => {
            Row() {
              Column({ space: 4 }) {
                Text(record.date)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(PRIMARY_TEXT_COLOR)

                Text(this.isLatestRecord(record) ? '当前基准记录' : '历史记录')
                  .fontSize(12)
                  .fontColor('#94A0B4')
              }

              Text(`${record.weight.toFixed(1)} kg`)
                .fontSize(16)
                .fontWeight(FontWeight.Bolder)
                .fontColor(PRIMARY_TEXT_COLOR)
            }
            .width('100%')
            .padding({ top: 8, bottom: 8 })
            .justifyContent(FlexAlign.SpaceBetween)
          }, (record: WeightRecord) => this.getRecordRenderKey(record))
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
  }
}
