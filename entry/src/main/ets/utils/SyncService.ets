import { hilog } from '@kit.PerformanceAnalysisKit';
import { AuthSession, isAuthSessionValid } from '../models/AuthSession';
import { FoodOption } from '../models/FoodOption';
import { FoodPlanItem } from '../models/FoodPlan';
import { PendingSyncOperation } from '../models/SyncQueue';
import {
  FoodDraftSelectionItemPayload,
  FoodMealSyncPayload,
  WeightSyncPayload,
  WorkoutPlanSyncPayload,
  WorkoutRecordSyncPayload,
  WorkoutTemplateSyncPayload
} from '../models/SyncPayload';
import { SavedCustomWorkout } from '../models/ExerciseOption';
import { WorkoutPlanLocalMeta } from '../models/BackendApi';
import { UserProfile } from '../models/UserProfile';
import { WeightRecord } from '../models/WeightRecord';
import { WorkoutPlanItem } from '../models/WorkoutPlan';
import { WorkoutRecord } from '../models/WorkoutRecord';
import { deserializeAuthSession, deserializeWorkoutPlanLocalMeta, serializeWorkoutPlanLocalMeta } from './AuthStorageHelper';
import {
  createCustomFoodOptionRemote,
  createFoodPlanRemote,
  createWorkoutPlanRemote,
  createWorkoutRecordRemote,
  deleteFoodPlanRemote,
  deleteWorkoutPlanRemote,
  deleteWorkoutTemplateRemote,
  fetchFoodPlans,
  saveWorkoutTemplateRemote,
  updateCustomFoodOptionRemote,
  updateUserProfileRemote,
  upsertWorkoutPlanMeta,
  upsertWeightRecordRemote
} from './ApiService';
import {
  buildSavedWorkoutIdentityKey,
  deserializeExerciseDraft,
  deserializeSavedCustomWorkouts,
  deserializeUserProfile,
  deserializeWorkoutRecords,
  serializeSavedCustomWorkouts,
  upsertSavedCustomWorkoutByIdentity,
  serializeUserProfile,
  serializeWorkoutRecords
} from './ExerciseHelper';
import {
  buildCustomFoodIdentityKey,
  deserializeCustomFoodOptions,
  deserializeFoodPlans,
  serializeCustomFoodOptions,
  serializeFoodPlans,
  upsertCustomFoodOptionByIdentity
} from './FoodHelper';
import {
  deserializePendingSyncOperations,
  isLocalOnlyId,
  queuePendingOperation,
  removePendingOperation,
  removePendingOperationByEntityKey
} from './SyncQueueHelper';
import {
  deserializeWorkoutPlans,
  serializeWorkoutPlans
} from './WorkoutPlanHelper';
import {
  compareRecordDate,
  deserializeWeightRecords,
  serializeWeightRecords
} from './WeightRecordHelper';

const SYNC_LOG_DOMAIN: number = 0xFF13;
const SYNC_LOG_TAG: string = 'SyncService';

function serializeSyncLogValue(value: Object | string | undefined | null): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  return JSON.stringify(value);
}

interface SyncFoodMealStartLog {
  date: string;
  mealType: string;
  notes: string;
  selectionCount: number;
  selections: FoodDraftSelectionItemPayload[];
}

interface SyncFoodMealFetchedLog {
  date: string;
  mealType: string;
  remoteMealPlanCount: number;
}

interface SyncFoodMealDeletedLog {
  date: string;
  mealType: string;
  deletedCount: number;
}

interface SyncFoodMealCreatedLog {
  date: string;
  mealType: string;
  createdCount: number;
}

interface SyncOperationLog {
  id: string;
  entityType: string;
  action: string;
  entityKey: string;
}

interface SyncOperationErrorLog extends SyncOperationLog {
  error: string;
}

export interface SyncRuntimeState {
  apiBaseUrlText: string;
  authSessionText: string;
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
  lastSyncAttemptText: string;
  lastSyncSuccessText: string;
}

export interface SyncExecutionResult {
  state: SyncRuntimeState;
  syncedCount: number;
  lastErrorMessage: string;
}

export interface ImmediateSyncResult {
  state: SyncRuntimeState;
  syncedImmediately: boolean;
  queuedForLater: boolean;
  errorMessage: string;
}

