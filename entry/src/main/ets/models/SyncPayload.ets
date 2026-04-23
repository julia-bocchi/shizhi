import { FoodOption } from './FoodOption';
import { SavedCustomWorkout } from './ExerciseOption';
import { WorkoutPlanItem } from './WorkoutPlan';
import { WorkoutRecord } from './WorkoutRecord';

export interface WeightSyncPayload {
  date: string;
  weight: number;
}

export interface FoodDraftSelectionItemPayload {
  foodId: string;
  count: number;
}

export interface FoodMealSyncPayload {
  date: string;
  mealType: string;
  notes: string;
  selections: FoodDraftSelectionItemPayload[];
}

export interface WorkoutTemplateSyncPayload {
  template: SavedCustomWorkout;
}

export interface WorkoutPlanSyncPayload {
  plan: WorkoutPlanItem;
}

export interface WorkoutRecordSyncPayload {
  record: WorkoutRecord;
  draftText: string;
}

export interface FoodOptionSyncPayload {
  option: FoodOption;
}
