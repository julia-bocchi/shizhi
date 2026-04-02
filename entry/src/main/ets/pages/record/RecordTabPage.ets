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
  createSampleRecords,
  formatDate,
  roundDownToStep,
  roundUpToStep
} from '../../utils/WeightRecordHelper';

@Component
export struct RecordTabPage {
  @State records: WeightRecord[] = [];
  @State weightInput: string = '';
  @State noticeText: string = '只能记录今天的体重；当天多次提交会覆盖当天记录。';
  @State nextId: number = 1;
  @State useEmojiTag: boolean = true;
  // 记录更新后递增版本号，确保列表 key 能稳定刷新。
  @State recordsVersion: number = 0;

  aboutToAppear(): void {
    if (this.records.length === 0) {
      this.records = createSampleRecords();
      this.nextId = this.records.length + 1;
    }
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
    let recentRecords = this.getRecentRecords();
    if (recentRecords.length < 2) {
      return 0;
    }
    return recentRecords[recentRecords.length - 1].weight - recentRecords[0].weight;
  }

  getTodayChange(): number {
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
      return '#EAF5EE';
    }
    if (weeklyChange >= 0.5) {
      return '#FFF1E8';
    }
    return '#EEF3FF';
  }

  getFeedbackAccentColor(): string {
    let weeklyChange = this.getWeeklyChange();
    if (weeklyChange <= -0.5) {
      return '#2E8B57';
    }
    if (weeklyChange >= 0.5) {
      return '#D86C3D';
    }
    return '#2F6FED';
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
      this.nextId += 1;
    }

    updatedRecords.sort((left: WeightRecord, right: WeightRecord) => compareRecordDate(left, right));
    this.records = updatedRecords;
    this.recordsVersion += 1;
    this.weightInput = '';
    this.noticeText = hasUpdated
      ? `已覆盖今天 ${dateValue} 的体重记录。`
      : `已记录今天 ${dateValue} 的体重：${parsedWeight.toFixed(1)} kg。`;
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

        Column({ space: 12 }) {
          Column({ space: 8 }) {
            Text('当前体重')
              .fontSize(13)
              .fontColor('#D8E5FF')

            Text(this.getCurrentWeightText())
              .fontSize(26)
              .fontWeight(FontWeight.Bolder)
              .fontColor('#FFFFFF')

            Text(this.getCurrentDateText())
              .fontSize(12)
              .fontColor('#B7CAE8')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .width('100%')
          .backgroundColor('#17324D')
          .borderRadius(24)

          Column({ space: 8 }) {
            Text('近 7 次变化')
              .fontSize(13)
              .fontColor('#7A5C2E')

            Text(this.getWeeklyChangeText())
              .fontSize(26)
              .fontWeight(FontWeight.Bolder)
              .fontColor(this.getWeeklyChange() <= 0 ? '#246B45' : '#C95F34')

            Text(`平均体重 ${this.getAverageText()}`)
              .fontSize(12)
              .fontColor('#816A47')
          }
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .width('100%')
          .backgroundColor('#F2E7D8')
          .borderRadius(24)
        }
        .width('100%')

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
                  .fontColor('#866A45')

                Text('记录日期')
                  .fontSize(12)
                  .fontColor('#866A45')
              }

              Text(this.getTodayDate())
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(PRIMARY_TEXT_COLOR)

              Text(`仅支持今天 · ${this.getTodayWeekdayText()}`)
                .fontSize(12)
                .fontColor('#866A45')
            }
            .alignItems(HorizontalAlign.Start)
            .justifyContent(FlexAlign.Center)
            .width('100%')
            .padding(14)
            .backgroundColor('#F8EEDC')
            .borderRadius(22)

            Column({ space: 8 }) {
              Row({ space: 6 }) {
                Text('录入')
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#4F6690')

                Text('输入体重')
                  .fontSize(12)
                  .fontColor('#4F6690')
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
                  .fontColor('#2F6FED')
                  .padding({ left: 10, right: 10, top: 10, bottom: 10 })
                  .backgroundColor('#DCE8FF')
                  .borderRadius(14)
              }
              .width('100%')
              .justifyContent(FlexAlign.SpaceBetween)

              Text('支持小数，例如 68.5')
                .fontSize(12)
                .fontColor('#4F6690')
            }
            .alignItems(HorizontalAlign.Start)
            .justifyContent(FlexAlign.Center)
            .width('100%')
            .padding(14)
            .backgroundColor('#EAF1FF')
            .borderRadius(22)
          }
          .width('100%')

          Button('记录或更新')
            .width('100%')
            .height(50)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .backgroundColor('#2F6FED')
            .borderRadius(18)
            .onClick(() => {
              this.addOrUpdateRecord();
            })

          Text(this.noticeText)
            .fontSize(13)
            .lineHeight(20)
            .fontColor('#5D6B7A')
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
                .fontColor('#7D8794')
            }
            .alignItems(HorizontalAlign.Start)

            Column({ space: 6 }) {
              Text(`柱顶标签：${this.getRecordTagModeText()}`)
                .fontSize(11)
                .fontColor('#7D8794')

              Button(this.getRecordTagToggleText())
                .height(32)
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor('#17324D')
                .backgroundColor('#E7EEF9')
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
            .fontColor('#7D8794')

          Row() {
            ForEach(this.getRecentRecords(), (record: WeightRecord) => {
              Column({ space: 8 }) {
                Text(this.getRecordTag(record))
                  .fontSize(this.getRecordTagFontSize())
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.isLatestRecord(record) ? '#2F6FED' : '#7D8794')
                  .maxLines(1)
                  .width('100%')
                  .textAlign(TextAlign.Center)

                Column() {
                  Text('')
                    .width('100%')
                    .height(this.getBarHeight(record))
                    .backgroundColor(this.isLatestRecord(record) ? '#2F6FED' : '#8EB4FF')
                    .borderRadius(16)
                }
                .width(28)
                .height(CHART_BAR_TRACK_HEIGHT)
                .justifyContent(FlexAlign.End)
                .backgroundColor('#E8EEF9')
                .borderRadius(16)

                Text(this.getShortDate(record.date))
                  .fontSize(11)
                  .fontColor('#7D8794')

                Text(record.weight.toFixed(1))
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(PRIMARY_TEXT_COLOR)
              }
              .width(40)
              .alignItems(HorizontalAlign.Center)
            }, (record: WeightRecord) => this.getRecordRenderKey(record))
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
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
                  .fontColor('#7D8794')
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