interface DeleteWorkoutPlanPayload {
  id: string;
}

function copySyncState(state: SyncRuntimeState): SyncRuntimeState {
  return {
    apiBaseUrlText: state.apiBaseUrlText,
    authSessionText: state.authSessionText,
    userProfileText: state.userProfileText,
    weightRecordText: state.weightRecordText,
    customFoodOptionText: state.customFoodOptionText,
    foodPlanText: state.foodPlanText,
    savedCustomWorkoutText: state.savedCustomWorkoutText,
    workoutPlanText: state.workoutPlanText,
    workoutPlanMetaText: state.workoutPlanMetaText,
    workoutRecordText: state.workoutRecordText,
    pendingSyncQueueText: state.pendingSyncQueueText,
    foodRecommendationCacheText: state.foodRecommendationCacheText,
    exerciseRecommendationCacheText: state.exerciseRecommendationCacheText,
    currentEditingSavedWorkoutIdText: state.currentEditingSavedWorkoutIdText,
    currentExercisePlanIdText: state.currentExercisePlanIdText,
    lastSyncAttemptText: state.lastSyncAttemptText,
    lastSyncSuccessText: state.lastSyncSuccessText
  };
}

function replaceTextValue(textValue: string, oldId: string, newId: string): string {
  if (oldId.trim().length === 0 || oldId === newId || textValue.length === 0) {
    return textValue;
  }
  return textValue.split(oldId).join(newId);
}

function replaceEntityIdInState(state: SyncRuntimeState, oldId: string, newId: string): SyncRuntimeState {
  if (oldId.trim().length === 0 || oldId === newId) {
    return state;
  }
  return {
    apiBaseUrlText: state.apiBaseUrlText,
    authSessionText: state.authSessionText,
    userProfileText: state.userProfileText,
    weightRecordText: replaceTextValue(state.weightRecordText, oldId, newId),
    customFoodOptionText: replaceTextValue(state.customFoodOptionText, oldId, newId),
    foodPlanText: replaceTextValue(state.foodPlanText, oldId, newId),
    savedCustomWorkoutText: replaceTextValue(state.savedCustomWorkoutText, oldId, newId),
    workoutPlanText: replaceTextValue(state.workoutPlanText, oldId, newId),
    workoutPlanMetaText: replaceTextValue(state.workoutPlanMetaText, oldId, newId),
    workoutRecordText: replaceTextValue(state.workoutRecordText, oldId, newId),
    pendingSyncQueueText: replaceTextValue(state.pendingSyncQueueText, oldId, newId),
    foodRecommendationCacheText: replaceTextValue(state.foodRecommendationCacheText, oldId, newId),
    exerciseRecommendationCacheText: replaceTextValue(state.exerciseRecommendationCacheText, oldId, newId),
    currentEditingSavedWorkoutIdText: state.currentEditingSavedWorkoutIdText === oldId ? newId : state.currentEditingSavedWorkoutIdText,
    currentExercisePlanIdText: state.currentExercisePlanIdText === oldId ? newId : state.currentExercisePlanIdText,
    lastSyncAttemptText: state.lastSyncAttemptText,
    lastSyncSuccessText: state.lastSyncSuccessText
  };
}

function upsertLocalWeightRecord(savedText: string, nextRecord: WeightRecord): string {
  let currentRecords = deserializeWeightRecords(savedText);
  let result: WeightRecord[] = [];
  let hasUpdated = false;
  for (let index = 0; index < currentRecords.length; index++) {
    if (currentRecords[index].date === nextRecord.date) {
      result.push(nextRecord);
      hasUpdated = true;
    } else {
      result.push(currentRecords[index]);
    }
  }
  if (!hasUpdated) {
    result.push(nextRecord);
  }
  result.sort((left: WeightRecord, right: WeightRecord) => compareRecordDate(left, right));
  return serializeWeightRecords(result);
}

function upsertLocalFoodOption(savedText: string, nextOption: FoodOption): string {
  return serializeCustomFoodOptions(upsertCustomFoodOptionByIdentity(
    deserializeCustomFoodOptions(savedText),
    nextOption,
    nextOption.id
  ).options);
}

