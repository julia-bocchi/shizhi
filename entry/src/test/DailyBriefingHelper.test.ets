import { describe, it, expect } from '@ohos/hypium';
import { FoodPlanItem } from '../main/ets/models/FoodPlan';
import { WorkoutPlanItem } from '../main/ets/models/WorkoutPlan';
import { WorkoutRecord } from '../main/ets/models/WorkoutRecord';
import { WeightRecord } from '../main/ets/models/WeightRecord';
import { serializeFoodPlans } from '../main/ets/utils/FoodHelper';
import { serializeWorkoutPlans } from '../main/ets/utils/WorkoutPlanHelper';
import { serializeWorkoutRecords } from '../main/ets/utils/ExerciseHelper';
import { serializeWeightRecords } from '../main/ets/utils/WeightRecordHelper';
import {
  buildDailyBriefingSummary,
  getCachedDailyBriefingAiText,
  upsertDailyBriefingAiCache
} from '../main/ets/utils/DailyBriefingHelper';

const TODAY_TEXT: string = '2026-04-19';

function createFoodPlan(id: string, mealType: string, calories: number): FoodPlanItem {
  return {
    id: id,
    date: TODAY_TEXT,
    foodId: `food-${id}`,
    name: `food-${id}`,
    description: 'test food',
    calories: calories,
    serving: '1 份',
    mealType: mealType,
    image: '',
    notes: '',
    accentColor: '#0F6BFF'
  };
}

function createWorkoutPlan(id: string, completed: boolean): WorkoutPlanItem {
  return {
    id: id,
    date: TODAY_TEXT,
    title: `plan-${id}`,
    summary: '30 分钟',
    notes: '',
    draftText: '',
    savedWorkoutId: '',
    accentColor: '#0F6BFF',
    goalType: 'duration',
    goalValue: 30,
    manuallyCompleted: completed,
    collapsed: false
  };
}

function createWorkoutRecord(planId: string, calories: number): WorkoutRecord {
  return {
    id: `record-${planId}`,
    date: TODAY_TEXT,
    name: `workout-${planId}`,
    calories: calories,
    durationSeconds: 1800,
    exerciseId: '',
    planId: planId,
    distanceKm: 0,
    count: 0
  };
}

function createWeightRecord(id: string, date: string, weight: number): WeightRecord {
  return {
    id: id,
    date: date,
    weight: weight
  };
}

export default function dailyBriefingHelperTest() {
  describe('dailyBriefingHelperTest', () => {
    it('buildDailyBriefingSummary combines calories plans and trend', 0, () => {
      let summary = buildDailyBriefingSummary(
        serializeFoodPlans([
          createFoodPlan('1', 'breakfast', 420),
          createFoodPlan('2', 'lunch', 560)
        ]),
        serializeWorkoutPlans([
          createWorkoutPlan('plan-1', false),
          createWorkoutPlan('plan-2', true)
        ]),
        serializeWorkoutRecords([
          createWorkoutRecord('plan-1', 260)
        ]),
        serializeWeightRecords([
          createWeightRecord('1', '2026-04-18', 58.4),
          createWeightRecord('2', TODAY_TEXT, 58.0)
        ]),
        '1800',
        TODAY_TEXT
      );

      expect(summary.intakeCalories).assertEqual(980);
      expect(summary.burnedCalories).assertEqual(260);
      expect(summary.remainingTargetCalories).assertEqual(820);
      expect(summary.mealTypeCount).assertEqual(2);
      expect(summary.completedWorkoutPlanCount).assertEqual(2);
      expect(summary.pendingWorkoutPlanCount).assertEqual(0);
      expect(summary.latestWeightText).assertEqual('58.0 kg');
    });

    it('daily briefing ai cache stores one record per date', 0, () => {
      let cacheText = upsertDailyBriefingAiCache('', TODAY_TEXT, '今天节奏稳定。');
      cacheText = upsertDailyBriefingAiCache(cacheText, TODAY_TEXT, '今天优先完成训练。');

      expect(getCachedDailyBriefingAiText(cacheText, TODAY_TEXT)).assertEqual('今天优先完成训练。');
      expect(getCachedDailyBriefingAiText(cacheText, '2026-04-20')).assertEqual('');
    });
  });
}
