import { WorkoutPlanItem } from '../models/WorkoutPlan';
import { WorkoutPlanLocalMeta } from '../models/BackendApi';

export function buildWorkoutPlanMetaFromPlan(plan: WorkoutPlanItem): WorkoutPlanLocalMeta {
  return {
    planId: plan.id,
    goalType: plan.goalType,
    goalValue: plan.goalValue,
    manuallyCompleted: plan.manuallyCompleted,
    collapsed: plan.collapsed
  };
}

export function buildWorkoutPlanMetaList(plans: WorkoutPlanItem[]): WorkoutPlanLocalMeta[] {
  let items: WorkoutPlanLocalMeta[] = [];
  for (let index = 0; index < plans.length; index++) {
    items.push(buildWorkoutPlanMetaFromPlan(plans[index]));
  }
  return items;
}
