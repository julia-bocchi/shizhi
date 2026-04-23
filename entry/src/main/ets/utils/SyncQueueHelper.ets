import {
  PendingSyncOperation,
  SYNC_ACTION_CREATE,
  SYNC_ACTION_DELETE,
  SYNC_ACTION_PUT,
  SYNC_ACTION_REPLACE,
  SYNC_ACTION_UPSERT,
  SYNC_ENTITY_FOOD_OPTION,
  SYNC_ENTITY_FOOD_MEAL,
  SYNC_ENTITY_PROFILE,
  SYNC_ENTITY_WEIGHT,
  SYNC_ENTITY_WORKOUT_PLAN,
  SYNC_ENTITY_WORKOUT_RECORD,
  SYNC_ENTITY_WORKOUT_TEMPLATE,
  createPendingSyncOperation
} from '../models/SyncQueue';
import { FoodOption } from '../models/FoodOption';
import { FoodDraftSelectionItemPayload, FoodMealSyncPayload, WorkoutPlanSyncPayload, WorkoutRecordSyncPayload,
  WorkoutTemplateSyncPayload, WeightSyncPayload } from '../models/SyncPayload';
import { SavedCustomWorkout } from '../models/ExerciseOption';
import { WorkoutPlanItem } from '../models/WorkoutPlan';
import { WorkoutRecord } from '../models/WorkoutRecord';

function sanitizeString(value: string | number | boolean | undefined | null, fallbackValue: string = ''): string {
  if (value === undefined || value === null) {
    return fallbackValue;
  }
  return `${value}`;
}

export function isLocalOnlyId(id: string): boolean {
  return id.indexOf('local-') === 0;
}

export function serializePendingSyncOperations(operations: PendingSyncOperation[]): string {
  return JSON.stringify(operations);
}

export function deserializePendingSyncOperations(savedText: string): PendingSyncOperation[] {
  if (savedText.trim().length === 0) {
    return [];
  }

  try {
    let parsedItems = JSON.parse(savedText) as PendingSyncOperation[];
    if (!Array.isArray(parsedItems)) {
      return [];
    }
    let result: PendingSyncOperation[] = [];
    for (let index = 0; index < parsedItems.length; index++) {
      result.push({
        id: sanitizeString(parsedItems[index].id),
        entityType: sanitizeString(parsedItems[index].entityType),
        action: sanitizeString(parsedItems[index].action),
        entityKey: sanitizeString(parsedItems[index].entityKey),
        payloadText: sanitizeString(parsedItems[index].payloadText),
        localUpdatedAt: sanitizeString(parsedItems[index].localUpdatedAt)
      });
    }
    return result;
  } catch (error) {
    return [];
  }
}

function upsertOperationByEntityKey(savedText: string, nextOperation: PendingSyncOperation): string {
  let currentItems = deserializePendingSyncOperations(savedText);
  let result: PendingSyncOperation[] = [];
  let hasUpdated = false;
  for (let index = 0; index < currentItems.length; index++) {
    let currentItem = currentItems[index];
    if (currentItem.entityType === nextOperation.entityType && currentItem.entityKey === nextOperation.entityKey) {
      result.push(nextOperation);
      hasUpdated = true;
    } else {
      result.push(currentItem);
    }
  }
  if (!hasUpdated) {
    result.push(nextOperation);
  }
  return serializePendingSyncOperations(result);
}

export function queuePendingOperation(savedText: string, nextOperation: PendingSyncOperation): string {
  return upsertOperationByEntityKey(savedText, nextOperation);
}

export function removePendingOperation(savedText: string, operationId: string): string {
  let currentItems = deserializePendingSyncOperations(savedText);
  let result: PendingSyncOperation[] = [];
  for (let index = 0; index < currentItems.length; index++) {
    if (currentItems[index].id !== operationId) {
      result.push(currentItems[index]);
    }
  }
  return serializePendingSyncOperations(result);
}

export function removePendingOperationByEntityKey(savedText: string, entityType: string, entityKey: string): string {
  let currentItems = deserializePendingSyncOperations(savedText);
  let result: PendingSyncOperation[] = [];
  for (let index = 0; index < currentItems.length; index++) {
    if (currentItems[index].entityType === entityType && currentItems[index].entityKey === entityKey) {
      continue;
    }
    result.push(currentItems[index]);
  }
  return serializePendingSyncOperations(result);
}

export function hasPendingSyncOperation(savedText: string, entityType: string = ''): boolean {
  let currentItems = deserializePendingSyncOperations(savedText);
  if (entityType.trim().length === 0) {
    return currentItems.length > 0;
  }
  for (let index = 0; index < currentItems.length; index++) {
    if (currentItems[index].entityType === entityType) {
      return true;
    }
  }
  return false;
}

export function createProfilePutOperation(profileText: string): PendingSyncOperation {
  return createPendingSyncOperation(SYNC_ENTITY_PROFILE, SYNC_ACTION_PUT, 'profile', profileText);
}

export function queueProfilePut(savedText: string, profileText: string): string {
  return queuePendingOperation(savedText, createProfilePutOperation(profileText));
}

export function createWeightUpsertOperation(dateText: string, weight: number): PendingSyncOperation {
  let payload: WeightSyncPayload = {
    date: dateText,
    weight: weight
  };
  return createPendingSyncOperation(SYNC_ENTITY_WEIGHT, SYNC_ACTION_UPSERT, dateText, JSON.stringify(payload));
}

