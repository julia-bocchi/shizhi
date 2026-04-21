import {
  PAGE_BACKGROUND_COLOR,
  PRIMARY_TEXT_COLOR,
  SECONDARY_TEXT_COLOR,
  SURFACE_BACKGROUND_COLOR
} from '../../constants/AppTheme';
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
import { EXERCISE_STORAGE_READY } from '../../utils/ExerciseStorage';
import { deserializeUserProfile } from '../../utils/ExerciseHelper';
import { formatDate } from '../../utils/WeightRecordHelper';

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
    description: '记录摄入热量',
    tabIndex: FOOD_TAB_INDEX,
    accentColor: '#F59E0B',
    surfaceColor: '#FFF8E8'
  },
  {
    id: 'exercise',
    icon: '动',
    title: '运动',
    description: '累计消耗热量',
    tabIndex: EXERCISE_TAB_INDEX,
    accentColor: '#FF7A59',
    surfaceColor: '#FFF1EC'
  },
  {
    id: 'record',
    icon: '重',
    title: '记录',
    description: '查看体重变化',
    tabIndex: RECORD_TAB_INDEX,
    accentColor: '#14B8A6',
    surfaceColor: '#ECFFFB'
  },
  {
    id: 'assistant',
    icon: 'AI',
    title: '助手',
    description: '生成今日建议',
    tabIndex: AI_TAB_INDEX,
    accentColor: '#7B61FF',
    surfaceColor: '#F4F0FF'
  }
];

@Component
export struct HomeTabPage {
  @Link currentTabIndex: number;
  @StorageLink('foodPlanText') foodPlanText: string = '';
  @StorageLink('workoutRecordText') workoutRecordText: string = '';
  @StorageLink('weightRecordText') weightRecordText: string = '';
  @StorageLink('userProfileText') userProfileText: string = '';
  @StorageLink('dailyFoodCalorieTargetText') dailyFoodCalorieTargetText: string = '';

  aboutToAppear(): void {
    EXERCISE_STORAGE_READY;
  }

  private getTodayText(): string {
    return formatDate(new Date());
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

  private getUserHeadline(): string {
    let profile = deserializeUserProfile(this.userProfileText);
    if (profile.nickname.trim().length > 0) {
      return `${profile.nickname.trim()} 的今日概览`;
    }
    return '今日健康概览';
  }

  private getNetCalorieAccentColor(): string {
    let summary = this.getCalorieSummary();
    if (summary.intakeCalories <= 0 && summary.burnedCalories <= 0) {
      return '#0F6BFF';
    }
    if (summary.netCalories <= 0) {
      return '#10B981';
    }
    if (summary.netCalories <= 350) {
      return '#0F6BFF';
    }
    return '#FF7A59';
  }

  private getNetCalorieSurfaceColor(): string {
    let summary = this.getCalorieSummary();
    if (summary.intakeCalories <= 0 && summary.burnedCalories <= 0) {
      return '#20456E';
    }
    if (summary.netCalories <= 0) {
      return '#174238';
    }
    if (summary.netCalories <= 350) {
      return '#20456E';
    }
    return '#5B2F2D';
  }

  private getNetCalorieTitleText(): string {
    let summary = this.getCalorieSummary();
    if (summary.intakeCalories <= 0 && summary.burnedCalories <= 0) {
      return '今日还没有热量记录';
    }
    if (summary.netCalories < 0) {
      return '净热量已经转负';
    }
    if (summary.netCalories === 0) {
      return '净热量刚好持平';
    }
    return '当前净热量';
  }

  private getNetCalorieDescriptionText(): string {
    let summary = this.getCalorieSummary();
    if (summary.intakeCalories <= 0 && summary.burnedCalories <= 0) {
      return '先去记录饮食或训练，首页会自动同步数据。';
    }
    if (summary.netCalories < 0) {
      return `今天的训练消耗比摄入多 ${Math.round(Math.abs(summary.netCalories))} kcal。`;
    }
    if (summary.netCalories === 0) {
      return '今天摄入和消耗目前相等。';
    }
    return `摄入减去消耗后，还剩 ${Math.round(summary.netCalories)} kcal。`;
  }

  private getTargetStatusText(): string {
    let summary = this.getCalorieSummary();
    if (summary.intakeCalories <= 0) {
      return `今日目标 ${summary.targetCalories} kcal`;
    }
    if (summary.remainingTargetCalories >= 0) {
      return `距离今日饮食目标还差 ${Math.round(summary.remainingTargetCalories)} kcal`;
    }
    return `已超过今日饮食目标 ${Math.round(Math.abs(summary.remainingTargetCalories))} kcal`;
  }

  private getProgressWidthText(): string {
    let summary = this.getCalorieSummary();
    let ratio = Math.round(summary.intakeProgress * 100);
    if (ratio <= 0) {
      return '0%';
    }
    if (ratio < 10) {
      return '10%';
    }
    return `${ratio}%`;
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
    let trendSummary = this.getWeightTrendSummary();
    if (!trendSummary.latestRecord) {
      return '--';
    }
    return `${trendSummary.latestRecord.weight.toFixed(1)} kg`;
  }

  private getWeightChangeText(): string {
    let trendSummary = this.getWeightTrendSummary();
    if (trendSummary.recentRecords.length < 2) {
      return '继续记录形成趋势';
    }
    let directionText: string = trendSummary.changeValue <= 0 ? '下降' : '上升';
    return `${directionText} ${Math.abs(trendSummary.changeValue).toFixed(1)} kg`;
  }

  private getWeightSublineText(): string {
    let trendSummary = this.getWeightTrendSummary();
    if (!trendSummary.latestRecord) {
      return '还没有体重记录';
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
      return 58;
    }
    let ratio = (record.weight - minValue) / range;
    return 34 + Math.round(ratio * 54);
  }

  private getWeightBarColor(record: WeightRecord): string {
    let trendSummary = this.getWeightTrendSummary();
    if (trendSummary.latestRecord && trendSummary.latestRecord.id === record.id) {
      return '#0F6BFF';
    }
    return '#93C5FD';
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
      if (calorieSummary.intakeCalories > 0) {
        return `已记录 ${Math.round(calorieSummary.intakeCalories)} kcal`;
      }
      return '今天还没记饮食';
    }
    if (entryId === 'exercise') {
      if (calorieSummary.burnedCalories > 0) {
        return `已消耗 ${Math.round(calorieSummary.burnedCalories)} kcal`;
      }
      return '今天还没训练';
    }
    if (entryId === 'record') {
      if (trendSummary.hasTodayRecord && trendSummary.latestRecord) {
        return `今日 ${trendSummary.latestRecord.weight.toFixed(1)} kg`;
      }
      return '今天还没记体重';
    }
    if (this.getReminderItems()[0].id === 'assistant') {
      return '数据已齐，可以直接分析';
    }
    return '根据今天的记录给建议';
  }

