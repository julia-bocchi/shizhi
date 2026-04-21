export const AI_ROLE_USER: string = 'user';
export const AI_ROLE_ASSISTANT: string = 'assistant';

export const AI_TASK_CHAT: string = 'chat';
export const AI_TASK_ANALYZE_WEIGHT: string = 'analyze_weight';
export const AI_TASK_GENERATE_PLAN: string = 'generate_plan';
export const AI_TASK_GENERATE_RECIPE: string = 'generate_recipe';
export const AI_TASK_GENERATE_FULL_PLAN: string = 'generate_full_plan';

const DEFAULT_AI_API_ENDPOINT: string = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';
const DEFAULT_AI_MODEL: string = 'glm-5.1';
const DEFAULT_API_KEY: string = 'b844e1495be84545a7f69bff272728ea.VGUBzWlLMX9B8Gsh';

export interface AiAssistantConfig {
  apiEndpoint: string;
  apiKey: string;
  model: string;
}

export interface AiChatMessage {
  id: string;
  role: string;
  content: string;
}

export interface AiGeneratedPlanItem {
  id: string;
  date: string;
  title: string;
  summary: string;
  notes: string;
  draftText: string;
  accentColor: string;
  imported: boolean;
}

export interface AiGeneratedFoodPlanItem {
  id: string;
  date: string;
  mealType: string;
  name: string;
  description: string;
  calories: number;
  serving: string;
  notes: string;
  image: string;
  accentColor: string;
  imported: boolean;
}

export interface AiAssistantResponse {
  reply: string;
  plans: AiGeneratedPlanItem[];
  foodPlans: AiGeneratedFoodPlanItem[];
  rawText: string;
}

function createUniqueId(): string {
  return `${Date.now()}-${Math.round(Math.random() * 1000)}`;
}

export function createAiChatMessage(role: string, content: string): AiChatMessage {
  return {
    id: createUniqueId(),
    role: role,
    content: content
  };
}

export function getDefaultAiApiEndpoint(): string {
  return DEFAULT_AI_API_ENDPOINT;
}

export function getDefaultAiModel(): string {
  return DEFAULT_AI_MODEL;
}

export function getDefaultAiApiKey(): string {
  return DEFAULT_API_KEY;
}
