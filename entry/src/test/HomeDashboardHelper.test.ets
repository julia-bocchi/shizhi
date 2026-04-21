import { describe, it, expect } from '@ohos/hypium';
import { FoodPlanItem } from '../main/ets/models/FoodPlan';
import { UserProfile } from '../main/ets/models/UserProfile';
import { WeightRecord } from '../main/ets/models/WeightRecord';
import { WorkoutRecord } from '../main/ets/models/WorkoutRecord';
import { AI_TAB_INDEX, FOOD_TAB_INDEX, PROFILE_TAB_INDEX, RECORD_TAB_INDEX } from '../main/ets/models/TabItem';
import {
  getHomeReminderItems,
  getHomeWeightTrend,
  getTodayDashboardCalories
} from '../main/ets/utils/HomeDashboardHelper';
import { serializeUserProfile, serializeWorkoutRecords } from '../main/ets/utils/ExerciseHelper';
import { serializeFoodPlans } from '../main/ets/utils/FoodHelper';
import { serializeWeightRecords } from '../main/ets/utils/WeightRecordHelper';

const TODAY_TEXT: string = '2026-04-19';

function createFoodPlan(id: string, date: string, calories: number): FoodPlanItem {
  return {
    id: id,
    date: date,
    foodId: `food-${id}`,
    name: `food-${id}`,
    description: 'test food',
    calories: calories,
    serving: '1 份',
    mealType: 'lunch',
    image: '',
    notes: '',
    accentColor: '#0F6BFF'
  };
}

function createWorkoutRecord(id: string, date: string, calories: number): WorkoutRecord {
  return {
    id: id,
    date: date,
    name: `workout-${id}`,
    calories: calories,
    durationSeconds: 1800,
    exerciseId: '',
    planId: '',
    distanceKm: 0,
    count: 0
  };
}

function createWeightRecord(id: number, date: string, weight: number): WeightRecord {
  return {
    id: id,
    date: date,
    weight: weight
  };
}

function createCompleteProfile(): UserProfile {
  return {
    nickname: 'Julia',
    heightCm: '168',
    weightKg: '58',
    age: '27',
    gender: '女'
  };
}

