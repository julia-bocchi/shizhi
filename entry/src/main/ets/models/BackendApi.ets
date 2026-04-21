import { UserProfile } from './UserProfile';

export interface ApiEnvelope<T> {
  code: number;
  message: string;
  data: T;
}

export interface LoginResponseData {
  userId: string;
  username: string;
  token: string;
}

export interface WeightSummaryResponseData {
  latestRecord?: BackendWeightRecord;
  previousRecord?: BackendWeightRecord;
  recentCount: number;
  averageWeight: number;
  changeInRange: number;
  changeFromPrevious: number;
}

export interface BackendWeightRecord {
  id: string;
  date: string;
  weight: number;
  isUpdated?: boolean;
}

export interface BackendFoodOption {
  id: string;
  source: string;
  name: string;
  description: string;
  calories: number;
  serving: string;
  mealSuggestion: string;
  image: string;
  accentColor: string;
}

export interface BackendFoodPlan {
  id: string;
  date: string;
  foodId: string;
  name: string;
  description: string;
  calories: number;
  serving: string;
  mealType: string;
  image: string;
  notes: string;
  accentColor: string;
}

export interface BackendWorkoutType {
  id: string;
  source: string;
  exerciseId: string;
  savedWorkoutId: string;
  name: string;
  description: string;
  mode: string;
  intensity: string;
  accentColor: string;
}

export interface BackendWorkoutPlan {
  id: string;
  date: string;
  title: string;
  summary: string;
  notes: string;
  draftText: string;
  savedWorkoutId: string;
  accentColor: string;
}

export interface BackendWorkoutRecord {
  id: string;
  date: string;
  name: string;
  calories: number;
  durationSeconds: number;
  exerciseId: string;
  planId: string;
  distanceKm: number;
  count: number;
}

export interface BackendWorkoutTemplate {
  id: string;
  name: string;
  mode: string;
  intensity: string;
  durationMinutes: string;
  distanceKm: string;
  paceMinutes: string;
  speedKmH: string;
  count: string;
  cadencePerMinute: string;
  sets: string;
  workSeconds: string;
  restSeconds: string;
}

export interface WorkoutDailySummaryResponseData {
  date: string;
  workoutCount: number;
  totalCalories: number;
  totalDurationSeconds: number;
}

export interface WorkoutPlanLocalMeta {
  planId: string;
  goalType: string;
  goalValue: number;
  manuallyCompleted: boolean;
  collapsed: boolean;
}

export interface LoginRequestPayload {
  username: string;
  password: string;
}

export interface UpdateWeightPayload {
  weight: number;
}

export interface CreateFoodOptionPayload {
  name: string;
  description: string;
  calories: number;
  serving: string;
  mealSuggestion: string;
  image: string;
  accentColor: string;
}

export interface CreateFoodPlanPayload {
  date: string;
  foodId: string;
  mealType: string;
  notes: string;
}

export interface CreateWorkoutPlanPayload {
  date: string;
  title: string;
  notes: string;
  savedWorkoutId: string;
  draftText: string;
}

export interface CreateWorkoutRecordPayload {
  date: string;
  exerciseId: string;
  name: string;
  calories: number;
  durationSeconds: number;
  planId: string;
  distanceKm: number;
  count: number;
  configSnapshot: WorkoutConfigSnapshot;
}

export interface CreateWorkoutTemplatePayload {
  name: string;
  mode: string;
  intensity: string;
  durationMinutes: string;
  distanceKm: string;
  paceMinutes: string;
  speedKmH: string;
  count: string;
  cadencePerMinute: string;
  sets: string;
  workSeconds: string;
  restSeconds: string;
}

export interface WorkoutConfigSnapshot {
  exerciseId: string;
  customName: string;
  customMode: string;
  customIntensity: string;
  durationMinutes: string;
  distanceKm: string;
  paceMinutes: string;
  speedKmH: string;
  count: string;
  cadencePerMinute: string;
  sets: string;
  workSeconds: string;
  restSeconds: string;
}

export interface UserProfileResponseData extends UserProfile {
}