function upsertLocalWorkoutTemplate(savedText: string, nextTemplate: SavedCustomWorkout): string {
  return serializeSavedCustomWorkouts(upsertSavedCustomWorkoutByIdentity(
    deserializeSavedCustomWorkouts(savedText),
    nextTemplate,
    nextTemplate.id
  ).savedWorkouts);
}

function upsertLocalWorkoutPlan(savedText: string, nextPlan: WorkoutPlanItem): string {
  let currentPlans = deserializeWorkoutPlans(savedText);
  let result: WorkoutPlanItem[] = [];
  let hasUpdated = false;
  for (let index = 0; index < currentPlans.length; index++) {
    if (currentPlans[index].id === nextPlan.id) {
      result.push(nextPlan);
      hasUpdated = true;
    } else {
      result.push(currentPlans[index]);
    }
  }
  if (!hasUpdated) {
    result.unshift(nextPlan);
  }
  return serializeWorkoutPlans(result);
}

function upsertLocalWorkoutRecord(savedText: string, nextRecord: WorkoutRecord): string {
  let currentRecords = deserializeWorkoutRecords(savedText);
  let result: WorkoutRecord[] = [];
  let hasUpdated = false;
  for (let index = 0; index < currentRecords.length; index++) {
    if (currentRecords[index].id === nextRecord.id) {
      result.push(nextRecord);
      hasUpdated = true;
    } else {
      result.push(currentRecords[index]);
    }
  }
  if (!hasUpdated) {
    result.unshift(nextRecord);
  }
  return serializeWorkoutRecords(result);
}

function replaceLocalFoodMeal(savedText: string, dateText: string, mealType: string, nextPlans: FoodPlanItem[]): string {
  let currentPlans = deserializeFoodPlans(savedText);
  let result: FoodPlanItem[] = [];
  for (let index = 0; index < currentPlans.length; index++) {
    let currentPlan = currentPlans[index];
    if (currentPlan.date === dateText && currentPlan.mealType === mealType) {
      continue;
    }
    result.push(currentPlan);
  }
  for (let index = 0; index < nextPlans.length; index++) {
    result.unshift(nextPlans[index]);
  }
  return serializeFoodPlans(result);
}

function removeLocalWorkoutTemplate(savedText: string, templateId: string): string {
  let currentItems = deserializeSavedCustomWorkouts(savedText);
  let result: SavedCustomWorkout[] = [];
  for (let index = 0; index < currentItems.length; index++) {
    if (currentItems[index].id !== templateId) {
      result.push(currentItems[index]);
    }
  }
  return serializeSavedCustomWorkouts(result);
}

function removeLocalWorkoutPlan(savedText: string, planId: string): string {
  let currentPlans = deserializeWorkoutPlans(savedText);
  let result: WorkoutPlanItem[] = [];
  for (let index = 0; index < currentPlans.length; index++) {
    if (currentPlans[index].id !== planId) {
      result.push(currentPlans[index]);
    }
  }
  return serializeWorkoutPlans(result);
}

function removeLocalWorkoutPlanMeta(savedText: string, planId: string): string {
  let currentItems = deserializeWorkoutPlanLocalMeta(savedText);
  let result: WorkoutPlanLocalMeta[] = [];
  for (let index = 0; index < currentItems.length; index++) {
    if (currentItems[index].planId !== planId) {
      result.push(currentItems[index]);
    }
  }
  return serializeWorkoutPlanLocalMeta(result);
}

function mergeSyncedWorkoutPlan(localPlan: WorkoutPlanItem, remotePlan: WorkoutPlanItem): WorkoutPlanItem {
  let remoteSummary = remotePlan.summary.trim();
  let shouldKeepLocalSummary = remoteSummary.length === 0 || remoteSummary === '已保存训练计划';
  return {
    id: remotePlan.id,
    date: remotePlan.date,
    title: remotePlan.title.trim().length > 0 ? remotePlan.title : localPlan.title,
    summary: shouldKeepLocalSummary ? localPlan.summary : remotePlan.summary,
    notes: remotePlan.notes,
    draftText: remotePlan.draftText.trim().length > 0 ? remotePlan.draftText : localPlan.draftText,
    savedWorkoutId: remotePlan.savedWorkoutId,
    accentColor: remotePlan.accentColor.trim().length > 0 ? remotePlan.accentColor : localPlan.accentColor,
    goalType: remotePlan.goalType,
    goalValue: remotePlan.goalValue,
    manuallyCompleted: remotePlan.manuallyCompleted,
    collapsed: remotePlan.collapsed
  };
}

