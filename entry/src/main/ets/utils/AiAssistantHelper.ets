import http from '@ohos.net.http';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  AI_ROLE_ASSISTANT,
  AI_ROLE_USER,
  AI_TASK_CHAT,
  AI_TASK_ANALYZE_WEIGHT,
  AI_TASK_GENERATE_FULL_PLAN,
  AI_TASK_GENERATE_PLAN,
  AI_TASK_GENERATE_RECIPE,
  AI_TASK_DAILY_BRIEFING,
  AiAssistantConfig,
  AiAssistantResponse,
  AiChatMessage,
  AiGeneratedFoodPlanItem,
  AiGeneratedPlanItem
} from '../models/AiAssistant';
import {
  CUSTOM_INTENSITY_MODERATE,
  CUSTOM_INTENSITY_OPTIONS,
  CUSTOM_MODE_OPTIONS,
  EXERCISE_OPTIONS,
  ExerciseDraft,
  createDefaultExerciseDraft
} from '../models/ExerciseOption';
import { FOOD_MEAL_OPTIONS } from '../models/FoodOption';
import { UserProfile } from '../models/UserProfile';
import { WeightRecord } from '../models/WeightRecord';
import { WorkoutRecord } from '../models/WorkoutRecord';
import { getWorkoutTitle, serializeExerciseDraft } from './ExerciseHelper';
import { formatDate, getRecentWeightRecords } from './WeightRecordHelper';
import { buildWorkoutPlanSummary, getWorkoutPlanAccentColor } from './WorkoutPlanHelper';

interface ChatCompletionMessage {
  role: string;
  content: string;
  reasoning_content?: string;
}

interface ChatCompletionChoice {
  message?: ChatCompletionMessage;
}

interface ChatCompletionError {
  message?: string;
}

interface ParsedErrorResponse {
  message?: string | number;
  error?: ChatCompletionError | string | number;
}

interface ChatCompletionResponse {
  choices?: ChatCompletionChoice[];
  error?: ChatCompletionError;
}

interface ChatCompletionRequestBody {
  model: string;
  temperature: number;
  max_tokens: number;
  thinking_budget?: number;
  messages: ChatCompletionMessage[];
  enable_thinking: boolean;
}

interface ParsedPlanPayload {
  date?: string | number;
  title?: string | number;
  summary?: string | number;
  notes?: string | number;
  exerciseId?: string | number;
  customName?: string | number;
  customMode?: string | number;
  customIntensity?: string | number;
  durationMinutes?: string | number;
  distanceKm?: string | number;
  paceMinutes?: string | number;
  speedKmH?: string | number;
  count?: string | number;
  cadencePerMinute?: string | number;
  sets?: string | number;
  workSeconds?: string | number;
  restSeconds?: string | number;
}

interface ParsedFoodPlanPayload {
  date?: string | number;
  mealType?: string | number;
  name?: string | number;
  description?: string | number;
  calories?: string | number;
  serving?: string | number;
  notes?: string | number;
  image?: string | number;
  accentColor?: string | number;
}

interface ParsedAssistantPayload {
  reply?: string;
  plans?: ParsedPlanPayload[];
  foodPlans?: ParsedFoodPlanPayload[];
}

const AI_LOG_DOMAIN: number = 0xFF14;
const AI_LOG_TAG: string = 'AiAssistant';

export interface AiAssistantRequestContext {
  task: string;
  userPrompt: string;
  profile: UserProfile;
  weightRecords: WeightRecord[];
  workoutRecords: WorkoutRecord[];
  existingPlanCount: number;
  existingFoodPlanCount: number;
  dailyFoodCalorieTarget: number;
  savedWorkoutNames: string[];
  historyMessages: AiChatMessage[];
}

export interface AiAssistantRequestOptions {
  onRequestCreated?: (cancelHandler: () => void) => void;
  enableThinking?: boolean;
  thinkingBudget?: number;
  maxTokens?: number;
  readTimeout?: number;
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
  let parsedValue: number = Number(`${value}`);
  return isNaN(parsedValue) ? fallbackValue : parsedValue;
}

function getHttpResponseText(result: string | Object | ArrayBuffer): string {
  if (typeof result === 'string') {
    return result;
  }
  return JSON.stringify(result);
}

