import { FoodPlanItem } from '../models/FoodPlan';
import { WeightRecord } from '../models/WeightRecord';
import { WorkoutPlanItem } from '../models/WorkoutPlan';
import { WorkoutRecord } from '../models/WorkoutRecord';
import { EXERCISE_TAB_INDEX, FOOD_TAB_INDEX, RECORD_TAB_INDEX } from '../models/TabItem';
import { deserializeFoodPlans } from './FoodHelper';
import { deserializeWorkoutPlans } from './WorkoutPlanHelper';
import { deserializeWorkoutRecords } from './ExerciseHelper';
import {
  deserializeWeightRecords,
  getAverageWeight,
  getLatestWeightRecord,
  getRecentWeightRecords,
  getWeightChange
} from './WeightRecordHelper';

const DEFAULT_DAILY_CALORIE_TARGET: number = 2000;
const AI_CACHE_LIMIT: number = 7;

export interface DailyBriefingSummary {
  date: string;
  intakeCalories: number;
  burnedCalories: number;
  netCalories: number;
  targetCalories: number;
  remainingTargetCalories: number;
  mealPlanCount: number;
  mealTypeCount: number;
  workoutPlanCount: number;
  completedWorkoutPlanCount: number;
  pendingWorkoutPlanCount: number;
  latestWeightText: string;
  weightTrendText: string;
  calorieStatusText: string;
  foodStatusText: string;
  workoutStatusText: string;
  primaryAdvice: string;
  localBriefingText: string;
  speechText: string;
  suggestedActionText: string;
  suggestedActionTabIndex: number;
}

export interface DailyBriefingAiCacheRecord {
  date: string;
  text: string;
  updatedAt: number;
}

function sanitizeString(value: string | number | boolean | undefined | null, fallbackValue: string = ''): string {
  if (value === undefined || value === null) {
    return fallbackValue;
  }
  return `${value}`;
}

function sanitizeNumber(value: string | number | boolean | undefined | null, fallbackValue: number = 0): number {
  if (typeof value === 'number') {
    return isNaN(value) ? fallbackValue : value;
  }
  if (value === undefined || value === null) {
    return fallbackValue;
  }
  let parsedValue: number = Number(`${value}`);
  return isNaN(parsedValue) ? fallbackValue : parsedValue;
}

function getDailyCalorieTarget(targetText: string): number {
  let targetValue: number = Number(targetText.trim());
  if (isNaN(targetValue) || targetValue <= 0) {
    return DEFAULT_DAILY_CALORIE_TARGET;
  }
  return targetValue;
}

function getTodayFoodPlans(foodPlanText: string, todayText: string): FoodPlanItem[] {
  let plans = deserializeFoodPlans(foodPlanText);
  let result: FoodPlanItem[] = [];
  for (let index = 0; index < plans.length; index++) {
    if (plans[index].date === todayText) {
      result.push(plans[index]);
    }
  }
  return result;
}

function getTodayWorkoutPlans(workoutPlanText: string, todayText: string): WorkoutPlanItem[] {
  let plans = deserializeWorkoutPlans(workoutPlanText);
  let result: WorkoutPlanItem[] = [];
  for (let index = 0; index < plans.length; index++) {
    if (plans[index].date === todayText) {
      result.push(plans[index]);
    }
  }
  return result;
}

function getTodayWorkoutRecords(workoutRecordText: string, todayText: string): WorkoutRecord[] {
  let records = deserializeWorkoutRecords(workoutRecordText);
  let result: WorkoutRecord[] = [];
  for (let index = 0; index < records.length; index++) {
    if (records[index].date === todayText) {
      result.push(records[index]);
    }
  }
  return result;
}

function getMealTypeCount(plans: FoodPlanItem[]): number {
  let mealTypes: string[] = [];
  for (let index = 0; index < plans.length; index++) {
    let mealType = plans[index].mealType.trim();
    if (mealType.length === 0) {
      continue;
    }
    if (mealTypes.indexOf(mealType) < 0) {
      mealTypes.push(mealType);
    }
  }
  return mealTypes.length;
}