async function syncProfileOperation(state: SyncRuntimeState, authSession: AuthSession, operation: PendingSyncOperation): Promise<SyncRuntimeState> {
  let profile = deserializeUserProfile(operation.payloadText);
  let remoteProfile: UserProfile = await updateUserProfileRemote(state.apiBaseUrlText, authSession, profile);
  let nextState = copySyncState(state);
  nextState.userProfileText = serializeUserProfile(remoteProfile);
  return nextState;
}

async function syncWeightOperation(state: SyncRuntimeState, authSession: AuthSession, operation: PendingSyncOperation): Promise<SyncRuntimeState> {
  let payload = JSON.parse(operation.payloadText) as WeightSyncPayload;
  let remoteRecord = await upsertWeightRecordRemote(state.apiBaseUrlText, authSession, payload.date, payload.weight);
  let nextState = copySyncState(state);
  nextState.weightRecordText = upsertLocalWeightRecord(state.weightRecordText, remoteRecord);
  return nextState;
}

async function syncFoodOptionOperation(state: SyncRuntimeState, authSession: AuthSession, operation: PendingSyncOperation): Promise<SyncRuntimeState> {
  let option = JSON.parse(operation.payloadText) as FoodOption;
  let remoteOption: FoodOption;
  if (isLocalOnlyId(option.id)) {
    remoteOption = await createCustomFoodOptionRemote(state.apiBaseUrlText, authSession, {
      identityKey: buildCustomFoodIdentityKey(option.name),
      name: option.name,
      description: option.description,
      calories: option.calories,
      serving: option.serving,
      mealSuggestion: option.mealSuggestion,
      image: option.image,
      accentColor: option.accentColor
    });
    let replacedState = replaceEntityIdInState(state, option.id, remoteOption.id);
    let nextState = copySyncState(replacedState);
    nextState.customFoodOptionText = upsertLocalFoodOption(replacedState.customFoodOptionText, remoteOption);
    return nextState;
  }
  remoteOption = await updateCustomFoodOptionRemote(state.apiBaseUrlText, authSession, option.id, {
    name: option.name,
    description: option.description,
    calories: option.calories,
    serving: option.serving,
    mealSuggestion: option.mealSuggestion,
    image: option.image,
    accentColor: option.accentColor
  });
  let nextState = copySyncState(state);
  nextState.customFoodOptionText = upsertLocalFoodOption(state.customFoodOptionText, remoteOption);
  return nextState;
}