function buildLogPreview(text: string, maxLength: number = 180): string {
  let trimmed = text.trim();
  if (trimmed.length <= maxLength) {
    return trimmed;
  }
  return `${trimmed.substring(0, maxLength)}...`;
}

function looksLikeJsonText(text: string): boolean {
  let trimmed = text.trim();
  return trimmed.startsWith('{') || trimmed.startsWith('[');
}

function containsAnyKeyword(text: string, keywords: string[]): boolean {
  for (let index = 0; index < keywords.length; index++) {
    if (text.indexOf(keywords[index]) >= 0) {
      return true;
    }
  }
  return false;
}

export function inferAiAssistantTaskFromPrompt(promptText: string): string {
  let normalizedPrompt = promptText.trim().toLowerCase();
  if (normalizedPrompt.length === 0) {
    return AI_TASK_CHAT;
  }

  let hasWorkoutIntent = containsAnyKeyword(normalizedPrompt, [
    '训练计划',
    '运动计划',
    '健身计划',
    '训练安排',
    '运动安排',
    '训练方案',
    '健身方案',
    '安排训练',
    '安排运动'
  ]);
  let hasFoodIntent = containsAnyKeyword(normalizedPrompt, [
    '饮食计划',
    '食谱',
    '餐单',
    '菜单',
    '配餐',
    '减脂餐',
    '增肌餐',
    '饮食安排',
    '三餐安排',
    '吃什么'
  ]);
  let hasFullPlanIntent = containsAnyKeyword(normalizedPrompt, [
    '制定计划',
    '完整计划',
    '全套计划',
    '综合计划',
    '整体计划',
    '一周计划',
    '周计划',
    '减脂计划',
    '增肌计划',
    '重新制定计划',
    '重新安排计划'
  ]);
  let hasWeightIntent = containsAnyKeyword(normalizedPrompt, [
    '体重分析',
    '分析体重',
    '体重变化',
    '减重建议',
    '增重建议'
  ]);

  if (hasWorkoutIntent && hasFoodIntent) {
    return AI_TASK_GENERATE_FULL_PLAN;
  }
  if (hasFullPlanIntent) {
    return AI_TASK_GENERATE_FULL_PLAN;
  }
  if (hasWorkoutIntent) {
    return AI_TASK_GENERATE_PLAN;
  }
  if (hasFoodIntent) {
    return AI_TASK_GENERATE_RECIPE;
  }
  if (hasWeightIntent) {
    return AI_TASK_ANALYZE_WEIGHT;
  }
  return AI_TASK_CHAT;
}

function getAiMaxTokens(task: string): number {
  if (task === AI_TASK_DAILY_BRIEFING) {
    return 360;
  }
  if (task === AI_TASK_GENERATE_FULL_PLAN) {
    return 2200;
  }
  if (task === AI_TASK_GENERATE_PLAN || task === AI_TASK_GENERATE_RECIPE) {
    return 1000;
  }
  return 600;
}

function getAiThinkingBudget(task: string): number {
  if (task === AI_TASK_GENERATE_FULL_PLAN || task === AI_TASK_GENERATE_PLAN || task === AI_TASK_GENERATE_RECIPE) {
    return 0;
  }
  if (task === AI_TASK_DAILY_BRIEFING) {
    return 48;
  }
  return 64;
}

function shouldEnableAiThinking(task: string): boolean {
  return task !== AI_TASK_GENERATE_FULL_PLAN && task !== AI_TASK_GENERATE_PLAN && task !== AI_TASK_GENERATE_RECIPE;
}

function getAiReadTimeout(task: string): number {
  if (task === AI_TASK_GENERATE_FULL_PLAN || task === AI_TASK_GENERATE_PLAN || task === AI_TASK_GENERATE_RECIPE) {
    return 180000;
  }
  return 90000;
}

function sanitizeAssistantContent(content: string): string {
  let sanitized = content.trim();
  sanitized = sanitized.replace(/<\/?think>/g, '').trim();
  return sanitized;
}

function resolveErrorText(error: Object | string | undefined | null, fallbackMessage: string): string {
  if (typeof error === 'string') {
    let trimmedError = error.trim();
    return trimmedError.length > 0 ? trimmedError : fallbackMessage;
  }

  let rawText = `${error}`;
  if (rawText.trim().length > 0 && rawText !== '[object Object]') {
    return rawText;
  }

  let serializedError = getHttpResponseText(error as Object);
  if (serializedError.trim().length > 0 && serializedError !== '{}') {
    return serializedError;
  }
  return fallbackMessage;
}

