export const SYNC_ENTITY_PROFILE: string = 'profile';
export const SYNC_ENTITY_WEIGHT: string = 'weight';
export const SYNC_ENTITY_FOOD_OPTION: string = 'food_option';
export const SYNC_ENTITY_FOOD_MEAL: string = 'food_meal';
export const SYNC_ENTITY_WORKOUT_TEMPLATE: string = 'workout_template';
export const SYNC_ENTITY_WORKOUT_PLAN: string = 'workout_plan';
export const SYNC_ENTITY_WORKOUT_RECORD: string = 'workout_record';

export const SYNC_ACTION_PUT: string = 'put';
export const SYNC_ACTION_UPSERT: string = 'upsert';
export const SYNC_ACTION_REPLACE: string = 'replace';
export const SYNC_ACTION_CREATE: string = 'create';
export const SYNC_ACTION_DELETE: string = 'delete';

export interface PendingSyncOperation {
  id: string;
  entityType: string;
  action: string;
  entityKey: string;
  payloadText: string;
  localUpdatedAt: string;
}

export function createPendingSyncOperation(entityType: string, action: string, entityKey: string,
  payloadText: string, localUpdatedAt: string = `${Date.now()}`): PendingSyncOperation {
  return {
    id: `${Date.now()}-${Math.round(Math.random() * 1000)}`,
    entityType: entityType,
    action: action,
    entityKey: entityKey,
    payloadText: payloadText,
    localUpdatedAt: localUpdatedAt
  };
}
