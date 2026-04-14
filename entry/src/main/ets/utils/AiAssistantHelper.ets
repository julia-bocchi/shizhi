import http from '@ohos.net.http';
import {
  AI_ROLE_ASSISTANT,
  AI_ROLE_USER,
  AI_TASK_ANALYZE_WEIGHT,
  AI_TASK_GENERATE_PLAN,
  AiAssistantConfig,
  AiAssistantResponse,
  AiChatMessage,
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
import { UserProfile } from '../models/UserProfile';
import { WeightRecord } from '../models/WeightRecord';
import { WorkoutRecord } from '../models/WorkoutRecord';
import { getWorkoutTitle, serializeExerciseDraft } from './ExerciseHelper';
import { formatDate, getRecentWeightRecords } from './WeightRecordHelper';
import { buildWorkoutPlanSummary, getWorkoutPlanAccentColor } from './WorkoutPlanHelper';

interface ChatCompletionMessage {
  role: string;
  content: string;
}

interface ChatCompletionChoice {
  message?: ChatCompletionMessage;
}

interface ChatCompletionError {
  message?: string;
}

interface ChatCompletionResponse {
  choices?: ChatCompletionChoice[];
  error?: ChatCompletionError;
}

interface ChatCompletionRequestBody {
  model: string;
  temperature: number;
  max_tokens: number;
  messages: ChatCompletionMessage[];
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

interface ParsedAssistantPayload {
  reply?: string;
  plans?: ParsedPlanPayload[];
}

export interface AiAssistantRequestContext {
  task: string;
  userPrompt: string;
  profile: UserProfile;
  weightRecords: WeightRecord[];
  workoutRecords: WorkoutRecord[];
  existingPlanCount: number;
  savedWorkoutNames: string[];
  historyMessages: AiChatMessage[];
}

function sanitizeString(value: string | number | boolean | undefined | null, fallbackValue: string = ''): string {
  if (value === undefined || value === null) {
    return fallbackValue;
  }
  return `${value}`;
}

function getHttpResponseText(result: string | Object | ArrayBuffer): string {
  if (typeof result === 'string') {
    return result;
  }
  return JSON.stringify(result);
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

function buildSupportedExercisesText(): string {
  let lines: string[] = [];
  for (let index = 0; index < EXERCISE_OPTIONS.length; index++) {
    lines.push(`${EXERCISE_OPTIONS[index].id}: ${EXERCISE_OPTIONS[index].name}`);
  }
  return lines.join('；');
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
    '你是一名健身助手，服务于一个体重与训练计划 App。',
    '你的目标是结合最近体重变化、最近训练记录和用户提问，输出温和、可执行、不过度承诺的建议。',
    '不要给出医疗诊断，不要鼓励极端节食、过量训练或危险动作。',
    '如果用户要求训练计划，只能使用这些 exerciseId：' + buildSupportedExercisesText(),
    '如果上述预设都不合适，请使用 custom。',
    'customMode 只能是 duration、set_timer、distance_pace、distance_speed、count_rate。',
    'customIntensity 只能是 light、moderate、intense。',
    '请始终返回 JSON 对象，不要输出 Markdown 代码块。',
    'JSON 结构必须是：{"reply":"给用户展示的建议","plans":[{"date":"YYYY-MM-DD","title":"计划标题","summary":"一句摘要","notes":"备注","exerciseId":"running","customName":"","customMode":"duration","customIntensity":"moderate","durationMinutes":"30","distanceKm":"5","paceMinutes":"6","speedKmH":"18","count":"200","cadencePerMinute":"120","sets":"4","workSeconds":"40","restSeconds":"20"}]}。',
    '如果本次不需要生成计划，plans 返回空数组。'
  ].join('\n');
}

function buildUserPrompt(context: AiAssistantRequestContext): string {
  let todayText: string = formatDate(new Date());
  let taskInstruction: string = '请回答用户问题。';
  if (context.task === AI_TASK_ANALYZE_WEIGHT) {
    taskInstruction = '请重点分析最近体重变化，并给出 3 条以内可执行建议，plans 返回空数组。';
  } else if (context.task === AI_TASK_GENERATE_PLAN) {
    taskInstruction = '请给出简短解释，并额外生成 3 到 5 条可导入的训练计划。计划日期尽量从今天开始顺延，强度循序渐进。';
  }

  let savedWorkoutHint: string = context.savedWorkoutNames.length > 0
    ? context.savedWorkoutNames.join('、')
    : '无';

  return [
    `今天日期：${todayText}`,
    `当前任务：${context.task}`,
    `任务要求：${taskInstruction}`,
    `用户问题：${context.userPrompt}`,
    `用户资料：${JSON.stringify(context.profile)}`,
    `最近体重：${buildWeightDataText(context.weightRecords)}`,
    `最近训练记录：${buildWorkoutDataText(context.workoutRecords)}`,
    `训练页当前已有计划数量：${context.existingPlanCount}`,
    `已保存的自定义模板名称：${savedWorkoutHint}`,
    '请让 reply 用中文回答，语气简洁、友好、可执行。'
  ].join('\n');
}

function extractJsonObjectText(rawText: string): string {
  let trimmedText = rawText.trim();
  if (trimmedText.startsWith('```')) {
    trimmedText = trimmedText.replace(/^```[a-zA-Z]*\s*/, '').replace(/\s*```$/, '');
  }

  let startIndex = trimmedText.indexOf('{');
  let endIndex = trimmedText.lastIndexOf('}');
  if (startIndex >= 0 && endIndex > startIndex) {
    return trimmedText.substring(startIndex, endIndex + 1);
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

function parseAssistantPayload(rawAssistantText: string, profile: UserProfile): AiAssistantResponse {
  let jsonText: string = extractJsonObjectText(rawAssistantText);

  try {
    let parsedPayload = JSON.parse(jsonText) as ParsedAssistantPayload;
    let replyText: string = sanitizeString(parsedPayload.reply, rawAssistantText).trim();
    let plans: AiGeneratedPlanItem[] = [];
    let parsedPlans = parsedPayload.plans;

    if (Array.isArray(parsedPlans)) {
      for (let index = 0; index < parsedPlans.length; index++) {
        let fallbackDate = formatDate(new Date(Date.now() + index * 24 * 60 * 60 * 1000));
        plans.push(createGeneratedPlanItem(parsedPlans[index], profile, fallbackDate));
      }
    }

    return {
      reply: replyText.length > 0 ? replyText : 'AI 已返回结果，但没有生成可展示的文本。',
      plans: plans,
      rawText: rawAssistantText
    };
  } catch (error) {
    return {
      reply: rawAssistantText.trim().length > 0 ? rawAssistantText.trim() : 'AI 没有返回可解析内容，请稍后重试。',
      plans: [],
      rawText: rawAssistantText
    };
  }
}

export async function requestAiAssistant(config: AiAssistantConfig, context: AiAssistantRequestContext): Promise<AiAssistantResponse> {
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

    let requestBody: ChatCompletionRequestBody = {
      model: config.model.trim(),
      temperature: context.task === AI_TASK_GENERATE_PLAN ? 0.7 : 0.5,
      max_tokens: 1200,
      messages: requestMessages
    };

    let response = await httpRequest.request(config.apiEndpoint.trim(), {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${config.apiKey.trim()}`
      },
      extraData: JSON.stringify(requestBody),
      connectTimeout: 15000,
      readTimeout: 30000,
      expectDataType: http.HttpDataType.STRING
    });

    let responseText: string = getHttpResponseText(response.result);
    if (response.responseCode >= 400) {
      throw new Error(`AI 接口调用失败（${response.responseCode}）：${responseText}`);
    }

    let parsedResponse = JSON.parse(responseText) as ChatCompletionResponse;
    if (parsedResponse.error && parsedResponse.error.message) {
      throw new Error(parsedResponse.error.message);
    }

    if (!parsedResponse.choices || parsedResponse.choices.length === 0 ||
      !parsedResponse.choices[0].message || parsedResponse.choices[0].message.content.length === 0) {
      throw new Error('AI 接口没有返回有效内容。');
    }

    let assistantContent: string = parsedResponse.choices[0].message.content;
    return parseAssistantPayload(assistantContent, context.profile);
  } catch (error) {
    let errorMessage = `${error}`;
    if (errorMessage.trim().length === 0 || errorMessage === '[object Object]') {
      errorMessage = 'AI 请求失败，请检查网络与配置。';
    }
    throw new Error(errorMessage);
  } finally {
    httpRequest.destroy();
  }
}