function resolveAiResponseErrorMessage(statusCode: number, responseText: string): string {
  let trimmedResponse = responseText.trim();
  if (trimmedResponse.length === 0) {
    return `AI 接口调用失败（${statusCode}）。`;
  }
  if (looksLikeJsonText(trimmedResponse)) {
    try {
      let parsedResponse = JSON.parse(trimmedResponse) as ParsedErrorResponse;
      let parsedMessage = '';
      if (parsedResponse.error && typeof parsedResponse.error === 'object') {
        parsedMessage = sanitizeString((parsedResponse.error as ChatCompletionError).message).trim();
      } else if (typeof parsedResponse.error === 'string' || typeof parsedResponse.error === 'number') {
        parsedMessage = sanitizeString(parsedResponse.error).trim();
      }
      if (parsedMessage.length === 0) {
        parsedMessage = sanitizeString(parsedResponse.message).trim();
      }
      if (parsedMessage.length > 0) {
        return `AI 接口调用失败（${statusCode}）：${parsedMessage}`;
      }
    } catch (error) {
    }
  }
  return `AI 接口调用失败（${statusCode}）：${buildLogPreview(trimmedResponse, 200)}`;
}

function maskSensitiveText(value: string): string {
  let trimmed = value.trim();
  if (trimmed.length <= 12) {
    return '***';
  }
  return `${trimmed.substring(0, 6)}...${trimmed.substring(trimmed.length - 4)}`;
}

function isSupportedExerciseId(exerciseId: string): boolean {
  for (let index = 0; index < EXERCISE_OPTIONS.length; index++) {
    if (EXERCISE_OPTIONS[index].id === exerciseId) {
      return true;
    }
  }
  return false;
}

function normalizeExerciseId(exerciseId: string): string {
  let trimmedId = exerciseId.trim();
  if (isSupportedExerciseId(trimmedId)) {
    return trimmedId;
  }
  return 'custom';
}

function normalizeCustomMode(mode: string): string {
  for (let index = 0; index < CUSTOM_MODE_OPTIONS.length; index++) {
    if (CUSTOM_MODE_OPTIONS[index].id === mode) {
      return mode;
    }
  }
  return CUSTOM_MODE_OPTIONS[0].id;
}

function normalizeCustomIntensity(intensity: string): string {
  for (let index = 0; index < CUSTOM_INTENSITY_OPTIONS.length; index++) {
    if (CUSTOM_INTENSITY_OPTIONS[index].id === intensity) {
      return intensity;
    }
  }
  return CUSTOM_INTENSITY_MODERATE;
}

function normalizeDateText(value: string, fallbackDate: string): string {
  let trimmedValue = value.trim();
  let datePattern = /^\d{4}-\d{2}-\d{2}$/;
  if (datePattern.test(trimmedValue)) {
    return trimmedValue;
  }
  return fallbackDate;
}

function normalizeMealType(mealType: string): string {
  let trimmedMealType = mealType.trim().toLowerCase();
  for (let index = 0; index < FOOD_MEAL_OPTIONS.length; index++) {
    if (FOOD_MEAL_OPTIONS[index].id === trimmedMealType) {
      return trimmedMealType;
    }
  }
  return FOOD_MEAL_OPTIONS[0].id;
}

function getMealAccentColor(mealType: string): string {
  if (mealType === 'breakfast') {
    return '#F59E0B';
  }
  if (mealType === 'lunch') {
    return '#10B981';
  }
  if (mealType === 'dinner') {
    return '#0F6BFF';
  }
  return '#7B61FF';
}

function getMealLabel(mealType: string): string {
  for (let index = 0; index < FOOD_MEAL_OPTIONS.length; index++) {
    if (FOOD_MEAL_OPTIONS[index].id === mealType) {
      return FOOD_MEAL_OPTIONS[index].label;
    }
  }
  return '餐次';
}

function buildSupportedExercisesText(): string {
  let lines: string[] = [];
  for (let index = 0; index < EXERCISE_OPTIONS.length; index++) {
    lines.push(`${EXERCISE_OPTIONS[index].id}: ${EXERCISE_OPTIONS[index].name}`);
  }
  return lines.join('；');
}

