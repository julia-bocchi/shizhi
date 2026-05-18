export const AI_ROLE_USER: string = 'user';
export const AI_ROLE_ASSISTANT: string = 'assistant';
export const AI_MESSAGE_STATUS_DONE: string = 'done';
export const AI_MESSAGE_STATUS_THINKING: string = 'thinking';
export const AI_MESSAGE_STATUS_ERROR: string = 'error';
export const AI_MESSAGE_STATUS_CANCELLED: string = 'cancelled';

export const AI_TASK_CHAT: string = 'chat';
export const AI_TASK_ANALYZE_WEIGHT: string = 'analyze_weight';
export const AI_TASK_GENERATE_PLAN: string = 'generate_plan';
export const AI_TASK_GENERATE_RECIPE: string = 'generate_recipe';
export const AI_TASK_GENERATE_FULL_PLAN: string = 'generate_full_plan';

const DEFAULT_AI_API_ENDPOINT: string = 'https://api.siliconflow.cn/v1/chat/completions';
const DEFAULT_AI_MODEL: string = 'deepseek-ai/DeepSeek-V3.2';
const DEFAULT_API_KEY: string = '';

export interface AiAssistantConfig {
  apiEndpoint: string;
  apiKey: string;
  model: string;
}

export interface AiChatMessage {
  id: string;
  role: string;
  content: string;
  thinkingContent: string;
  status: string;
  createdAt: number;
  generatedPlans: AiGeneratedPlanItem[];
  generatedFoodPlans: AiGeneratedFoodPlanItem[];
}

export interface AiConversationRecord {
  id: string;
  title: string;
  createdAt: number;
  updatedAt: number;
  messages: AiChatMessage[];
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
  reasoningContent: string;
  plans: AiGeneratedPlanItem[];
  foodPlans: AiGeneratedFoodPlanItem[];
  rawText: string;
  parseSucceeded: boolean;
}

function createUniqueId(): string {
  return `${Date.now()}-${Math.round(Math.random() * 1000)}`;
}

function cloneAiGeneratedPlanItem(plan: AiGeneratedPlanItem): AiGeneratedPlanItem {
  return {
    id: plan.id,
    date: plan.date,
    title: plan.title,
    summary: plan.summary,
    notes: plan.notes,
    draftText: plan.draftText,
    accentColor: plan.accentColor,
    imported: plan.imported
  };
}

function cloneAiGeneratedFoodPlanItem(plan: AiGeneratedFoodPlanItem): AiGeneratedFoodPlanItem {
  return {
    id: plan.id,
    date: plan.date,
    mealType: plan.mealType,
    name: plan.name,
    description: plan.description,
    calories: plan.calories,
    serving: plan.serving,
    notes: plan.notes,
    image: plan.image,
    accentColor: plan.accentColor,
    imported: plan.imported
  };
}

function cloneAiGeneratedPlans(plans: AiGeneratedPlanItem[]): AiGeneratedPlanItem[] {
  let result: AiGeneratedPlanItem[] = [];
  for (let index = 0; index < plans.length; index++) {
    result.push(cloneAiGeneratedPlanItem(plans[index]));
  }
  return result;
}

function cloneAiGeneratedFoodPlans(plans: AiGeneratedFoodPlanItem[]): AiGeneratedFoodPlanItem[] {
  let result: AiGeneratedFoodPlanItem[] = [];
  for (let index = 0; index < plans.length; index++) {
    result.push(cloneAiGeneratedFoodPlanItem(plans[index]));
  }
  return result;
}

export function createAiChatMessage(role: string, content: string, thinkingContent: string = '',
  status: string = AI_MESSAGE_STATUS_DONE, generatedPlans: AiGeneratedPlanItem[] = [],
  generatedFoodPlans: AiGeneratedFoodPlanItem[] = []): AiChatMessage {
  return {
    id: createUniqueId(),
    role: role,
    content: content,
    thinkingContent: thinkingContent,
    status: status,
    createdAt: Date.now(),
    generatedPlans: cloneAiGeneratedPlans(generatedPlans),
    generatedFoodPlans: cloneAiGeneratedFoodPlans(generatedFoodPlans)
  };
}

export function cloneAiChatMessage(message: AiChatMessage): AiChatMessage {
  return {
    id: message.id,
    role: message.role,
    content: message.content,
    thinkingContent: message.thinkingContent,
    status: message.status,
    createdAt: message.createdAt,
    generatedPlans: cloneAiGeneratedPlans(message.generatedPlans),
    generatedFoodPlans: cloneAiGeneratedFoodPlans(message.generatedFoodPlans)
  };
}

export function createAiConversationRecord(messages: AiChatMessage[] = []): AiConversationRecord {
  let now: number = Date.now();
  return {
    id: createUniqueId(),
    title: '新对话',
    createdAt: now,
    updatedAt: now,
    messages: messages
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

export function serializeAiConversationHistory(records: AiConversationRecord[]): string {
  return JSON.stringify(records);
}

export function deserializeAiConversationHistory(text: string): AiConversationRecord[] {
  if (text.trim().length === 0) {
    return [];
  }

  try {
    let parsedRecords = JSON.parse(text) as AiConversationRecord[];
    if (!Array.isArray(parsedRecords)) {
      return [];
    }

    let result: AiConversationRecord[] = [];
    for (let index = 0; index < parsedRecords.length; index++) {
      let currentRecord = parsedRecords[index];
      if (!currentRecord || !Array.isArray(currentRecord.messages)) {
        continue;
      }

      let messages: AiChatMessage[] = [];
      for (let messageIndex = 0; messageIndex < currentRecord.messages.length; messageIndex++) {
        let currentMessage = currentRecord.messages[messageIndex];
        if (!currentMessage || `${currentMessage.role}`.trim().length === 0) {
          continue;
        }
        messages.push({
          id: `${currentMessage.id || createUniqueId()}`,
          role: `${currentMessage.role}`,
          content: `${currentMessage.content || ''}`,
          thinkingContent: `${currentMessage.thinkingContent || ''}`,
          status: `${currentMessage.status || AI_MESSAGE_STATUS_DONE}`,
          createdAt: Number(currentMessage.createdAt) > 0 ? Number(currentMessage.createdAt) : Date.now(),
          generatedPlans: Array.isArray(currentMessage.generatedPlans)
            ? cloneAiGeneratedPlans(currentMessage.generatedPlans as AiGeneratedPlanItem[])
            : [],
          generatedFoodPlans: Array.isArray(currentMessage.generatedFoodPlans)
            ? cloneAiGeneratedFoodPlans(currentMessage.generatedFoodPlans as AiGeneratedFoodPlanItem[])
            : []
        });
      }

      let now: number = Date.now();
      result.push({
        id: `${currentRecord.id || createUniqueId()}`,
        title: `${currentRecord.title || '新对话'}`,
        createdAt: Number(currentRecord.createdAt) > 0 ? Number(currentRecord.createdAt) : now,
        updatedAt: Number(currentRecord.updatedAt) > 0 ? Number(currentRecord.updatedAt) : now,
        messages: messages
      });
    }
    return result;
  } catch (error) {
    return [];
  }
}