  @Builder
  private buildOverviewCard() {
    Column({ space: 16 }) {
      Row() {
        Column({ space: 4 }) {
          Text(this.getUserHeadline())
            .fontSize(24)
            .fontWeight(FontWeight.Bolder)
            .fontColor('#FFFFFF')

          Text(this.getTodayText())
            .fontSize(12)
            .fontColor('#D3E2F5')
        }
        .alignItems(HorizontalAlign.Start)

        Text('今日总览')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(this.getNetCalorieAccentColor())
          .borderRadius(999)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Top)

      Column({ space: 8 }) {
        Text(this.getNetCalorieTitleText())
          .fontSize(13)
          .fontColor('#BCD1E8')

        Row({ space: 8 }) {
          Text(`${Math.round(this.getCalorieSummary().netCalories)}`)
            .fontSize(42)
            .fontWeight(FontWeight.Bolder)
            .fontColor('#FFFFFF')

          Text('kcal')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#D8E6F7')
            .margin({ top: 22 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)

        Text(this.getNetCalorieDescriptionText())
          .fontSize(13)
          .lineHeight(20)
          .fontColor('#D8E6F7')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      Row({ space: 12 }) {
        Column({ space: 6 }) {
          Text('摄入热量')
            .fontSize(12)
            .fontColor('#A7BED9')

          Text(`${Math.round(this.getCalorieSummary().intakeCalories)} kcal`)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .padding(14)
        .backgroundColor(this.getNetCalorieSurfaceColor())
        .borderRadius(20)

        Column({ space: 6 }) {
          Text('消耗热量')
            .fontSize(12)
            .fontColor('#A7BED9')

          Text(`${Math.round(this.getCalorieSummary().burnedCalories)} kcal`)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .padding(14)
        .backgroundColor(this.getNetCalorieSurfaceColor())
        .borderRadius(20)
      }
      .width('100%')

      Column({ space: 8 }) {
        Row() {
          Text(`饮食目标 ${this.getCalorieSummary().targetCalories} kcal`)
            .fontSize(12)
            .fontColor('#D8E6F7')
            .layoutWeight(1)

          Text(this.getTargetStatusText())
            .fontSize(12)
            .fontColor('#D8E6F7')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')

        Stack({ alignContent: Alignment.Start }) {
          Text('')
            .width('100%')
            .height(8)
            .backgroundColor('#2E4D71')
            .borderRadius(999)

          Text('')
            .width(this.getProgressWidthText())
            .height(8)
            .backgroundColor(this.getNetCalorieAccentColor())
            .borderRadius(999)
        }
        .width('100%')
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(20)
    .backgroundColor('#17324D')
    .borderRadius(28)
  }

  @Builder
  private buildWeightTrendCard() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 4 }) {
          Text('体重变化趋势')
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
          .fontColor('#0F6BFF')
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('#EAF2FF')
          .borderRadius(999)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 12 }) {
        Column({ space: 6 }) {
          Text('最新体重')
            .fontSize(12)
            .fontColor('#5373A6')

          Text(this.getLatestWeightText())
            .fontSize(26)
            .fontWeight(FontWeight.Bolder)
            .fontColor(PRIMARY_TEXT_COLOR)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .padding(14)
        .backgroundColor('#F5F8FF')
        .borderRadius(20)

        Column({ space: 6 }) {
          Text('近 7 次变化')
            .fontSize(12)
            .fontColor('#5373A6')

          Text(this.getWeightChangeText())
            .fontSize(22)
            .fontWeight(FontWeight.Bolder)
            .fontColor(this.getWeightTrendSummary().changeValue <= 0 ? '#10B981' : '#FF7A59')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .padding(14)
        .backgroundColor('#EEF4FF')
        .borderRadius(20)
      }
      .width('100%')

      if (this.getWeightTrendSummary().recentRecords.length > 0) {
        Row({ space: 10 }) {
          ForEach(this.getWeightTrendSummary().recentRecords, (record: WeightRecord) => {
            Column({ space: 8 }) {
              Column() {
                Text('')
                  .width('100%')
                  .height(this.getWeightBarHeight(record))
                  .backgroundColor(this.getWeightBarColor(record))
                  .borderRadius(12)
              }
              .width(24)
              .height(92)
              .justifyContent(FlexAlign.End)
              .backgroundColor('#EAF2FF')
              .borderRadius(12)

              Text(this.getWeightShortDate(record.date))
                .fontSize(10)
                .fontColor('#94A0B4')

              Text(record.weight.toFixed(1))
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(PRIMARY_TEXT_COLOR)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
          }, (record: WeightRecord) => `${record.id}`)
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
          .backgroundColor('#F5F8FF')
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
  private buildQuickEntryItem(entry: HomeQuickEntryItem) {
    Button() {
      Column({ space: 10 }) {
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

        Column({ space: 4 }) {
          Text(entry.title)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(PRIMARY_TEXT_COLOR)

          Text(entry.description)
            .fontSize(11)
            .fontColor(SECONDARY_TEXT_COLOR)

          Text(this.getQuickEntryStatusText(entry.id))
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(entry.accentColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
    }
    .layoutWeight(1)
    .padding(16)
    .backgroundColor(entry.surfaceColor)
    .borderRadius(20)
    .onClick(() => {
      this.openTab(entry.tabIndex);
    })
  }

  @Builder
  private buildQuickEntryCard() {
    Column({ space: 12 }) {
      Column({ space: 4 }) {
        Text('常用入口')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(PRIMARY_TEXT_COLOR)

        Text('从首页直接进入常用页面。')
          .fontSize(12)
          .fontColor(SECONDARY_TEXT_COLOR)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      Row({ space: 12 }) {
        this.buildQuickEntryItem(HOME_QUICK_ENTRIES[0])
        this.buildQuickEntryItem(HOME_QUICK_ENTRIES[1])
      }
      .width('100%')

      Row({ space: 12 }) {
        this.buildQuickEntryItem(HOME_QUICK_ENTRIES[2])
        this.buildQuickEntryItem(HOME_QUICK_ENTRIES[3])
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
  private buildReminderCard() {
    Column({ space: 12 }) {
      Column({ space: 4 }) {
        Text('今日提醒')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(PRIMARY_TEXT_COLOR)

        Text('优先处理最影响首页数据完整度的几项。')
          .fontSize(12)
          .fontColor(SECONDARY_TEXT_COLOR)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      ForEach(this.getReminderItems(), (item: HomeReminderItem) => {
        Button() {
          Row({ space: 12 }) {
            Text('')
              .width(10)
              .height(10)
              .backgroundColor(item.accentColor)
              .borderRadius(5)

            Column({ space: 4 }) {
              Text(item.title)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(PRIMARY_TEXT_COLOR)

              Text(item.description)
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
              .fontColor(item.accentColor)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor('#FFFFFF')
              .borderRadius(999)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .padding(14)
        .backgroundColor('#F7FAFF')
        .borderRadius(18)
        .onClick(() => {
          this.openTab(item.targetTabIndex);
        })
      }, (item: HomeReminderItem) => item.id)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(18)
    .backgroundColor(SURFACE_BACKGROUND_COLOR)
    .borderRadius(24)
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        this.buildOverviewCard()
        this.buildWeightTrendCard()
        this.buildQuickEntryCard()
        this.buildReminderCard()
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
