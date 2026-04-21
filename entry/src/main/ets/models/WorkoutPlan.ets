export interface WorkoutPlanItem {
  id: string;
  date: string;
  title: string;
  summary: string;
  notes: string;
  draftText: string;
  savedWorkoutId: string;
  accentColor: string;
  goalType: string;
  goalValue: number;
  manuallyCompleted: boolean;
  collapsed: boolean;
}