function buildSupportedMealTypesText(): string {
  let lines: string[] = [];
  for (let index = 0; index < FOOD_MEAL_OPTIONS.length; index++) {
    lines.push(`${FOOD_MEAL_OPTIONS[index].id}: ${FOOD_MEAL_OPTIONS[index].label}`);
  }
  return lines.join('；');
}

function isWorkoutGenerationTask(task: string): boolean {
  return task === AI_TASK_GENERATE_PLAN || task === AI_TASK_GENERATE_FULL_PLAN;
}

function isFoodGenerationTask(task: string): boolean {
  return task === AI_TASK_GENERATE_RECIPE || task === AI_TASK_GENERATE_FULL_PLAN;
}

function buildHistoryMessages(historyMessages: AiChatMessage[]): ChatCompletionMessage[] {
  let result: ChatCompletionMessage[] = [];
  let startIndex: number = historyMessages.length > 6 ? historyMessages.length - 6 : 0;
  for (let index = startIndex; index < historyMessages.length; index++) {
    let currentMessage = historyMessages[index];
    if (currentMessage.role !== AI_ROLE_USER && currentMessage.role !== AI_ROLE_ASSISTANT) {
      continue;
    }
    result.push({
      role: currentMessage.role,
      content: currentMessage.content
    });
  }
  return result;
}

function buildWeightDataText(weightRecords: WeightRecord[]): string {
  let recentRecords: WeightRecord[] = getRecentWeightRecords(weightRecords, 10);
  if (recentRecords.length === 0) {
    return '[]';
  }

  let items: string[] = [];
  for (let index = 0; index < recentRecords.length; index++) {
    items.push(JSON.stringify({
      date: recentRecords[index].date,
      weightKg: recentRecords[index].weight
    }));
  }
  return `[${items.join(',')}]`;
}

function buildWorkoutDataText(workoutRecords: WorkoutRecord[]): string {
  if (workoutRecords.length === 0) {
    return '[]';
  }

  let copiedRecords: WorkoutRecord[] = workoutRecords.slice();
  copiedRecords.sort((left: WorkoutRecord, right: WorkoutRecord) => {
    if (left.date > right.date) {
      return -1;
    }
    if (left.date < right.date) {
      return 1;
    }
    return 0;
  });
  let recentRecords: WorkoutRecord[] = copiedRecords.slice(0, 8);
  let items: string[] = [];
  for (let index = 0; index < recentRecords.length; index++) {
    items.push(JSON.stringify({
      date: recentRecords[index].date,
      name: recentRecords[index].name,
      calories: recentRecords[index].calories,
      durationSeconds: recentRecords[index].durationSeconds
    }));
  }
  return `[${items.join(',')}]`;
}

function buildSystemPrompt(): string {
  return [
    '你是智卡管家，只返回 JSON 对象，不要 Markdown。',
    '顶层字段：reply 字符串、plans 数组、foodPlans 数组；不需要的数组返回空数组。',
    '必须严格遵守用户要求的生成数量；如果要求 3 到 4 条训练计划，不要为 7 天每天都生成训练。',
    '训练项字段：date,title,summary,notes,exerciseId,customName,customMode,customIntensity,durationMinutes,distanceKm,paceMinutes,speedKmH,count,cadencePerMinute,sets,workSeconds,restSeconds。',
    'exerciseId 只能用：' + buildSupportedExercisesText(),
    'customMode 只能用 duration,set_timer,distance_pace,distance_speed,count_rate；customIntensity 只能用 light,moderate,intense。',
    '饮食项字段：date,mealType,name,description,calories,serving,notes,image,accentColor；mealType 只能用：' + buildSupportedMealTypesText(),
    '输出温和可执行建议，避免医疗诊断、危险训练和极端节食。'
  ].join('\n');
}

