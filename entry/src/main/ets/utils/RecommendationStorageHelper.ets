import { AiRecommendationCache, AiRecommendationItem } from '../models/AiRecommendation';

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

export function createEmptyRecommendationCache(): AiRecommendationCache {
  return {
    updatedAt: '',
    reply: '',
    items: []
  };
}

export function serializeRecommendationCache(cache: AiRecommendationCache): string {
  return JSON.stringify(cache);
}

export function deserializeRecommendationCache(savedText: string): AiRecommendationCache {
  if (savedText.trim().length === 0) {
    return createEmptyRecommendationCache();
  }

  try {
    let parsedValue = JSON.parse(savedText) as AiRecommendationCache;
    let parsedItems = Array.isArray(parsedValue.items) ? parsedValue.items : [];
    let items: AiRecommendationItem[] = [];
    for (let index = 0; index < parsedItems.length; index++) {
      items.push({
        id: sanitizeString(parsedItems[index].id),
        score: sanitizeNumber(parsedItems[index].score),
        reason: sanitizeString(parsedItems[index].reason)
      });
    }
    return {
      updatedAt: sanitizeString(parsedValue.updatedAt),
      reply: sanitizeString(parsedValue.reply),
      items: items
    };
  } catch (error) {
    return createEmptyRecommendationCache();
  }
}

export function getRecommendationScore(cacheText: string, itemId: string): number {
  if (itemId.trim().length === 0) {
    return -1;
  }
  let cache = deserializeRecommendationCache(cacheText);
  for (let index = 0; index < cache.items.length; index++) {
    if (cache.items[index].id === itemId) {
      return cache.items[index].score;
    }
  }
  return -1;
}

export function getRecommendationRank(cacheText: string, itemId: string): number {
  if (itemId.trim().length === 0) {
    return -1;
  }
  let cache = deserializeRecommendationCache(cacheText);
  for (let index = 0; index < cache.items.length; index++) {
    if (cache.items[index].id === itemId) {
      return index;
    }
  }
  return -1;
}
