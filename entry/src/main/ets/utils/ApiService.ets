import http from '@ohos.net.http';
import { FoodOption } from '../models/FoodOption';
import { FoodPlanItem } from '../models/FoodPlan';
import { UserProfile } from '../models/UserProfile';
import { WeightRecord } from '../models/WeightRecord';
import { WorkoutPlanItem } from '../models/WorkoutPlan';
import { SavedCustomWorkout } from '../models/ExerciseOption';
import { WorkoutRecord } from '../models/WorkoutRecord';
import { AuthSession, createEmptyAuthSession } from '../models/AuthSession';
import {
  BackendFoodOption,
  BackendFoodPlan,
  BackendWeightRecord,
  BackendWorkoutType,
  BackendWorkoutPlan,
  BackendWorkoutRecord,
  BackendWorkoutTemplate,
  CreateFoodOptionPayload,
  CreateFoodPlanPayload,
  CreateWorkoutPlanPayload,
  CreateWorkoutRecordPayload,
  CreateWorkoutTemplatePayload,
  LoginRequestPayload,
  LoginResponseData,
  UpdateFoodPlanPayload,
  UpdateWeightPayload,
  WeightSummaryResponseData,
  WorkoutDailySummaryResponseData,
  WorkoutPlanLocalMeta
} from '../models/BackendApi';
import { requestApiData } from './ApiClient';
import { serializeAuthSession } from './AuthStorageHelper';
import {
  WORKOUT_PLAN_GOAL_DURATION,
  getWorkoutPlanGoalFromDraft
} from './WorkoutPlanHelper';
import { deserializeExerciseDraft } from './ExerciseHelper';

interface FoodOptionsResponseData {
  items: BackendFoodOption[];
}

interface FoodPlansResponseData {
  plans: BackendFoodPlan[];
}

interface WorkoutPlansResponseData {
  plans: BackendWorkoutPlan[];
}

interface WorkoutTypesResponseData {
  items: BackendWorkoutType[];
}

interface WorkoutRecordsResponseData {
  items?: BackendWorkoutRecord[];
  records?: BackendWorkoutRecord[];
}