export function queueWeightUpsert(savedText: string, dateText: string, weight: number): string {
  return queuePendingOperation(savedText, createWeightUpsertOperation(dateText, weight));
}

export function createFoodOptionUpsertOperation(option: FoodOption): PendingSyncOperation {
  return createPendingSyncOperation(SYNC_ENTITY_FOOD_OPTION, SYNC_ACTION_UPSERT, option.id, JSON.stringify(option));
}

export function queueFoodOptionUpsert(savedText: string, option: FoodOption): string {
  return queuePendingOperation(savedText, createFoodOptionUpsertOperation(option));
}

export function createFoodMealReplaceOperation(dateText: string, mealType: string, notes: string,
  selections: FoodDraftSelectionItemPayload[]): PendingSyncOperation {
  let payload: FoodMealSyncPayload = {
    date: dateText,
    mealType: mealType,
    notes: notes,
    selections: selections
  };
  return createPendingSyncOperation(
    SYNC_ENTITY_FOOD_MEAL,
    SYNC_ACTION_REPLACE,
    `${dateText}|${mealType}`,
    JSON.stringify(payload)
  );
}

export function queueFoodMealReplace(savedText: string, dateText: string, mealType: string, notes: string,
  selections: FoodDraftSelectionItemPayload[]): string {
  return queuePendingOperation(savedText, createFoodMealReplaceOperation(dateText, mealType, notes, selections));
}

export function createWorkoutTemplateUpsertOperation(template: SavedCustomWorkout): PendingSyncOperation {
  let payload: WorkoutTemplateSyncPayload = {
    template: template
  };
  return createPendingSyncOperation(
    SYNC_ENTITY_WORKOUT_TEMPLATE,
    SYNC_ACTION_UPSERT,
    template.id,
    JSON.stringify(payload)
  );
}

export function queueWorkoutTemplateUpsert(savedText: string, template: SavedCustomWorkout): string {
  return queuePendingOperation(savedText, createWorkoutTemplateUpsertOperation(template));
}

export function createWorkoutTemplateDeleteOperation(templateId: string, templateName: string): PendingSyncOperation {
  return createPendingSyncOperation(
    SYNC_ENTITY_WORKOUT_TEMPLATE,
    SYNC_ACTION_DELETE,
    templateId,
    JSON.stringify({ id: templateId, name: templateName })
  );
}

export function queueWorkoutTemplateDelete(savedText: string, templateId: string, templateName: string): string {
  let currentItems = deserializePendingSyncOperations(savedText);
  let result: PendingSyncOperation[] = [];
  let removedPendingCreate = false;
  for (let index = 0; index < currentItems.length; index++) {
    let currentItem = currentItems[index];
    if (currentItem.entityType === 'workout_template' && currentItem.entityKey === templateId &&
      currentItem.action !== SYNC_ACTION_DELETE && isLocalOnlyId(templateId)) {
      removedPendingCreate = true;
      continue;
    }
    result.push(currentItem);
  }
  if (removedPendingCreate && isLocalOnlyId(templateId)) {
    return serializePendingSyncOperations(result);
  }
  return queuePendingOperation(serializePendingSyncOperations(result), createWorkoutTemplateDeleteOperation(templateId, templateName));
}

export function createWorkoutPlanCreateOperation(plan: WorkoutPlanItem): PendingSyncOperation {
  let payload: WorkoutPlanSyncPayload = {
    plan: plan
  };
  return createPendingSyncOperation(
    SYNC_ENTITY_WORKOUT_PLAN,
    SYNC_ACTION_CREATE,
    plan.id,
    JSON.stringify(payload)
  );
}

export function queueWorkoutPlanCreate(savedText: string, plan: WorkoutPlanItem): string {
  return queuePendingOperation(savedText, createWorkoutPlanCreateOperation(plan));
}

export function createWorkoutPlanDeleteOperation(planId: string): PendingSyncOperation {
  return createPendingSyncOperation(
    SYNC_ENTITY_WORKOUT_PLAN,
    SYNC_ACTION_DELETE,
    planId,
    JSON.stringify({ id: planId })
  );
}

export function queueWorkoutPlanDelete(savedText: string, planId: string): string {
  let currentItems = deserializePendingSyncOperations(savedText);
  let result: PendingSyncOperation[] = [];
  let removedPendingCreate = false;
  for (let index = 0; index < currentItems.length; index++) {
    let currentItem = currentItems[index];
    if (currentItem.entityType === 'workout_plan' && currentItem.entityKey === planId &&
      currentItem.action === SYNC_ACTION_CREATE && isLocalOnlyId(planId)) {
      removedPendingCreate = true;
      continue;
    }
    result.push(currentItem);
  }
  if (removedPendingCreate && isLocalOnlyId(planId)) {
    return serializePendingSyncOperations(result);
  }
  return queuePendingOperation(serializePendingSyncOperations(result), createWorkoutPlanDeleteOperation(planId));
}

export function createWorkoutRecordCreateOperation(record: WorkoutRecord, draftText: string): PendingSyncOperation {
  let payload: WorkoutRecordSyncPayload = {
    record: record,
    draftText: draftText
  };
  return createPendingSyncOperation(
    SYNC_ENTITY_WORKOUT_RECORD,
    SYNC_ACTION_CREATE,
    record.id,
    JSON.stringify(payload)
  );
}

export function queueWorkoutRecordCreate(savedText: string, record: WorkoutRecord, draftText: string): string {
  return queuePendingOperation(savedText, createWorkoutRecordCreateOperation(record, draftText));
}