function getIntakeCalories(plans: FoodPlanItem[]): number {
  let calories: number = 0;
  for (let index = 0; index < plans.length; index++) {
    calories += plans[index].calories;
  }
  return calories;
}

function getBurnedCalories(records: WorkoutRecord[]): number {
  let calories: number = 0;
  for (let index = 0; index < records.length; index++) {
    calories += records[index].calories;
  }
  return calories;
}

function isWorkoutPlanCompleted(plan: WorkoutPlanItem, records: WorkoutRecord[]): boolean {
  if (plan.manuallyCompleted) {
    return true;
  }
  for (let index = 0; index < records.length; index++) {
    if (records[index].planId === plan.id) {
      return true;
    }
  }
  return false;
}

function getCompletedWorkoutPlanCount(plans: WorkoutPlanItem[], records: WorkoutRecord[]): number {
  let count: number = 0;
  for (let index = 0; index < plans.length; index++) {
    if (isWorkoutPlanCompleted(plans[index], records)) {
      count += 1;
    }
  }
  return count;
}

function buildCalorieStatusText(intakeCalories: number, burnedCalories: number, targetCalories: number): string {
  if (intakeCalories <= 0 && burnedCalories <= 0) {
    return `目标 ${targetCalories} kcal，今天还没有记录。`;
  }
  let remaining = targetCalories - intakeCalories;
  if (remaining >= 0) {
    return `已摄入 ${Math.round(intakeCalories)} kcal，距目标还差 ${Math.round(remaining)} kcal。`;
  }
  return `已摄入 ${Math.round(intakeCalories)} kcal，超过目标 ${Math.round(Math.abs(remaining))} kcal。`;
}

function buildFoodStatusText(mealPlanCount: number, mealTypeCount: number): string {
  if (mealPlanCount <= 0) {
    return '今天还没有饮食计划。';
  }
  if (mealTypeCount >= 3) {
    return `已安排 ${mealTypeCount} 个餐次，饮食计划比较完整。`;
  }
  return `已安排 ${mealTypeCount} 个餐次，晚些时候可以补齐剩余餐次。`;
}

function buildWorkoutStatusText(planCount: number, completedCount: number): string {
  if (planCount <= 0) {
    return '今天还没有训练计划。';
  }
  if (completedCount >= planCount) {
    return `今天 ${planCount} 项训练计划已完成。`;
  }
  return `今天有 ${planCount} 项训练计划，还有 ${planCount - completedCount} 项待完成。`;
}

function buildWeightTrendText(weightRecordText: string): string {
  let records: WeightRecord[] = deserializeWeightRecords(weightRecordText);
  let recentRecords: WeightRecord[] = getRecentWeightRecords(records, 7);
  let latestRecord = getLatestWeightRecord(records);
  if (!latestRecord) {
    return '还没有体重记录。';
  }
  if (recentRecords.length < 2) {
    return `最新体重 ${latestRecord.weight.toFixed(1)} kg，继续记录后会形成趋势。`;
  }
  let changeValue = getWeightChange(recentRecords);
  let averageWeight = getAverageWeight(recentRecords);
  if (changeValue <= -0.3) {
    return `近 7 次下降 ${Math.abs(changeValue).toFixed(1)} kg，均值 ${averageWeight.toFixed(1)} kg。`;
  }
  if (changeValue >= 0.3) {
    return `近 7 次上升 ${Math.abs(changeValue).toFixed(1)} kg，均值 ${averageWeight.toFixed(1)} kg。`;
  }
  return `近 7 次基本平稳，均值 ${averageWeight.toFixed(1)} kg。`;
}

function buildLatestWeightText(weightRecordText: string): string {
  let latestRecord = getLatestWeightRecord(deserializeWeightRecords(weightRecordText));
  if (!latestRecord) {
    return '--';
  }
  return `${latestRecord.weight.toFixed(1)} kg`;
}