async function syncFoodMealOperation(state: SyncRuntimeState, authSession: AuthSession, operation: PendingSyncOperation): Promise<SyncRuntimeState> {
  let payload = JSON.parse(operation.payloadText) as FoodMealSyncPayload;
  let startLog: SyncFoodMealStartLog = {
    date: payload.date,
    mealType: payload.mealType,
    notes: payload.notes,
    selectionCount: payload.selections.length,
    selections: payload.selections
  };
  hilog.info(SYNC_LOG_DOMAIN, SYNC_LOG_TAG, 'food_meal start %{public}s', serializeSyncLogValue(startLog));
  let remotePlans = await fetchFoodPlans(state.apiBaseUrlText, authSession, payload.date, payload.date);
  let mealPlans: FoodPlanItem[] = [];
  for (let index = 0; index < remotePlans.length; index++) {
    if (remotePlans[index].date === payload.date && remotePlans[index].mealType === payload.mealType) {
      mealPlans.push(remotePlans[index]);
    }
  }
  let fetchedLog: SyncFoodMealFetchedLog = {
    date: payload.date,
    mealType: payload.mealType,
    remoteMealPlanCount: mealPlans.length
  };
  hilog.info(SYNC_LOG_DOMAIN, SYNC_LOG_TAG, 'food_meal fetched %{public}s', serializeSyncLogValue(fetchedLog));
  for (let index = 0; index < mealPlans.length; index++) {
    await deleteFoodPlanRemote(state.apiBaseUrlText, authSession, mealPlans[index].id);
  }
  let deletedLog: SyncFoodMealDeletedLog = {
    date: payload.date,
    mealType: payload.mealType,
    deletedCount: mealPlans.length
  };
  hilog.info(SYNC_LOG_DOMAIN, SYNC_LOG_TAG, 'food_meal deleted %{public}s', serializeSyncLogValue(deletedLog));

  let nextMealPlans: FoodPlanItem[] = [];
  for (let index = 0; index < payload.selections.length; index++) {
    let currentSelection = payload.selections[index];
    for (let countIndex = 0; countIndex < currentSelection.count; countIndex++) {
      nextMealPlans.push(await createFoodPlanRemote(state.apiBaseUrlText, authSession, {
        date: payload.date,
        foodId: currentSelection.foodId,
        mealType: payload.mealType,
        notes: payload.notes
      }));
    }
  }
  let createdLog: SyncFoodMealCreatedLog = {
    date: payload.date,
    mealType: payload.mealType,
    createdCount: nextMealPlans.length
  };
  hilog.info(SYNC_LOG_DOMAIN, SYNC_LOG_TAG, 'food_meal created %{public}s', serializeSyncLogValue(createdLog));

  let nextState = copySyncState(state);
  nextState.foodPlanText = replaceLocalFoodMeal(state.foodPlanText, payload.date, payload.mealType, nextMealPlans);
  return nextState;
}

async function syncWorkoutTemplateOperation(state: SyncRuntimeState, authSession: AuthSession,
  operation: PendingSyncOperation): Promise<SyncRuntimeState> {
  let payload = JSON.parse(operation.payloadText) as WorkoutTemplateSyncPayload;
  let currentTemplate = payload.template;

  if (operation.action === 'delete') {
    if (!isLocalOnlyId(operation.entityKey)) {
      await deleteWorkoutTemplateRemote(state.apiBaseUrlText, authSession, operation.entityKey);
    }
    let deletedState = copySyncState(state);
    deletedState.savedCustomWorkoutText = removeLocalWorkoutTemplate(state.savedCustomWorkoutText, operation.entityKey);
    return deletedState;
  }

  let remoteTemplate = await saveWorkoutTemplateRemote(state.apiBaseUrlText, authSession,
    isLocalOnlyId(currentTemplate.id) ? '' : currentTemplate.id,
    {
      identityKey: buildSavedWorkoutIdentityKey(currentTemplate.name),
      name: currentTemplate.name,
      mode: currentTemplate.mode,
      intensity: currentTemplate.intensity,
      durationMinutes: currentTemplate.durationMinutes,
      distanceKm: currentTemplate.distanceKm,
      paceMinutes: currentTemplate.paceMinutes,
      speedKmH: currentTemplate.speedKmH,
      count: currentTemplate.count,
      cadencePerMinute: currentTemplate.cadencePerMinute,
      sets: currentTemplate.sets,
      workSeconds: currentTemplate.workSeconds,
      restSeconds: currentTemplate.restSeconds
    });
  if (isLocalOnlyId(currentTemplate.id) && currentTemplate.id !== remoteTemplate.id) {
    let replacedState = replaceEntityIdInState(state, currentTemplate.id, remoteTemplate.id);
    let nextState = copySyncState(replacedState);
    nextState.savedCustomWorkoutText = upsertLocalWorkoutTemplate(replacedState.savedCustomWorkoutText, remoteTemplate);
    return nextState;
  }
  let nextState = copySyncState(state);
  nextState.savedCustomWorkoutText = upsertLocalWorkoutTemplate(state.savedCustomWorkoutText, remoteTemplate);
  return nextState;
}

