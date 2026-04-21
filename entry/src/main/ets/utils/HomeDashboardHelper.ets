import {
  AI_TAB_INDEX,
  EXERCISE_TAB_INDEX,
  FOOD_TAB_INDEX,
  PROFILE_TAB_INDEX,
  RECORD_TAB_INDEX
} from '../models/TabItem';
import { WeightRecord } from '../models/WeightRecord';
import {
  deserializeUserProfile,
  deserializeWorkoutRecords,
  getMissingProfileFields
} from './ExerciseHelper';
import { deserializeFoodPlans } from './FoodHelper';
import {
  deserializeWeightRecords,
  formatDate,
  getAverageWeight,
  getLatestWeightRecord,
  getRecentWeightRecords,
  getWeightChange
} from './WeightRecordHelper';

const DEFAULT_DAILY_CALORIE_TARGET: number = 2000;

export interface HomeDashboardCaloriesSummary {
  intakeCalories: number;
  burnedCalories: number;
  netCalories: number;
  targetCalories: number;
  remainingTargetCalories: number;
  intakeProgress: number;
}

export interface HomeWeightTrendSummary {
  recentRecords: WeightRecord[];
  latestRecord?: WeightRecord;
  changeValue: number;
  averageWeight: number;
  hasTodayRecord: boolean;
}

export interface HomeReminderItem {
  id: string;
  title: string;
  description: string;
  targetTabIndex: number;
  accentColor: string;
}

function getDailyCalorieTarget(targetText: string): number {
  let targetValue: number = Number(targetText.trim());
  if (isNaN(targetValue) || targetValue <= 0) {
    return DEFAULT_DAILY_CALORIE_TARGET;
  }
  return targetValue;
}

export function getTodayDashboardCalories(
  foodPlanText: string,
  workoutRecordText: string,
  dailyFoodCalorieTargetText: string,
  todayText: string = formatDate(new Date())
): HomeDashboardCaloriesSummary {
  let intakeCalories: number = 0;
  let burnedCalories: number = 0;
  let targetCalories: number = getDailyCalorieTarget(dailyFoodCalorieTargetText);

  let foodPlans = deserializeFoodPlans(foodPlanText);
  for (let index = 0; index < foodPlans.length; index++) {
    if (foodPlans[index].date === todayText) {
      intakeCalories += foodPlans[index].calories;
    }
  }

  let workoutRecords = deserializeWorkoutRecords(workoutRecordText);
  for (let index = 0; index < workoutRecords.length; index++) {
    if (workoutRecords[index].date === todayText) {
      burnedCalories += workoutRecords[index].calories;
    }
  }

  let intakeProgress: number = intakeCalories / targetCalories;
  if (intakeProgress < 0) {
    intakeProgress = 0;
  }
  if (intakeProgress > 1) {
    intakeProgress = 1;
  }

  return {
    intakeCalories: intakeCalories,
    burnedCalories: burnedCalories,
    netCalories: intakeCalories - burnedCalories,
    targetCalories: targetCalories,
    remainingTargetCalories: targetCalories - intakeCalories,
    intakeProgress: intakeProgress
  };
}

export function getHomeWeightTrend(
  weightRecordText: string,
  todayText: string = formatDate(new Date()),
  limit: number = 7
): HomeWeightTrendSummary {
  let records = deserializeWeightRecords(weightRecordText);
  let recentRecords = getRecentWeightRecords(records, limit);
  let latestRecord = getLatestWeightRecord(records);
  let hasTodayRecord: boolean = false;
  if (latestRecord) {
    hasTodayRecord = latestRecord.date === todayText;
  }

  return {
    recentRecords: recentRecords,
    latestRecord: latestRecord,
    changeValue: getWeightChange(recentRecords),
    averageWeight: getAverageWeight(recentRecords),
    hasTodayRecord: hasTodayRecord
  };
}

export function getHomeReminderItems(
  userProfileText: string,
  foodPlanText: string,
  workoutRecordText: string,
  weightRecordText: string,
  todayText: string = formatDate(new Date())
): HomeReminderItem[] {
  let reminderItems: HomeReminderItem[] = [];
  let profile = deserializeUserProfile(userProfileText);
  let missingFields = getMissingProfileFields(profile);
  let calorieSummary = getTodayDashboardCalories(foodPlanText, workoutRecordText, '', todayText);
  let weightTrend = getHomeWeightTrend(weightRecordText, todayText);

  if (missingFields.length > 0) {
    reminderItems.push({
      id: 'profile',
      title: '完善个人资料',
      description: `还缺少：${missingFields.join('、')}`,
      targetTabIndex: PROFILE_TAB_INDEX,
      accentColor: '#0F6BFF'
    });
  }

  if (!weightTrend.hasTodayRecord) {
    reminderItems.push({
      id: 'record',
      title: '记录今日体重',
      description: '补上今天的体重，趋势才会更完整',
      targetTabIndex: RECORD_TAB_INDEX,
      accentColor: '#14B8A6'
    });
  }

  if (calorieSummary.intakeCalories <= 0) {
    reminderItems.push({
      id: 'food',
      title: '补充今日饮食',
      description: '先记一餐，首页才能显示摄入热量',
      targetTabIndex: FOOD_TAB_INDEX,
      accentColor: '#F59E0B'
    });
  }

  if (calorieSummary.burnedCalories <= 0) {
    reminderItems.push({
      id: 'exercise',
      title: '开始一次训练',
      description: '完成训练后会自动累计今日消耗',
      targetTabIndex: EXERCISE_TAB_INDEX,
      accentColor: '#FF7A59'
    });
  }

  if (reminderItems.length === 0) {
    reminderItems.push({
      id: 'assistant',
      title: '查看今日建议',
      description: '数据已经齐了，可以去 AI 助手做分析',
      targetTabIndex: AI_TAB_INDEX,
      accentColor: '#7B61FF'
    });
  }

  if (reminderItems.length <= 3) {
    return reminderItems;
  }
  return reminderItems.slice(0, 3);
}
