import { AuthSession } from '../models/AuthSession';
import { WorkoutPlanLocalMeta } from '../models/BackendApi';
import { fetchFoodOptions, fetchFoodPlans, fetchUserProfile, fetchWeightRecords, fetchWorkoutPlans } from './ApiService';
import { serializeWorkoutPlanLocalMeta } from './AuthStorageHelper';
import { serializeUserProfile } from './ExerciseHelper';
import { serializeCustomFoodOptions, serializeFoodPlans } from './FoodHelper';
import { formatDate, serializeWeightRecords } from './WeightRecordHelper';
import { serializeWorkoutPlans } from './WorkoutPlanHelper';

export const DEFAULT_DAILY_FOOD_CALORIE_TARGET_TEXT: string = '2000';

export interface UserDataSessionState {
  userProfileText: string;
  weightRecordText: string;
  customFoodOptionText: string;
  foodPlanText: string;
  savedCustomWorkoutText: string;
  workoutPlanText: string;
  workoutPlanMetaText: string;
  workoutRecordText: string;
  pendingSyncQueueText: string;
  foodRecommendationCacheText: string;
  exerciseRecommendationCacheText: string;
  currentEditingSavedWorkoutIdText: string;
  currentExercisePlanIdText: string;
  currentExerciseDraftText: string;
  currentExerciseProfileText: string;
  currentFoodPlanDateText: string;
  currentFoodPlanMealTypeText: string;
  dailyFoodCalorieTargetText: string;
  dailyBriefingAiCacheText: string;
  ttsAudioCacheText: string;
  weeklyPlanDraftConversationIdText: string;
  weeklyPlanDraftDateText: string;
  assistantOpenConversationIdText: string;
  lastSyncAttemptText: string;
  lastSyncSuccessText: string;
  exercisePlanPickerVisible: boolean;
}

export function createClearedUserDataSessionState(): UserDataSessionState {
  return {
    userProfileText: '',
    weightRecordText: '',
    customFoodOptionText: '',
    foodPlanText: '',
    savedCustomWorkoutText: '',
    workoutPlanText: '',
    workoutPlanMetaText: '',
    workoutRecordText: '',
    pendingSyncQueueText: '',
    foodRecommendationCacheText: '',
    exerciseRecommendationCacheText: '',
    currentEditingSavedWorkoutIdText: '',
    currentExercisePlanIdText: '',
    currentExerciseDraftText: '',
    currentExerciseProfileText: '',
    currentFoodPlanDateText: '',
    currentFoodPlanMealTypeText: '',
    dailyFoodCalorieTargetText: DEFAULT_DAILY_FOOD_CALORIE_TARGET_TEXT,
    dailyBriefingAiCacheText: '',
    ttsAudioCacheText: '',
    weeklyPlanDraftConversationIdText: '',
    weeklyPlanDraftDateText: '',
    assistantOpenConversationIdText: '',
    lastSyncAttemptText: '',
    lastSyncSuccessText: '',
    exercisePlanPickerVisible: false
  };
}

export function getRecentSevenDayDateRange(): string[] {
  let endDate = new Date();
  let startDate = new Date(endDate.getTime());
  startDate.setDate(startDate.getDate() - 6);
  return [formatDate(startDate), formatDate(endDate)];
}

export function getUpcomingSevenDayPlanDateRange(): string[] {
  let startDate = new Date();
  let endDate = new Date(startDate.getTime());
  endDate.setDate(endDate.getDate() + 6);
  return [formatDate(startDate), formatDate(endDate)];
}

export async function fetchLoginUserData(baseUrl: string, authSession: AuthSession): Promise<UserDataSessionState> {
  let weightDateRange = getRecentSevenDayDateRange();
  let planDateRange = getUpcomingSevenDayPlanDateRange();
  let workoutMetaItems: WorkoutPlanLocalMeta[] = [];
  let profile = await fetchUserProfile(baseUrl, authSession);
  let weightRecords = await fetchWeightRecords(baseUrl, authSession, weightDateRange[0], weightDateRange[1]);
  let foodOptions = await fetchFoodOptions(baseUrl, authSession);
  let foodPlans = await fetchFoodPlans(baseUrl, authSession, planDateRange[0], planDateRange[1]);
  let workoutPlanResult = await fetchWorkoutPlans(baseUrl, authSession, planDateRange[0], planDateRange[1], workoutMetaItems);
  let nextState = createClearedUserDataSessionState();
  nextState.userProfileText = serializeUserProfile(profile);
  nextState.weightRecordText = serializeWeightRecords(weightRecords);
  nextState.customFoodOptionText = serializeCustomFoodOptions(foodOptions);
  nextState.foodPlanText = serializeFoodPlans(foodPlans);
  nextState.workoutPlanText = serializeWorkoutPlans(workoutPlanResult.plans);
  nextState.workoutPlanMetaText = serializeWorkoutPlanLocalMeta(workoutPlanResult.metaItems);
  return nextState;
}