function buildUserPrompt(context: AiAssistantRequestContext): string {
  let todayText: string = formatDate(new Date());
  let taskInstruction: string = '请回答用户问题。除非用户明确要求，否则 plans 和 foodPlans 返回空数组。';
  if (context.task === AI_TASK_ANALYZE_WEIGHT) {
    taskInstruction = '请重点分析最近体重变化，并给出 3 条以内可执行建议。plans 和 foodPlans 返回空数组。';
  } else if (context.task === AI_TASK_DAILY_BRIEFING) {
    taskInstruction = '请根据用户问题中提供的今日简报结构，输出 120 字以内的今日健康计划解读。plans 和 foodPlans 返回空数组。';
  } else if (context.task === AI_TASK_GENERATE_PLAN) {
    taskInstruction = '只生成训练 plans。必须输出 {"reply":"80字以内","plans":[训练项],"foodPlans":[]}。plans 总数只能是 3 到 4；foodPlans 必须是空数组；不要生成饮食。';
  } else if (context.task === AI_TASK_GENERATE_RECIPE) {
    taskInstruction = '只生成饮食 foodPlans。必须输出 {"reply":"80字以内","plans":[],"foodPlans":[饮食项]}。plans 必须是空数组；foodPlans 总数按用户要求，未指定时生成 6 到 8 条；如果用户要求一周草案，整周总共 7 条，不要每天三餐。';
  } else if (context.task === AI_TASK_GENERATE_FULL_PLAN) {
    taskInstruction = '同时生成训练和饮食。必须输出 {"reply":"80字以内","plans":[训练项],"foodPlans":[饮食项]}。plans 总数只能是 3 到 4；foodPlans 总数只能是 7；不要每天都生成训练，不要每天三餐。';
  }

  let savedWorkoutHint: string = context.savedWorkoutNames.length > 0
    ? context.savedWorkoutNames.join('、')
    : '无';

  let calorieTargetText: string = context.dailyFoodCalorieTarget > 0
    ? `${context.dailyFoodCalorieTarget} kcal`
    : '未设置';

  return [
    `今天日期：${todayText}`,
    `当前任务：${context.task}`,
    `任务要求：${taskInstruction}`,
    `用户问题：${context.userPrompt}`,
    `用户资料：${JSON.stringify(context.profile)}`,
    `最近体重：${buildWeightDataText(context.weightRecords)}`,
    `最近训练记录：${buildWorkoutDataText(context.workoutRecords)}`,
    `训练页当前已有计划数量：${context.existingPlanCount}`,
    `饮食页当前已有计划数量：${context.existingFoodPlanCount}`,
    `当前饮食热量目标：${calorieTargetText}`,
    `已保存的自定义模板名称：${savedWorkoutHint}`,
    '请让 reply 用中文回答，语气简洁、友好、可执行。'
  ].join('\n');
}

function stripMarkdownCodeFence(text: string): string {
  let trimmedText = text.trim();
  if (trimmedText.startsWith('```')) {
    return trimmedText.replace(/^```[a-zA-Z]*\s*/, '').replace(/\s*```$/, '').trim();
  }
  return trimmedText;
}

function pushUniqueCandidate(candidates: string[], candidate: string): void {
  let trimmedCandidate = candidate.trim();
  if (trimmedCandidate.length === 0) {
    return;
  }
  for (let index = 0; index < candidates.length; index++) {
    if (candidates[index] === trimmedCandidate) {
      return;
    }
  }
  candidates.push(trimmedCandidate);
}

function extractBalancedJsonObject(text: string, startIndex: number): string {
  let depth: number = 0;
  let inString: boolean = false;
  let escaped: boolean = false;

  for (let index = startIndex; index < text.length; index++) {
    let currentChar = text.charAt(index);
    if (inString) {
      if (escaped) {
        escaped = false;
        continue;
      }
      if (currentChar === '\\') {
        escaped = true;
        continue;
      }
      if (currentChar === '"') {
        inString = false;
      }
      continue;
    }

    if (currentChar === '"') {
      inString = true;
      continue;
    }
    if (currentChar === '{') {
      depth += 1;
      continue;
    }
    if (currentChar !== '}') {
      continue;
    }
    depth -= 1;
    if (depth === 0) {
      return text.substring(startIndex, index + 1);
    }
    if (depth < 0) {
      return '';
    }
  }
  return '';
}

function collectJsonObjectCandidates(rawText: string): string[] {
  let normalizedText = stripMarkdownCodeFence(rawText);
  let candidates: string[] = [];
  pushUniqueCandidate(candidates, normalizedText);

  for (let index = 0; index < normalizedText.length; index++) {
    if (normalizedText.charAt(index) !== '{') {
      continue;
    }
    let candidate = extractBalancedJsonObject(normalizedText, index);
    if (candidate.length > 0) {
      pushUniqueCandidate(candidates, candidate);
    }
  }
  return candidates;
}