async function syncWorkoutPlanOperation(state: SyncRuntimeState, authSession: AuthSession, operation: PendingSyncOperation): Promise<SyncRuntimeState> {
  if (operation.action === 'delete') {
    let payload = JSON.parse(operation.payloadText) as DeleteWorkoutPlanPayload;
    if (!isLocalOnlyId(payload.id)) {
      await deleteWorkoutPlanRemote(state.apiBaseUrlText, authSession, payload.id);
    }
    let deletedState = copySyncState(state);
    deletedState.workoutPlanText = removeLocalWorkoutPlan(state.workoutPlanText, payload.id);
    deletedState.workoutPlanMetaText = removeLocalWorkoutPlanMeta(state.workoutPlanMetaText, payload.id);
    return deletedState;
  }

  let payload = JSON.parse(operation.payloadText) as WorkoutPlanSyncPayload;
  let currentPlan = payload.plan;
  let remotePlan = await createWorkoutPlanRemote(state.apiBaseUrlText, authSession, {
    date: currentPlan.date,
    title: currentPlan.title,
    notes: currentPlan.notes,
    savedWorkoutId: currentPlan.savedWorkoutId,
    draftText: currentPlan.draftText
  }, currentPlan.goalType, currentPlan.goalValue);
  let mergedRemotePlan = mergeSyncedWorkoutPlan(currentPlan, remotePlan);
  let nextState = state;
  if (isLocalOnlyId(currentPlan.id) && currentPlan.id !== mergedRemotePlan.id) {
    nextState = replaceEntityIdInState(state, currentPlan.id, mergedRemotePlan.id);
  }
  let mergedState = copySyncState(nextState);
  mergedState.workoutPlanText = upsertLocalWorkoutPlan(nextState.workoutPlanText, mergedRemotePlan);
  mergedState.workoutPlanMetaText = serializeWorkoutPlanLocalMeta(upsertWorkoutPlanMeta(
    deserializeWorkoutPlanLocalMeta(nextState.workoutPlanMetaText),
    {
      planId: mergedRemotePlan.id,
      goalType: mergedRemotePlan.goalType,
      goalValue: mergedRemotePlan.goalValue,
      manuallyCompleted: mergedRemotePlan.manuallyCompleted,
      collapsed: mergedRemotePlan.collapsed
    }
  ));
  return mergedState;
}

async function syncWorkoutRecordOperation(state: SyncRuntimeState, authSession: AuthSession,
  operation: PendingSyncOperation): Promise<SyncRuntimeState> {
  let payload = JSON.parse(operation.payloadText) as WorkoutRecordSyncPayload;
  let draft = deserializeExerciseDraft(payload.draftText);
  let remoteRecord = await createWorkoutRecordRemote(state.apiBaseUrlText, authSession, {
    date: payload.record.date,
    exerciseId: payload.record.exerciseId,
    name: payload.record.name,
    calories: payload.record.calories,
    durationSeconds: payload.record.durationSeconds,
    planId: payload.record.planId,
    distanceKm: payload.record.distanceKm,
    count: payload.record.count,
    configSnapshot: {
      exerciseId: draft.exerciseId,
      customName: draft.customName,
      customMode: draft.customMode,
      customIntensity: draft.customIntensity,
      durationMinutes: draft.durationMinutes,
      distanceKm: draft.distanceKm,
      paceMinutes: draft.paceMinutes,
      speedKmH: draft.speedKmH,
      count: draft.count,
      cadencePerMinute: draft.cadencePerMinute,
      sets: draft.sets,
      workSeconds: draft.workSeconds,
      restSeconds: draft.restSeconds
    }
  });
  let nextState = state;
  if (isLocalOnlyId(payload.record.id) && payload.record.id !== remoteRecord.id) {
    nextState = replaceEntityIdInState(state, payload.record.id, remoteRecord.id);
  }
  let mergedState = copySyncState(nextState);
  mergedState.workoutRecordText = upsertLocalWorkoutRecord(nextState.workoutRecordText, remoteRecord);
  return mergedState;
}

async function syncSingleOperation(state: SyncRuntimeState, authSession: AuthSession,
  operation: PendingSyncOperation): Promise<SyncRuntimeState> {
  if (operation.entityType === 'profile') {
    return await syncProfileOperation(state, authSession, operation);
  }
  if (operation.entityType === 'weight') {
    return await syncWeightOperation(state, authSession, operation);
  }
  if (operation.entityType === 'food_option') {
    return await syncFoodOptionOperation(state, authSession, operation);
  }
  if (operation.entityType === 'food_meal') {
    return await syncFoodMealOperation(state, authSession, operation);
  }
  if (operation.entityType === 'workout_template') {
    return await syncWorkoutTemplateOperation(state, authSession, operation);
  }
  if (operation.entityType === 'workout_plan') {
    return await syncWorkoutPlanOperation(state, authSession, operation);
  }
  if (operation.entityType === 'workout_record') {
    return await syncWorkoutRecordOperation(state, authSession, operation);
  }
  return state;
}