function buildPrimaryAdvice(intakeCalories: number, targetCalories: number, mealPlanCount: number,
  workoutPlanCount: number, pendingWorkoutPlanCount: number, weightTrendText: string): string {
  if (mealPlanCount <= 0) {
    return '先补充今天的饮食计划，智卡才能判断摄入是否合理。';
  }
  if (intakeCalories > targetCalories + 100) {
    return '今天摄入已经超过目标，后续餐次建议以清淡蛋白和蔬菜为主。';
  }
  if (pendingWorkoutPlanCount > 0) {
    return '优先完成今天未结束的训练计划，再根据体感决定是否加量。';
  }
  if (workoutPlanCount <= 0) {
    return '今天还没有训练安排，可以加入一次 20 到 30 分钟的低强度运动。';
  }
  if (weightTrendText.indexOf('上升') >= 0 && intakeCalories >= targetCalories * 0.8) {
    return '近期体重有回升迹象，今天先稳住摄入目标，不要再额外加餐。';
  }
  return '今天的饮食和训练节奏比较清晰，继续按计划执行即可。';
}

function buildSuggestedActionTabIndex(mealPlanCount: number, pendingWorkoutPlanCount: number,
  workoutPlanCount: number): number {
  if (mealPlanCount <= 0) {
    return FOOD_TAB_INDEX;
  }
  if (pendingWorkoutPlanCount > 0 || workoutPlanCount <= 0) {
    return EXERCISE_TAB_INDEX;
  }
  return RECORD_TAB_INDEX;
}

function buildSuggestedActionText(targetTabIndex: number): string {
  if (targetTabIndex === FOOD_TAB_INDEX) {
    return '去调整饮食';
  }
  if (targetTabIndex === EXERCISE_TAB_INDEX) {
    return '去调整训练';
  }
  return '去记录体重';
}

export function buildDailyBriefingSummary(foodPlanText: string, workoutPlanText: string,
  workoutRecordText: string, weightRecordText: string, dailyFoodCalorieTargetText: string,
  todayText: string): DailyBriefingSummary {
  let todayFoodPlans = getTodayFoodPlans(foodPlanText, todayText);
  let todayWorkoutPlans = getTodayWorkoutPlans(workoutPlanText, todayText);
  let todayWorkoutRecords = getTodayWorkoutRecords(workoutRecordText, todayText);
  let targetCalories = getDailyCalorieTarget(dailyFoodCalorieTargetText);
  let intakeCalories = getIntakeCalories(todayFoodPlans);
  let burnedCalories = getBurnedCalories(todayWorkoutRecords);
  let mealTypeCount = getMealTypeCount(todayFoodPlans);
  let completedWorkoutPlanCount = getCompletedWorkoutPlanCount(todayWorkoutPlans, todayWorkoutRecords);
  let pendingWorkoutPlanCount = Math.max(0, todayWorkoutPlans.length - completedWorkoutPlanCount);
  let weightTrendText = buildWeightTrendText(weightRecordText);
  let primaryAdvice = buildPrimaryAdvice(
    intakeCalories,
    targetCalories,
    todayFoodPlans.length,
    todayWorkoutPlans.length,
    pendingWorkoutPlanCount,
    weightTrendText
  );
  let suggestedActionTabIndex = buildSuggestedActionTabIndex(
    todayFoodPlans.length,
    pendingWorkoutPlanCount,
    todayWorkoutPlans.length
  );
  let calorieStatusText = buildCalorieStatusText(intakeCalories, burnedCalories, targetCalories);
  let foodStatusText = buildFoodStatusText(todayFoodPlans.length, mealTypeCount);
  let workoutStatusText = buildWorkoutStatusText(todayWorkoutPlans.length, completedWorkoutPlanCount);
  let localBriefingText = `${calorieStatusText}${foodStatusText}${workoutStatusText}${weightTrendText}${primaryAdvice}`;

  return {
    date: todayText,
    intakeCalories: intakeCalories,
    burnedCalories: burnedCalories,
    netCalories: intakeCalories - burnedCalories,
    targetCalories: targetCalories,
    remainingTargetCalories: targetCalories - intakeCalories,
    mealPlanCount: todayFoodPlans.length,
    mealTypeCount: mealTypeCount,
    workoutPlanCount: todayWorkoutPlans.length,
    completedWorkoutPlanCount: completedWorkoutPlanCount,
    pendingWorkoutPlanCount: pendingWorkoutPlanCount,
    latestWeightText: buildLatestWeightText(weightRecordText),
    weightTrendText: weightTrendText,
    calorieStatusText: calorieStatusText,
    foodStatusText: foodStatusText,
    workoutStatusText: workoutStatusText,
    primaryAdvice: primaryAdvice,
    localBriefingText: localBriefingText,
    speechText: `智卡今日简报。${calorieStatusText}${foodStatusText}${workoutStatusText}${weightTrendText}建议：${primaryAdvice}`,
    suggestedActionText: buildSuggestedActionText(suggestedActionTabIndex),
    suggestedActionTabIndex: suggestedActionTabIndex
  };
}