function isStructuredAssistantPayload(payload: ParsedAssistantPayload | Object | undefined | null): boolean {
  if (!payload || Array.isArray(payload)) {
    return false;
  }
  let structuredPayload = payload as ParsedAssistantPayload;
  return structuredPayload.reply !== undefined ||
    Array.isArray(structuredPayload.plans) ||
    Array.isArray(structuredPayload.foodPlans);
}

function buildStructuredPayloadFallbackReply(rawAssistantText: string): string {
  let trimmedText = rawAssistantText.trim();
  if (trimmedText.length === 0) {
    return 'AI 没有返回可解析内容，请稍后重试。';
  }
  if (looksLikeJsonText(trimmedText) || trimmedText.indexOf('"reply"') >= 0 ||
    trimmedText.indexOf('"plans"') >= 0 || trimmedText.indexOf('"foodPlans"') >= 0) {
    return '';
  }
  return trimmedText;
}

function buildDraftFromPayload(plan: ParsedPlanPayload): ExerciseDraft {
  let draft: ExerciseDraft = createDefaultExerciseDraft();
  let exerciseId: string = normalizeExerciseId(sanitizeString(plan.exerciseId, 'custom'));
  draft.exerciseId = exerciseId;
  draft.customName = sanitizeString(plan.customName);
  draft.customMode = normalizeCustomMode(sanitizeString(plan.customMode, draft.customMode));
  draft.customIntensity = normalizeCustomIntensity(sanitizeString(plan.customIntensity, draft.customIntensity));
  draft.durationMinutes = sanitizeString(plan.durationMinutes, draft.durationMinutes);
  draft.distanceKm = sanitizeString(plan.distanceKm, draft.distanceKm);
  draft.paceMinutes = sanitizeString(plan.paceMinutes, draft.paceMinutes);
  draft.speedKmH = sanitizeString(plan.speedKmH, draft.speedKmH);
  draft.count = sanitizeString(plan.count, draft.count);
  draft.cadencePerMinute = sanitizeString(plan.cadencePerMinute, draft.cadencePerMinute);
  draft.sets = sanitizeString(plan.sets, draft.sets);
  draft.workSeconds = sanitizeString(plan.workSeconds, draft.workSeconds);
  draft.restSeconds = sanitizeString(plan.restSeconds, draft.restSeconds);

  if (exerciseId !== 'custom') {
    draft.customName = '';
  }
  if (exerciseId === 'custom' && draft.customName.trim().length === 0) {
    draft.customName = 'AI 建议训练';
  }

  return draft;
}

function createGeneratedPlanItem(plan: ParsedPlanPayload, profile: UserProfile, fallbackDate: string): AiGeneratedPlanItem {
  let draft: ExerciseDraft = buildDraftFromPayload(plan);
  let summaryText: string = sanitizeString(plan.summary);

  return {
    id: `${Date.now()}-${Math.round(Math.random() * 1000)}`,
    date: normalizeDateText(sanitizeString(plan.date), fallbackDate),
    title: sanitizeString(plan.title, getWorkoutTitle(draft)),
    summary: summaryText.trim().length > 0 ? summaryText : buildWorkoutPlanSummary(profile, draft),
    notes: sanitizeString(plan.notes),
    draftText: serializeExerciseDraft(draft),
    accentColor: getWorkoutPlanAccentColor(draft),
    imported: false
  };
}

function createGeneratedFoodPlanItem(plan: ParsedFoodPlanPayload, fallbackDate: string): AiGeneratedFoodPlanItem {
  let mealType: string = normalizeMealType(sanitizeString(plan.mealType, 'breakfast'));
  let calories: number = sanitizeNumber(plan.calories, 0);

  return {
    id: `${Date.now()}-${Math.round(Math.random() * 1000)}`,
    date: normalizeDateText(sanitizeString(plan.date), fallbackDate),
    mealType: mealType,
    name: sanitizeString(plan.name, `${getMealLabel(mealType)}推荐`),
    description: sanitizeString(plan.description, 'AI 为你生成的一条饮食建议。'),
    calories: calories > 0 ? calories : 300,
    serving: sanitizeString(plan.serving, '1 份'),
    notes: sanitizeString(plan.notes),
    image: sanitizeString(plan.image),
    accentColor: sanitizeString(plan.accentColor, getMealAccentColor(mealType)),
    imported: false
  };
}