export async function syncOperationNowOrQueue(state: SyncRuntimeState,
  operation: PendingSyncOperation): Promise<ImmediateSyncResult> {
  let nextState: SyncRuntimeState = copySyncState(state);
  nextState.lastSyncAttemptText = `${Date.now()}`;
  let authSession = deserializeAuthSession(nextState.authSessionText);
  if (!isAuthSessionValid(authSession)) {
    nextState.pendingSyncQueueText = queuePendingOperation(nextState.pendingSyncQueueText, operation);
    return {
      state: nextState,
      syncedImmediately: false,
      queuedForLater: true,
      errorMessage: ''
    };
  }

  try {
    let syncedState = await syncSingleOperation(nextState, authSession, operation);
    syncedState.pendingSyncQueueText = removePendingOperationByEntityKey(
      syncedState.pendingSyncQueueText,
      operation.entityType,
      operation.entityKey
    );
    syncedState.lastSyncSuccessText = `${Date.now()}`;
    return {
      state: syncedState,
      syncedImmediately: true,
      queuedForLater: false,
      errorMessage: ''
    };
  } catch (error) {
    let errorText = `${error}`;
    let failedState = copySyncState(nextState);
    failedState.pendingSyncQueueText = queuePendingOperation(failedState.pendingSyncQueueText, operation);
    let operationErrorLog: SyncOperationErrorLog = {
      id: operation.id,
      entityType: operation.entityType,
      action: operation.action,
      entityKey: operation.entityKey,
      error: errorText
    };
    hilog.error(SYNC_LOG_DOMAIN, SYNC_LOG_TAG, 'immediate sync failed %{public}s', serializeSyncLogValue(operationErrorLog));
    return {
      state: failedState,
      syncedImmediately: false,
      queuedForLater: true,
      errorMessage: errorText
    };
  }
}

export async function syncPendingOperations(state: SyncRuntimeState): Promise<SyncExecutionResult> {
  let authSession = deserializeAuthSession(state.authSessionText);
  let nextState: SyncRuntimeState = copySyncState(state);
  nextState.lastSyncAttemptText = `${Date.now()}`;
  if (!isAuthSessionValid(authSession)) {
    return {
      state: nextState,
      syncedCount: 0,
      lastErrorMessage: ''
    };
  }

  let syncedCount = 0;
  let lastErrorMessage = '';
  let guardCount = 0;
  while (guardCount < 50) {
    guardCount += 1;
    let queueItems = deserializePendingSyncOperations(nextState.pendingSyncQueueText);
    if (queueItems.length === 0) {
      break;
    }
    let currentOperation = queueItems[0];
    let operationLog: SyncOperationLog = {
      id: currentOperation.id,
      entityType: currentOperation.entityType,
      action: currentOperation.action,
      entityKey: currentOperation.entityKey
    };
    hilog.info(SYNC_LOG_DOMAIN, SYNC_LOG_TAG, 'sync operation %{public}s', serializeSyncLogValue(operationLog));
    try {
      nextState = await syncSingleOperation(nextState, authSession, currentOperation);
      nextState.pendingSyncQueueText = removePendingOperation(nextState.pendingSyncQueueText, currentOperation.id);
      nextState.lastSyncSuccessText = `${Date.now()}`;
      syncedCount += 1;
    } catch (error) {
      lastErrorMessage = `${error}`;
      let operationErrorLog: SyncOperationErrorLog = {
        id: currentOperation.id,
        entityType: currentOperation.entityType,
        action: currentOperation.action,
        entityKey: currentOperation.entityKey,
        error: lastErrorMessage
      };
      hilog.error(SYNC_LOG_DOMAIN, SYNC_LOG_TAG, 'sync operation failed %{public}s', serializeSyncLogValue(operationErrorLog));
      break;
    }
  }

  return {
    state: nextState,
    syncedCount: syncedCount,
    lastErrorMessage: lastErrorMessage
  };
}