export function buildDailyBriefingAiPrompt(summary: DailyBriefingSummary): string {
  return [
    '请以“智卡管家”的身份解读今天的健康计划，只返回简短中文建议，不要生成训练或饮食草案。',
    '要求：控制在 120 字以内；先说总体判断，再给下一步行动；不要医疗诊断；不要 Markdown。',
    `日期：${summary.date}`,
    `摄入：${Math.round(summary.intakeCalories)} kcal`,
    `消耗：${Math.round(summary.burnedCalories)} kcal`,
    `目标：${Math.round(summary.targetCalories)} kcal`,
    `饮食状态：${summary.foodStatusText}`,
    `训练状态：${summary.workoutStatusText}`,
    `体重趋势：${summary.weightTrendText}`,
    `本地规则建议：${summary.primaryAdvice}`
  ].join('\n');
}

export function deserializeDailyBriefingAiCache(cacheText: string): DailyBriefingAiCacheRecord[] {
  if (cacheText.trim().length === 0) {
    return [];
  }
  try {
    let parsedRecords = JSON.parse(cacheText) as DailyBriefingAiCacheRecord[];
    if (!Array.isArray(parsedRecords)) {
      return [];
    }
    let result: DailyBriefingAiCacheRecord[] = [];
    for (let index = 0; index < parsedRecords.length; index++) {
      let currentRecord = parsedRecords[index];
      let dateText = sanitizeString(currentRecord.date).trim();
      let text = sanitizeString(currentRecord.text).trim();
      if (dateText.length === 0 || text.length === 0) {
        continue;
      }
      result.push({
        date: dateText,
        text: text,
        updatedAt: sanitizeNumber(currentRecord.updatedAt, Date.now())
      });
    }
    return result;
  } catch (error) {
    return [];
  }
}

export function serializeDailyBriefingAiCache(records: DailyBriefingAiCacheRecord[]): string {
  return JSON.stringify(records);
}

export function getCachedDailyBriefingAiText(cacheText: string, todayText: string): string {
  let records = deserializeDailyBriefingAiCache(cacheText);
  for (let index = 0; index < records.length; index++) {
    if (records[index].date === todayText) {
      return records[index].text;
    }
  }
  return '';
}

export function upsertDailyBriefingAiCache(cacheText: string, todayText: string,
  aiText: string): string {
  let records = deserializeDailyBriefingAiCache(cacheText);
  let nextRecords: DailyBriefingAiCacheRecord[] = [{
    date: todayText,
    text: aiText.trim(),
    updatedAt: Date.now()
  }];
  for (let index = 0; index < records.length; index++) {
    if (records[index].date === todayText) {
      continue;
    }
    nextRecords.push(records[index]);
    if (nextRecords.length >= AI_CACHE_LIMIT) {
      break;
    }
  }
  return serializeDailyBriefingAiCache(nextRecords);
}
