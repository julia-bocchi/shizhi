import { ExerciseDraft } from '../models/ExerciseOption';
import { UserProfile } from '../models/UserProfile';
import { WorkoutPlanItem } from '../models/WorkoutPlan';
import {
  findExerciseOption,
  getWorkoutMetrics,
  getWorkoutTitle,
  serializeExerciseDraft
} from './ExerciseHelper';

function sanitizeString(value: string | number | boolean | undefined | null, fallbackValue: string = ''): string {
  if (value === undefined || value === null) {
    return fallbackValue;
  }
  return `${value}`;
}

export function getWorkoutPlanAccentColor(draft: ExerciseDraft): string {
  if (draft.exerciseId === 'custom') {
    return '#7A5C2E';
  }
  return findExerciseOption(draft.exerciseId).accentColor;
}

export function buildWorkoutPlanSummary(profile: UserProfile, draft: ExerciseDraft): string {
  let metrics = getWorkoutMetrics(profile, draft);
  if (metrics.validationMessage.length > 0) {
    return metrics.modeLabel;
  }
  if (metrics.canEstimateCalories) {
    return `${metrics.modeLabel} · ${metrics.durationText} · ${metrics.calorieText}`;
  }
  return `${metrics.modeLabel} · ${metrics.durationText}`;
}

export function createWorkoutPlanItem(date: string, draft: ExerciseDraft, profile: UserProfile, title: string, notes: string,
  savedWorkoutId: string = ''): WorkoutPlanItem {
  return {
    id: `${Date.now()}-${Math.round(Math.random() * 1000)}`,
    date: sanitizeString(date),
    title: title.trim().length > 0 ? title.trim() : getWorkoutTitle(draft),
    summary: buildWorkoutPlanSummary(profile, draft),
    notes: notes.trim(),
    draftText: serializeExerciseDraft(draft),
    savedWorkoutId: savedWorkoutId,
    accentColor: getWorkoutPlanAccentColor(draft)
  };
}

export function serializeWorkoutPlans(plans: WorkoutPlanItem[]): string {
  return JSON.stringify(plans);
}

export function deserializeWorkoutPlans(savedText: string): WorkoutPlanItem[] {
  if (savedText.trim().length === 0) {
    return [];
  }

  try {
    let parsedPlans = JSON.parse(savedText) as WorkoutPlanItem[];
    if (!Array.isArray(parsedPlans)) {
      return [];
    }

    let nextPlans: WorkoutPlanItem[] = [];
    for (let index = 0; index < parsedPlans.length; index++) {
      let currentPlan = parsedPlans[index];
      nextPlans.push({
        id: sanitizeString(currentPlan.id),
        date: sanitizeString(currentPlan.date),
        title: sanitizeString(currentPlan.title),
        summary: sanitizeString(currentPlan.summary),
        notes: sanitizeString(currentPlan.notes),
        draftText: sanitizeString(currentPlan.draftText),
        savedWorkoutId: sanitizeString(currentPlan.savedWorkoutId),
        accentColor: sanitizeString(currentPlan.accentColor, '#17324D')
      });
    }
    return nextPlans;
  } catch (error) {
    return [];
  }
}
