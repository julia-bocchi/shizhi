import { ExerciseDraft } from '../models/ExerciseOption';
import { UserProfile } from '../models/UserProfile';
import { WorkoutPlanItem } from '../models/WorkoutPlan';
import {
  getActiveWorkoutMode,
  findExerciseOption,
  getWorkoutDurationMinutes,
  getWorkoutMetrics,
  getWorkoutTitle,
  deserializeExerciseDraft,
  serializeExerciseDraft
} from './ExerciseHelper';
import {
  EXERCISE_MODE_COUNT_RATE,
  EXERCISE_MODE_DISTANCE_PACE,
  EXERCISE_MODE_DISTANCE_SPEED
} from '../models/ExerciseOption';

export const WORKOUT_PLAN_GOAL_DURATION: string = 'duration';
export const WORKOUT_PLAN_GOAL_DISTANCE: string = 'distance';
export const WORKOUT_PLAN_GOAL_COUNT: string = 'count';

export interface WorkoutPlanGoal {
  goalType: string;
  goalValue: number;
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
  let parsedValue = Number(`${value}`);
  return isNaN(parsedValue) ? fallbackValue : parsedValue;
}

function parsePositiveNumber(value: string): number {
  let parsedValue = Number(value.trim());
  if (isNaN(parsedValue) || parsedValue <= 0) {
    return 0;
  }
  return parsedValue;
}

function trimGoalValueText(value: number): string {
  let normalizedValue = Math.round(value * 10) / 10;
  let fixedText = normalizedValue.toFixed(1);
  if (fixedText.endsWith('.0')) {
    return fixedText.substring(0, fixedText.length - 2);
  }
  return fixedText;
}

export function getWorkoutPlanAccentColor(draft: ExerciseDraft): string {
  if (draft.exerciseId === 'custom') {
    return '#FF7A59';
  }
  return findExerciseOption(draft.exerciseId).accentColor;
}

export function getWorkoutPlanGoalFromDraft(draft: ExerciseDraft): WorkoutPlanGoal {
  let activeMode = getActiveWorkoutMode(draft);
  if (activeMode === EXERCISE_MODE_DISTANCE_PACE || activeMode === EXERCISE_MODE_DISTANCE_SPEED) {
    let distanceKm = parsePositiveNumber(draft.distanceKm);
    return {
      goalType: WORKOUT_PLAN_GOAL_DISTANCE,
      goalValue: distanceKm > 0 ? distanceKm : 1
    };
  }
  if (activeMode === EXERCISE_MODE_COUNT_RATE) {
    let count = parsePositiveNumber(draft.count);
    return {
      goalType: WORKOUT_PLAN_GOAL_COUNT,
      goalValue: count > 0 ? count : 1
    };
  }
  let durationMinutes = getWorkoutDurationMinutes(draft);
  return {
    goalType: WORKOUT_PLAN_GOAL_DURATION,
    goalValue: durationMinutes > 0 ? durationMinutes : 30
  };
}

export function getWorkoutPlanGoalUnit(goalType: string): string {
  if (goalType === WORKOUT_PLAN_GOAL_DISTANCE) {
    return 'km';
  }
  if (goalType === WORKOUT_PLAN_GOAL_COUNT) {
    return '次';
  }
  return '分钟';
}

export function getWorkoutPlanGoalLabel(goalType: string): string {
  if (goalType === WORKOUT_PLAN_GOAL_DISTANCE) {
    return '目标路程';
  }
  if (goalType === WORKOUT_PLAN_GOAL_COUNT) {
    return '目标次数';
  }
  return '目标时长';
}

export function formatWorkoutPlanGoalValue(goalType: string, value: number): string {
  if (goalType === WORKOUT_PLAN_GOAL_COUNT) {
    return `${Math.max(0, Math.round(value))}`;
  }
  return trimGoalValueText(value);
}

export function getWorkoutPlanGoalText(goalType: string, value: number): string {
  return `${formatWorkoutPlanGoalValue(goalType, value)} ${getWorkoutPlanGoalUnit(goalType)}`;
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
  savedWorkoutId: string = '', goalValueInput: number = 0): WorkoutPlanItem {
  let goal = getWorkoutPlanGoalFromDraft(draft);
  let normalizedGoalValue = goalValueInput > 0 ? goalValueInput : goal.goalValue;
  return {
    id: `local-workout-plan-${Date.now()}-${Math.round(Math.random() * 1000)}`,
    date: sanitizeString(date),
    title: title.trim().length > 0 ? title.trim() : getWorkoutTitle(draft),
    summary: buildWorkoutPlanSummary(profile, draft),
    notes: notes.trim(),
    draftText: serializeExerciseDraft(draft),
    savedWorkoutId: savedWorkoutId,
    accentColor: getWorkoutPlanAccentColor(draft),
    goalType: goal.goalType,
    goalValue: normalizedGoalValue,
    manuallyCompleted: false,
    collapsed: false
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
      let draftText = sanitizeString(currentPlan.draftText);
      let fallbackGoal = getWorkoutPlanGoalFromDraft(deserializeExerciseDraft(draftText));
      nextPlans.push({
        id: sanitizeString(currentPlan.id),
        date: sanitizeString(currentPlan.date),
        title: sanitizeString(currentPlan.title),
        summary: sanitizeString(currentPlan.summary),
        notes: sanitizeString(currentPlan.notes),
        draftText: draftText,
        savedWorkoutId: sanitizeString(currentPlan.savedWorkoutId),
        accentColor: sanitizeString(currentPlan.accentColor, '#0F6BFF'),
        goalType: sanitizeString(currentPlan.goalType, fallbackGoal.goalType),
        goalValue: sanitizeNumber(currentPlan.goalValue, fallbackGoal.goalValue),
        manuallyCompleted: currentPlan.manuallyCompleted === true,
        collapsed: currentPlan.collapsed === true
      });
    }
    return nextPlans;
  } catch (error) {
    return [];
  }
}