export function parseAssistantPayload(rawAssistantText: string, profile: UserProfile,
  reasoningContent: string = ''): AiAssistantResponse {
  let candidates = collectJsonObjectCandidates(rawAssistantText);
  for (let candidateIndex = 0; candidateIndex < candidates.length; candidateIndex++) {
    try {
      let parsedPayload = JSON.parse(candidates[candidateIndex]) as ParsedAssistantPayload;
      if (!isStructuredAssistantPayload(parsedPayload)) {
        continue;
      }
      let replyText: string = sanitizeString(parsedPayload.reply, rawAssistantText).trim();
      let plans: AiGeneratedPlanItem[] = [];
      let foodPlans: AiGeneratedFoodPlanItem[] = [];
      let parsedPlans = parsedPayload.plans;
      let parsedFoodPlans = parsedPayload.foodPlans;

      if (Array.isArray(parsedPlans)) {
        for (let index = 0; index < parsedPlans.length; index++) {
          let fallbackDate = formatDate(new Date(Date.now() + index * 24 * 60 * 60 * 1000));
          plans.push(createGeneratedPlanItem(parsedPlans[index], profile, fallbackDate));
        }
      }

      if (Array.isArray(parsedFoodPlans)) {
        for (let index = 0; index < parsedFoodPlans.length; index++) {
          let fallbackDate = formatDate(new Date(Date.now() + index * 24 * 60 * 60 * 1000));
          foodPlans.push(createGeneratedFoodPlanItem(parsedFoodPlans[index], fallbackDate));
        }
      }

      return {
        reply: replyText.length > 0 ? replyText : 'AI 已返回结果，但没有生成可展示的文本。',
        reasoningContent: reasoningContent.trim(),
        plans: plans,
        foodPlans: foodPlans,
        rawText: rawAssistantText,
        parseSucceeded: true
      };
    } catch (error) {
    }
  }

  return {
    reply: buildStructuredPayloadFallbackReply(rawAssistantText),
    reasoningContent: reasoningContent.trim(),
    plans: [],
    foodPlans: [],
    rawText: rawAssistantText,
    parseSucceeded: false
  };
}