export default function homeDashboardHelperTest() {
  describe('homeDashboardHelperTest', () => {
    it('getTodayDashboardCalories counts only today data', 0, () => {
      let foodPlanText = serializeFoodPlans([
        createFoodPlan('1', TODAY_TEXT, 420),
        createFoodPlan('2', TODAY_TEXT, 530),
        createFoodPlan('3', '2026-04-18', 999)
      ]);
      let workoutRecordText = serializeWorkoutRecords([
        createWorkoutRecord('1', TODAY_TEXT, 320),
        createWorkoutRecord('2', '2026-04-18', 180)
      ]);

      let summary = getTodayDashboardCalories(foodPlanText, workoutRecordText, '1800', TODAY_TEXT);

      expect(summary.intakeCalories).assertEqual(950);
      expect(summary.burnedCalories).assertEqual(320);
      expect(summary.netCalories).assertEqual(630);
      expect(summary.remainingTargetCalories).assertEqual(850);
    });

    it('getTodayDashboardCalories keeps zero state without records', 0, () => {
      let summary = getTodayDashboardCalories('', '', '1800', TODAY_TEXT);

      expect(summary.intakeCalories).assertEqual(0);
      expect(summary.burnedCalories).assertEqual(0);
      expect(summary.netCalories).assertEqual(0);
      expect(summary.remainingTargetCalories).assertEqual(1800);
    });

    it('getTodayDashboardCalories supports negative net calories', 0, () => {
      let foodPlanText = serializeFoodPlans([
        createFoodPlan('1', TODAY_TEXT, 320)
      ]);
      let workoutRecordText = serializeWorkoutRecords([
        createWorkoutRecord('1', TODAY_TEXT, 460)
      ]);

      let summary = getTodayDashboardCalories(foodPlanText, workoutRecordText, '1800', TODAY_TEXT);

      expect(summary.intakeCalories).assertEqual(320);
      expect(summary.burnedCalories).assertEqual(460);
      expect(summary.netCalories).assertEqual(-140);
      expect(summary.remainingTargetCalories).assertEqual(1480);
    });

    it('getHomeWeightTrend returns empty state when no records', 0, () => {
      let trend = getHomeWeightTrend('', TODAY_TEXT);
      let latestWeight = trend.latestRecord ? trend.latestRecord.weight : 0;

      expect(trend.recentRecords.length).assertEqual(0);
      expect(latestWeight).assertEqual(0);
      expect(trend.hasTodayRecord).assertEqual(false);
      expect(trend.changeValue).assertEqual(0);
    });

    it('getHomeWeightTrend keeps one record stable', 0, () => {
      let weightRecordText = serializeWeightRecords([
        createWeightRecord(1, TODAY_TEXT, 68.5)
      ]);
      let trend = getHomeWeightTrend(weightRecordText, TODAY_TEXT);
      let latestWeight = trend.latestRecord ? trend.latestRecord.weight : 0;

      expect(trend.recentRecords.length).assertEqual(1);
      expect(latestWeight).assertEqual(68.5);
      expect(trend.changeValue).assertEqual(0);
      expect(trend.hasTodayRecord).assertEqual(true);
    });

    it('getHomeWeightTrend trims to recent seven records', 0, () => {
      let weightRecordText = serializeWeightRecords([
        createWeightRecord(1, '2026-04-12', 70.0),
        createWeightRecord(2, '2026-04-13', 69.9),
        createWeightRecord(3, '2026-04-14', 69.7),
        createWeightRecord(4, '2026-04-15', 69.6),
        createWeightRecord(5, '2026-04-16', 69.4),
        createWeightRecord(6, '2026-04-17', 69.2),
        createWeightRecord(7, '2026-04-18', 69.1),
        createWeightRecord(8, TODAY_TEXT, 68.9)
      ]);
      let trend = getHomeWeightTrend(weightRecordText, TODAY_TEXT);
      let latestWeight = trend.latestRecord ? trend.latestRecord.weight : 0;

      expect(trend.recentRecords.length).assertEqual(7);
      expect(trend.recentRecords[0].date).assertEqual('2026-04-13');
      expect(latestWeight).assertEqual(68.9);
      expect(trend.changeValue).assertEqual(-1);
    });

    it('getHomeReminderItems keeps priority order and max length', 0, () => {
      let reminderItems = getHomeReminderItems('', '', '', '', TODAY_TEXT);

      expect(reminderItems.length).assertEqual(3);
      expect(reminderItems[0].targetTabIndex).assertEqual(PROFILE_TAB_INDEX);
      expect(reminderItems[1].targetTabIndex).assertEqual(RECORD_TAB_INDEX);
      expect(reminderItems[2].targetTabIndex).assertEqual(FOOD_TAB_INDEX);
    });

    it('getHomeReminderItems falls back to assistant when dashboard is complete', 0, () => {
      let userProfileText = serializeUserProfile(createCompleteProfile());
      let foodPlanText = serializeFoodPlans([
        createFoodPlan('1', TODAY_TEXT, 520)
      ]);
      let workoutRecordText = serializeWorkoutRecords([
        createWorkoutRecord('1', TODAY_TEXT, 260)
      ]);
      let weightRecordText = serializeWeightRecords([
        createWeightRecord(1, TODAY_TEXT, 58.2)
      ]);
      let reminderItems = getHomeReminderItems(
        userProfileText,
        foodPlanText,
        workoutRecordText,
        weightRecordText,
        TODAY_TEXT
      );

      expect(reminderItems.length).assertEqual(1);
      expect(reminderItems[0].targetTabIndex).assertEqual(AI_TAB_INDEX);
    });
  });
}