interface WorkoutTemplatesResponseData {
  items?: BackendWorkoutTemplate[];
  templates?: BackendWorkoutTemplate[];
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

function sanitizeBoolean(value: boolean | string | number | undefined | null, fallbackValue: boolean = false): boolean {
  if (typeof value === 'boolean') {
    return value;
  }
  if (value === undefined || value === null) {
    return fallbackValue;
  }
  return `${value}` === 'true' || `${value}` === '1';
}

export interface RemoteWeightSummary {
  latestRecord?: WeightRecord;
  previousRecord?: WeightRecord;
  recentCount: number;
  averageWeight: number;
  changeInRange: number;
  changeFromPrevious: number;
}

export interface RemoteWorkoutDailySummary {
  date: string;
  workoutCount: number;
  totalCalories: number;
  totalDurationSeconds: number;
}

export interface LoginResult {
  authSession: AuthSession;
  authSessionText: string;
}

export interface SyncedWorkoutPlansResult {
  plans: WorkoutPlanItem[];
  metaItems: WorkoutPlanLocalMeta[];
}

export function createEmptyRemoteWeightSummary(): RemoteWeightSummary {
  return {
    latestRecord: undefined,
    previousRecord: undefined,
    recentCount: 0,
    averageWeight: 0,
    changeInRange: 0,
    changeFromPrevious: 0
  };
}

export function createEmptyWorkoutDailySummary(): RemoteWorkoutDailySummary {
  return {
    date: '',
    workoutCount: 0,
    totalCalories: 0,
    totalDurationSeconds: 0
  };
}

function mapBackendWeightRecord(record: BackendWeightRecord): WeightRecord {
  return {
    id: sanitizeString(record.id),
    date: sanitizeString(record.date),
    weight: sanitizeNumber(record.weight)
  };
}

function mapBackendFoodOption(option: BackendFoodOption): FoodOption {
  return {
    id: sanitizeString(option.id),
    name: sanitizeString(option.name),
    description: sanitizeString(option.description),
    calories: sanitizeNumber(option.calories),
    serving: sanitizeString(option.serving),
    mealSuggestion: sanitizeString(option.mealSuggestion),
    image: sanitizeString(option.image),
    accentColor: sanitizeString(option.accentColor, '#D86C3D')
  };
}

function mapBackendFoodPlan(plan: BackendFoodPlan): FoodPlanItem {
  return {
    id: sanitizeString(plan.id),
    date: sanitizeString(plan.date),
    foodId: sanitizeString(plan.foodId),
    name: sanitizeString(plan.name),
    description: sanitizeString(plan.description),
    calories: sanitizeNumber(plan.calories),
    serving: sanitizeString(plan.serving),
    mealType: sanitizeString(plan.mealType, 'breakfast'),
    image: sanitizeString(plan.image),
    notes: sanitizeString(plan.notes),
    accentColor: sanitizeString(plan.accentColor, '#D86C3D')
  };
}

function mapBackendWorkoutRecord(record: BackendWorkoutRecord): WorkoutRecord {
  return {
    id: sanitizeString(record.id),
    date: sanitizeString(record.date),
    name: sanitizeString(record.name),
    calories: sanitizeNumber(record.calories),
    durationSeconds: sanitizeNumber(record.durationSeconds),
    exerciseId: sanitizeString(record.exerciseId),
    planId: sanitizeString(record.planId),
    distanceKm: sanitizeNumber(record.distanceKm),
    count: sanitizeNumber(record.count)
  };
}

function mapBackendWorkoutTemplate(template: BackendWorkoutTemplate): SavedCustomWorkout {
  return {
    id: sanitizeString(template.id),
    name: sanitizeString(template.name),
    mode: sanitizeString(template.mode, 'duration'),
    intensity: sanitizeString(template.intensity, 'moderate'),
    durationMinutes: sanitizeString(template.durationMinutes, '30'),
    distanceKm: sanitizeString(template.distanceKm, '0'),
    paceMinutes: sanitizeString(template.paceMinutes, '0'),
    speedKmH: sanitizeString(template.speedKmH, '0'),
    count: sanitizeString(template.count, '0'),
    cadencePerMinute: sanitizeString(template.cadencePerMinute, '0'),
    sets: sanitizeString(template.sets, '0'),
    workSeconds: sanitizeString(template.workSeconds, '0'),
    restSeconds: sanitizeString(template.restSeconds, '0')
  };
}

export async function fetchWorkoutTypes(baseUrl: string, authSession: AuthSession): Promise<BackendWorkoutType[]> {
  let data = await requestApiData<WorkoutTypesResponseData>({
    baseUrl: baseUrl,
    path: '/workout-types',
    method: http.RequestMethod.GET,
    authSession: authSession
  });
  return data.items;
}

function buildMetaFromDraftText(planId: string, draftText: string): WorkoutPlanLocalMeta {
  let fallbackDraft = deserializeExerciseDraft(sanitizeString(draftText));
  let goal = getWorkoutPlanGoalFromDraft(fallbackDraft);
  return {
    planId: planId,
    goalType: goal.goalType,
    goalValue: goal.goalValue,
    manuallyCompleted: false,
    collapsed: false
  };
}

function findPlanMeta(metaItems: WorkoutPlanLocalMeta[], planId: string): WorkoutPlanLocalMeta | undefined {
  for (let index = 0; index < metaItems.length; index++) {
    if (metaItems[index].planId === planId) {
      return metaItems[index];
    }
  }
  return undefined;
}

function mergeBackendWorkoutPlan(plan: BackendWorkoutPlan, metaItems: WorkoutPlanLocalMeta[]): WorkoutPlanItem {
  let meta = findPlanMeta(metaItems, sanitizeString(plan.id));
  if (!meta) {
    meta = buildMetaFromDraftText(sanitizeString(plan.id), sanitizeString(plan.draftText));
  }
  return {
    id: sanitizeString(plan.id),
    date: sanitizeString(plan.date),
    title: sanitizeString(plan.title),
    summary: sanitizeString(plan.summary),
    notes: sanitizeString(plan.notes),
    draftText: sanitizeString(plan.draftText),
    savedWorkoutId: sanitizeString(plan.savedWorkoutId),
    accentColor: sanitizeString(plan.accentColor, '#0F6BFF'),
    goalType: sanitizeString(meta.goalType, WORKOUT_PLAN_GOAL_DURATION),
    goalValue: sanitizeNumber(meta.goalValue, 30),
    manuallyCompleted: sanitizeBoolean(meta.manuallyCompleted),
    collapsed: sanitizeBoolean(meta.collapsed)
  };
}

export function upsertWorkoutPlanMeta(metaItems: WorkoutPlanLocalMeta[], nextItem: WorkoutPlanLocalMeta): WorkoutPlanLocalMeta[] {
  let nextMetaItems: WorkoutPlanLocalMeta[] = [];
  let hasUpdated = false;
  for (let index = 0; index < metaItems.length; index++) {
    if (metaItems[index].planId === nextItem.planId) {
      nextMetaItems.push(nextItem);
      hasUpdated = true;
    } else {
      nextMetaItems.push(metaItems[index]);
    }
  }
  if (!hasUpdated) {
    nextMetaItems.push(nextItem);
  }
  return nextMetaItems;
}

export function removeWorkoutPlanMeta(metaItems: WorkoutPlanLocalMeta[], planId: string): WorkoutPlanLocalMeta[] {
  let nextMetaItems: WorkoutPlanLocalMeta[] = [];
  for (let index = 0; index < metaItems.length; index++) {
    if (metaItems[index].planId !== planId) {
      nextMetaItems.push(metaItems[index]);
    }
  }
  return nextMetaItems;
}

export async function loginWithPassword(baseUrl: string, username: string, password: string): Promise<LoginResult> {
  let payload: LoginRequestPayload = {
    username: username.trim(),
    password: password
  };
  let data = await requestApiData<LoginResponseData>({
    baseUrl: baseUrl,
    path: '/auth/login',
    method: http.RequestMethod.POST,
    body: payload
  });
  let authSession: AuthSession = {
    userId: sanitizeString(data.userId),
    username: sanitizeString(data.username, username.trim()),
    token: sanitizeString(data.token),
    loginAt: `${Date.now()}`
  };
  return {
    authSession: authSession,
    authSessionText: serializeAuthSession(authSession)
  };
}

export function logoutSession(): LoginResult {
  let authSession = createEmptyAuthSession();
  return {
    authSession: authSession,
    authSessionText: serializeAuthSession(authSession)
  };
}

export async function fetchUserProfile(baseUrl: string, authSession: AuthSession): Promise<UserProfile> {
  return await requestApiData<UserProfile>({
    baseUrl: baseUrl,
    path: '/user-profile',
    method: http.RequestMethod.GET,
    authSession: authSession
  });
}

export async function updateUserProfileRemote(baseUrl: string, authSession: AuthSession, profile: UserProfile): Promise<UserProfile> {
  return await requestApiData<UserProfile>({
    baseUrl: baseUrl,
    path: '/user-profile',
    method: http.RequestMethod.PUT,
    authSession: authSession,
    body: profile
  });
}

export async function fetchWeightRecords(baseUrl: string, authSession: AuthSession, startDate: string, endDate: string): Promise<WeightRecord[]> {
  let data = await requestApiData<BackendWeightRecord[]>({
    baseUrl: baseUrl,
    path: '/weight-records',
    method: http.RequestMethod.GET,
    authSession: authSession,
    queryParams: [
      { key: 'startDate', value: startDate },
      { key: 'endDate', value: endDate }
    ]
  });
  let records: WeightRecord[] = [];
  for (let index = 0; index < data.length; index++) {
    records.push(mapBackendWeightRecord(data[index]));
  }
  return records;
}

export async function fetchWeightSummary(baseUrl: string, authSession: AuthSession, days: number): Promise<RemoteWeightSummary> {
  let data = await requestApiData<WeightSummaryResponseData>({
    baseUrl: baseUrl,
    path: '/weight-records/summary',
    method: http.RequestMethod.GET,
    authSession: authSession,
    queryParams: [{ key: 'days', value: `${days}` }]
  });
  return {
    latestRecord: data.latestRecord ? mapBackendWeightRecord(data.latestRecord) : undefined,
    previousRecord: data.previousRecord ? mapBackendWeightRecord(data.previousRecord) : undefined,
    recentCount: sanitizeNumber(data.recentCount),
    averageWeight: sanitizeNumber(data.averageWeight),
    changeInRange: sanitizeNumber(data.changeInRange),
    changeFromPrevious: sanitizeNumber(data.changeFromPrevious)
  };
}

export async function upsertWeightRecordRemote(baseUrl: string, authSession: AuthSession, dateText: string, weight: number): Promise<WeightRecord> {
  let payload: UpdateWeightPayload = {
    weight: weight
  };
  let data = await requestApiData<BackendWeightRecord>({
    baseUrl: baseUrl,
    path: `/weight-records/${encodeURIComponent(dateText)}`,
    method: http.RequestMethod.PUT,
    authSession: authSession,
    body: payload
  });
  return mapBackendWeightRecord(data);
}

export async function fetchFoodOptions(baseUrl: string, authSession: AuthSession): Promise<FoodOption[]> {
  let data = await requestApiData<FoodOptionsResponseData>({
    baseUrl: baseUrl,
    path: '/food-options',
    method: http.RequestMethod.GET,
    authSession: authSession,
    queryParams: [
      { key: 'includePreset', value: 'true' },
      { key: 'includeCustom', value: 'true' }
    ]
  });
  let options: FoodOption[] = [];
  for (let index = 0; index < data.items.length; index++) {
    options.push(mapBackendFoodOption(data.items[index]));
  }
  return options;
}

export async function createCustomFoodOptionRemote(baseUrl: string, authSession: AuthSession, payload: CreateFoodOptionPayload): Promise<FoodOption> {
  let data = await requestApiData<BackendFoodOption>({
    baseUrl: baseUrl,
    path: '/food-options/custom',
    method: http.RequestMethod.POST,
    authSession: authSession,
    body: payload
  });
  return mapBackendFoodOption(data);
}

export async function updateCustomFoodOptionRemote(baseUrl: string, authSession: AuthSession,
  foodId: string, payload: CreateFoodOptionPayload): Promise<FoodOption> {
  let data = await requestApiData<BackendFoodOption>({
    baseUrl: baseUrl,
    path: `/food-options/custom/${encodeURIComponent(foodId)}`,
    method: http.RequestMethod.PUT,
    authSession: authSession,
    body: payload
  });
  return mapBackendFoodOption(data);
}

export async function deleteCustomFoodOptionRemote(baseUrl: string, authSession: AuthSession, foodId: string): Promise<void> {
  await requestApiData<Object>({
    baseUrl: baseUrl,
    path: `/food-options/custom/${encodeURIComponent(foodId)}`,
    method: http.RequestMethod.DELETE,
    authSession: authSession
  });
}

export async function fetchFoodPlans(baseUrl: string, authSession: AuthSession, startDate: string, endDate: string): Promise<FoodPlanItem[]> {
  let data = await requestApiData<FoodPlansResponseData>({
    baseUrl: baseUrl,
    path: '/food-plans',
    method: http.RequestMethod.GET,
    authSession: authSession,
    queryParams: [
      { key: 'startDate', value: startDate },
      { key: 'endDate', value: endDate }
    ]
  });
  let plans: FoodPlanItem[] = [];
  for (let index = 0; index < data.plans.length; index++) {
    plans.push(mapBackendFoodPlan(data.plans[index]));
  }
  return plans;
}

export async function createFoodPlanRemote(baseUrl: string, authSession: AuthSession, payload: CreateFoodPlanPayload): Promise<FoodPlanItem> {
  let data = await requestApiData<BackendFoodPlan>({
    baseUrl: baseUrl,
    path: '/food-plans',
    method: http.RequestMethod.POST,
    authSession: authSession,
    body: payload
  });
  return mapBackendFoodPlan(data);
}

export async function updateFoodPlanRemote(baseUrl: string, authSession: AuthSession,
  planId: string, payload: UpdateFoodPlanPayload): Promise<FoodPlanItem> {
  let data = await requestApiData<BackendFoodPlan>({
    baseUrl: baseUrl,
    path: `/food-plans/${encodeURIComponent(planId)}`,
    method: http.RequestMethod.PUT,
    authSession: authSession,
    body: payload
  });
  return mapBackendFoodPlan(data);
}

export async function deleteFoodPlanRemote(baseUrl: string, authSession: AuthSession, planId: string): Promise<void> {
  await requestApiData<Object>({
    baseUrl: baseUrl,
    path: `/food-plans/${encodeURIComponent(planId)}`,
    method: http.RequestMethod.DELETE,
    authSession: authSession
  });
}

export async function fetchWorkoutTemplates(baseUrl: string, authSession: AuthSession): Promise<SavedCustomWorkout[]> {
  let data = await requestApiData<WorkoutTemplatesResponseData>({
    baseUrl: baseUrl,
    path: '/workout-templates',
    method: http.RequestMethod.GET,
    authSession: authSession
  });
  let sourceItems = data.items ? data.items : (data.templates ? data.templates : []);
  let templates: SavedCustomWorkout[] = [];
  for (let index = 0; index < sourceItems.length; index++) {
    templates.push(mapBackendWorkoutTemplate(sourceItems[index]));
  }
  return templates;
}

export async function saveWorkoutTemplateRemote(baseUrl: string, authSession: AuthSession,
  templateId: string, payload: CreateWorkoutTemplatePayload): Promise<SavedCustomWorkout> {
  let path = templateId.trim().length > 0 ? `/workout-templates/${encodeURIComponent(templateId)}` : '/workout-templates';
  let method = templateId.trim().length > 0 ? http.RequestMethod.PUT : http.RequestMethod.POST;
  let data = await requestApiData<BackendWorkoutTemplate>({
    baseUrl: baseUrl,
    path: path,
    method: method,
    authSession: authSession,
    body: payload
  });
  return mapBackendWorkoutTemplate(data);
}

export async function deleteWorkoutTemplateRemote(baseUrl: string, authSession: AuthSession, templateId: string): Promise<void> {
  await requestApiData<Object>({
    baseUrl: baseUrl,
    path: `/workout-templates/${encodeURIComponent(templateId)}`,
    method: http.RequestMethod.DELETE,
    authSession: authSession
  });
}

export async function fetchWorkoutPlans(baseUrl: string, authSession: AuthSession, startDate: string, endDate: string,
  metaItems: WorkoutPlanLocalMeta[]): Promise<SyncedWorkoutPlansResult> {
  let data = await requestApiData<WorkoutPlansResponseData>({
    baseUrl: baseUrl,
    path: '/workout-plans',
    method: http.RequestMethod.GET,
    authSession: authSession,
    queryParams: [
      { key: 'startDate', value: startDate },
      { key: 'endDate', value: endDate }
    ]
  });
  let plans: WorkoutPlanItem[] = [];
  let nextMetaItems: WorkoutPlanLocalMeta[] = metaItems.slice();
  for (let index = 0; index < data.plans.length; index++) {
    let currentPlan = mergeBackendWorkoutPlan(data.plans[index], nextMetaItems);
    plans.push(currentPlan);
    nextMetaItems = upsertWorkoutPlanMeta(nextMetaItems, {
      planId: currentPlan.id,
      goalType: currentPlan.goalType,
      goalValue: currentPlan.goalValue,
      manuallyCompleted: currentPlan.manuallyCompleted,
      collapsed: currentPlan.collapsed
    });
  }
  return {
    plans: plans,
    metaItems: nextMetaItems
  };
}

export async function createWorkoutPlanRemote(baseUrl: string, authSession: AuthSession,
  payload: CreateWorkoutPlanPayload, goalType: string, goalValue: number): Promise<WorkoutPlanItem> {
  let data = await requestApiData<BackendWorkoutPlan>({
    baseUrl: baseUrl,
    path: '/workout-plans',
    method: http.RequestMethod.POST,
    authSession: authSession,
    body: payload
  });
  return mergeBackendWorkoutPlan(data, [{
    planId: sanitizeString(data.id),
    goalType: goalType,
    goalValue: goalValue,
    manuallyCompleted: false,
    collapsed: false
  }]);
}

export async function deleteWorkoutPlanRemote(baseUrl: string, authSession: AuthSession, planId: string): Promise<void> {
  await requestApiData<Object>({
    baseUrl: baseUrl,
    path: `/workout-plans/${encodeURIComponent(planId)}`,
    method: http.RequestMethod.DELETE,
    authSession: authSession
  });
}

export async function fetchWorkoutRecords(baseUrl: string, authSession: AuthSession, startDate: string, endDate: string): Promise<WorkoutRecord[]> {
  let data = await requestApiData<WorkoutRecordsResponseData>({
    baseUrl: baseUrl,
    path: '/workout-records',
    method: http.RequestMethod.GET,
    authSession: authSession,
    queryParams: [
      { key: 'startDate', value: startDate },
      { key: 'endDate', value: endDate }
    ]
  });
  let sourceItems = data.items ? data.items : (data.records ? data.records : []);
  let records: WorkoutRecord[] = [];
  for (let index = 0; index < sourceItems.length; index++) {
    records.push(mapBackendWorkoutRecord(sourceItems[index]));
  }
  return records;
}

export async function fetchWorkoutDailySummary(baseUrl: string, authSession: AuthSession, dateText: string): Promise<RemoteWorkoutDailySummary> {
  let data = await requestApiData<WorkoutDailySummaryResponseData>({
    baseUrl: baseUrl,
    path: '/workout-records/daily-summary',
    method: http.RequestMethod.GET,
    authSession: authSession,
    queryParams: [{ key: 'date', value: dateText }]
  });
  return {
    date: sanitizeString(data.date),
    workoutCount: sanitizeNumber(data.workoutCount),
    totalCalories: sanitizeNumber(data.totalCalories),
    totalDurationSeconds: sanitizeNumber(data.totalDurationSeconds)
  };
}

export async function createWorkoutRecordRemote(baseUrl: string, authSession: AuthSession,
  payload: CreateWorkoutRecordPayload): Promise<WorkoutRecord> {
  let data = await requestApiData<BackendWorkoutRecord>({
    baseUrl: baseUrl,
    path: '/workout-records',
    method: http.RequestMethod.POST,
    authSession: authSession,
    body: payload
  });
  return mapBackendWorkoutRecord(data);
}