export async function requestAiAssistant(config: AiAssistantConfig, context: AiAssistantRequestContext,
  options?: AiAssistantRequestOptions): Promise<AiAssistantResponse> {
  if (config.apiEndpoint.trim().length === 0) {
    throw new Error('请先填写 AI 接口地址。');
  }
  if (config.apiKey.trim().length === 0) {
    throw new Error('请先填写 AI API Key。');
  }
  if (config.model.trim().length === 0) {
    throw new Error('请先填写 AI 模型名称。');
  }

  let httpRequest = http.createHttp();
  let startedAt: number = Date.now();
  let responseStatusCode: number = -1;
  let requestCancelled: boolean = false;

  if (options && options.onRequestCreated) {
    options.onRequestCreated(() => {
      requestCancelled = true;
      try {
        httpRequest.destroy();
      } catch (error) {
      }
    });
  }

  try {
    let requestMessages: ChatCompletionMessage[] = [];
    requestMessages.push({
      role: 'system',
      content: buildSystemPrompt()
    });
    let historyMessages: ChatCompletionMessage[] = buildHistoryMessages(context.historyMessages);
    for (let index = 0; index < historyMessages.length; index++) {
      requestMessages.push(historyMessages[index]);
    }
    requestMessages.push({
      role: 'user',
      content: buildUserPrompt(context)
    });

    let enableThinking: boolean = options && options.enableThinking !== undefined ?
      options.enableThinking : shouldEnableAiThinking(context.task);
    let thinkingBudget: number = options && options.thinkingBudget !== undefined ?
      options.thinkingBudget : getAiThinkingBudget(context.task);
    let maxTokens: number = options && options.maxTokens !== undefined ?
      options.maxTokens : getAiMaxTokens(context.task);
    let requestBody: ChatCompletionRequestBody = {
      model: config.model.trim(),
      temperature: isWorkoutGenerationTask(context.task) || isFoodGenerationTask(context.task) ? 0.7 : 0.5,
      max_tokens: maxTokens,
      messages: requestMessages,
      enable_thinking: enableThinking
    };
    if (enableThinking && thinkingBudget > 0) {
      requestBody.thinking_budget = thinkingBudget;
    }
    hilog.info(AI_LOG_DOMAIN, AI_LOG_TAG,
      '发起 AI 助手请求，请求链接=%{public}s，模型=%{public}s，任务=%{public}s，鉴权=%{public}s',
      config.apiEndpoint.trim(),
      config.model.trim(),
      context.task,
      maskSensitiveText(config.apiKey));
    hilog.info(AI_LOG_DOMAIN, AI_LOG_TAG,
      'AI 请求参数：historyCount=%{public}d，messageCount=%{public}d，maxTokens=%{public}d，thinkingBudget=%{public}d',
      historyMessages.length,
      requestMessages.length,
      requestBody.max_tokens,
      requestBody.thinking_budget ? requestBody.thinking_budget : 0);

    let response = await httpRequest.request(config.apiEndpoint.trim(), {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${config.apiKey.trim()}`
      },
      extraData: JSON.stringify(requestBody),
      connectTimeout: 15000,
      readTimeout: options && options.readTimeout !== undefined ? options.readTimeout : getAiReadTimeout(context.task),
      expectDataType: http.HttpDataType.STRING
    });

    responseStatusCode = response.responseCode;
    let responseText: string = getHttpResponseText(response.result);
    hilog.info(AI_LOG_DOMAIN, AI_LOG_TAG, '收到 AI 助手响应，状态码=%{public}d，响应长度=%{public}d，响应预览=%{public}s',
      response.responseCode, responseText.length, buildLogPreview(responseText));
    hilog.info(AI_LOG_DOMAIN, AI_LOG_TAG,'响应文本：%{public}s',responseText)
    hilog.info(AI_LOG_DOMAIN, AI_LOG_TAG, 'AI 原始响应体=%{public}s', responseText);
    if (response.responseCode >= 400) {
      throw new Error(resolveAiResponseErrorMessage(response.responseCode, responseText));
    }

    let parsedResponse = JSON.parse(responseText) as ChatCompletionResponse;
    if (parsedResponse.error && parsedResponse.error.message) {
      throw new Error(parsedResponse.error.message);
    }

    if (!parsedResponse.choices || parsedResponse.choices.length === 0 || !parsedResponse.choices[0].message) {
      throw new Error('AI 接口没有返回有效内容。');
    }

    let assistantContent: string = sanitizeAssistantContent(sanitizeString(parsedResponse.choices[0].message.content));
    let reasoningContent: string = sanitizeString(parsedResponse.choices[0].message.reasoning_content).trim();
    hilog.info(AI_LOG_DOMAIN, AI_LOG_TAG,
      'AI 响应解析完成：assistantLength=%{public}d，reasoningLength=%{public}d',
      assistantContent.length,
      reasoningContent.length);
    hilog.info(AI_LOG_DOMAIN, AI_LOG_TAG, 'AI 解析正文=%{public}s', assistantContent);
    hilog.info(AI_LOG_DOMAIN, AI_LOG_TAG, 'AI 解析推理=%{public}s', reasoningContent);
    if (assistantContent.length === 0 && reasoningContent.length === 0) {
      throw new Error('AI 接口没有返回有效内容。');
    }
    if (assistantContent.length === 0) {
      assistantContent = '模型已完成推理，但没有返回最终回答。请重试。';
    }
    return parseAssistantPayload(assistantContent, context.profile, reasoningContent);
  } catch (error) {
    if (requestCancelled) {
      throw new Error('请求已中断。');
    }
    let errorMessage = resolveErrorText(error as Object, 'AI 请求失败，请检查网络与配置。');
    hilog.error(AI_LOG_DOMAIN, AI_LOG_TAG, 'AI 助手请求异常，错误信息=%{public}s', errorMessage);
    throw new Error(errorMessage);
  } finally {
    hilog.info(AI_LOG_DOMAIN, AI_LOG_TAG, 'AI 助手请求结束，状态码=%{public}d，耗时=%{public}dms',
      responseStatusCode, Date.now() - startedAt);
    httpRequest.destroy();
  }
}
