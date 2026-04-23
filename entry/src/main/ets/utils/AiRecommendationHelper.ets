import http from '@ohos.net.http';
import { AiAssistantConfig } from '../models/AiAssistant';
import {
  AiRecommendationItem,
  AiRecommendationResponse,
  RecommendationExerciseCandidate,
  RecommendationFoodCandidate
} from '../models/AiRecommendation';
import { UserProfile } from '../models/UserProfile';
import { WeightRecord } from '../models/WeightRecord';
import { WorkoutRecord } from '../models/WorkoutRecord';

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

interface ParsedRecommendationPayload {
  reply?: string;
  foodRankings?: AiRecommendationItem[];
  exerciseRankings?: AiRecommendationItem[];
}

export interface AiRecommendationRequestContext {
  profile: UserProfile;
  weightRecords: WeightRecord[];
  workoutRecords: WorkoutRecord[];
  dailyFoodCalorieTarget: number;
  foodCandidates: RecommendationFoodCandidate[];
  exerciseCandidates: RecommendationExerciseCandidate[];
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

function getHttpResponseText(result: string | Object | ArrayBuffer): string {
  if (typeof result === 'string') {
    return result;
  }
  return JSON.stringify(result);
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

function buildWeightDataText(weightRecords: WeightRecord[]): string {
  if (weightRecords.length === 0) {
    return '[]';
  }
  let copiedRecords = weightRecords.slice();
  copiedRecords.sort((left: WeightRecord, right: WeightRecord) => left.date < right.date ? 1 : -1);
  let items: string[] = [];
  for (let index = 0; index < copiedRecords.length && index < 10; index++) {
    items.push(JSON.stringify({
      date: copiedRecords[index].date,
      weightKg: copiedRecords[index].weight
    }));
  }
  return `[${items.join(',')}]`;
}

function buildWorkoutDataText(workoutRecords: WorkoutRecord[]): string {
  if (workoutRecords.length === 0) {
    return '[]';
  }
  let copiedRecords = workoutRecords.slice();
  copiedRecords.sort((left: WorkoutRecord, right: WorkoutRecord) => left.date < right.date ? 1 : -1);
  let items: string[] = [];
  for (let index = 0; index < copiedRecords.length && index < 8; index++) {
    items.push(JSON.stringify({
      date: copiedRecords[index].date,
      name: copiedRecords[index].name,
      calories: copiedRecords[index].calories,
      durationSeconds: copiedRecords[index].durationSeconds
    }));
  }
  return `[${items.join(',')}]`;
}

function buildFoodCandidateText(candidates: RecommendationFoodCandidate[]): string {
  let lines: string[] = [];
  for (let index = 0; index < candidates.length; index++) {
    lines.push(JSON.stringify(candidates[index]));
  }
  return `[${lines.join(',')}]`;
}

function buildExerciseCandidateText(candidates: RecommendationExerciseCandidate[]): string {
  let lines: string[] = [];
  for (let index = 0; index < candidates.length; index++) {
    lines.push(JSON.stringify(candidates[index]));
  }
  return `[${lines.join(',')}]`;
}

function buildSystemPrompt(): string {
  return [
    '你是一个健身饮食应用里的排序助手。',
    '你只能基于已提供的候选项做排序，不允许新增候选项，不允许返回未知 id。',
    '请综合用户资料、近期体重变化、近期训练记录和热量目标，给出食物与运动候选的推荐排序。',
    '输出必须是 JSON 对象，不要输出 Markdown 代码块。',
    'JSON 结构必须是：{"reply":"一句中文总结","foodRankings":[{"id":"food-id","score":92,"reason":"一句简短原因"}],"exerciseRankings":[{"id":"exercise-id","score":88,"reason":"一句简短原因"}]}。',
    'score 范围是 0 到 100，列表按分数从高到低排序。',
    '如果候选列表为空，对应数组返回空数组。'
  ].join('\n');
}

function buildUserPrompt(context: AiRecommendationRequestContext): string {
  return [
    `用户资料：${JSON.stringify(context.profile)}`,
    `近期体重：${buildWeightDataText(context.weightRecords)}`,
    `近期训练记录：${buildWorkoutDataText(context.workoutRecords)}`,
    `当前饮食热量目标：${context.dailyFoodCalorieTarget} kcal`,
    `待排序食物候选：${buildFoodCandidateText(context.foodCandidates)}`,
    `待排序运动候选：${buildExerciseCandidateText(context.exerciseCandidates)}`,
    '请用中文简短说明推荐方向，并返回可直接用于前端排序的结果。'
  ].join('\n');
}

function filterRankingItems(items: AiRecommendationItem[] | undefined, supportedIds: string[]): AiRecommendationItem[] {
  if (!Array.isArray(items)) {
    return [];
  }
  let result: AiRecommendationItem[] = [];
  let knownIds: string[] = [];
  for (let index = 0; index < items.length; index++) {
    let itemId = sanitizeString(items[index].id);
    if (supportedIds.indexOf(itemId) < 0 || knownIds.indexOf(itemId) >= 0) {
      continue;
    }
    result.push({
      id: itemId,
      score: Math.max(0, Math.min(100, sanitizeNumber(items[index].score))),
      reason: sanitizeString(items[index].reason)
    });
    knownIds.push(itemId);
  }
  result.sort((left: AiRecommendationItem, right: AiRecommendationItem) => right.score - left.score);
  return result;
}

function parseRecommendationPayload(rawAssistantText: string, foodIds: string[], exerciseIds: string[]): AiRecommendationResponse {
  let jsonText = extractJsonObjectText(rawAssistantText);
  try {
    let parsedValue = JSON.parse(jsonText) as ParsedRecommendationPayload;
    return {
      reply: sanitizeString(parsedValue.reply, rawAssistantText).trim(),
      foodRankings: filterRankingItems(parsedValue.foodRankings, foodIds),
      exerciseRankings: filterRankingItems(parsedValue.exerciseRankings, exerciseIds)
    };
  } catch (error) {
    return {
      reply: rawAssistantText.trim().length > 0 ? rawAssistantText.trim() : 'AI 没有返回可解析的推荐结果。',
      foodRankings: [],
      exerciseRankings: []
    };
  }
}

export async function requestAiRecommendations(config: AiAssistantConfig,
  context: AiRecommendationRequestContext): Promise<AiRecommendationResponse> {
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
    let requestBody: ChatCompletionRequestBody = {
      model: config.model.trim(),
      temperature: 0.4,
      max_tokens: 1400,
      messages: [
        { role: 'system', content: buildSystemPrompt() },
        { role: 'user', content: buildUserPrompt(context) }
      ]
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
    let responseText = getHttpResponseText(response.result);
    if (response.responseCode >= 400) {
      throw new Error(`AI 接口调用失败（${response.responseCode}）：${responseText}`);
    }
    let parsedResponse = JSON.parse(responseText) as ChatCompletionResponse;
    if (parsedResponse.error && parsedResponse.error.message) {
      throw new Error(parsedResponse.error.message);
    }
    if (!parsedResponse.choices || parsedResponse.choices.length === 0 || !parsedResponse.choices[0].message) {
      throw new Error('AI 接口没有返回有效内容。');
    }
    return parseRecommendationPayload(
      parsedResponse.choices[0].message.content,
      context.foodCandidates.map((item: RecommendationFoodCandidate) => item.id),
      context.exerciseCandidates.map((item: RecommendationExerciseCandidate) => item.id)
    );
  } catch (error) {
    let errorMessage = `${error}`;
    if (errorMessage.trim().length === 0 || errorMessage === '[object Object]') {
      errorMessage = 'AI 推荐请求失败，请检查网络与配置。';
    }
    throw new Error(errorMessage);
  } finally {
    httpRequest.destroy();
  }
}
