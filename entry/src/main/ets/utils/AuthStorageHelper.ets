import { AuthSession, createEmptyAuthSession } from '../models/AuthSession';
import { WorkoutPlanLocalMeta } from '../models/BackendApi';

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

export function serializeAuthSession(session: AuthSession): string {
  return JSON.stringify({
    userId: session.userId,
    username: session.username,
    token: session.token,
    loginAt: session.loginAt
  });
}

export function deserializeAuthSession(savedText: string): AuthSession {
  if (savedText.trim().length === 0) {
    return createEmptyAuthSession();
  }

  try {
    let parsedValue = JSON.parse(savedText) as AuthSession;
    return {
      userId: sanitizeString(parsedValue.userId),
      username: sanitizeString(parsedValue.username),
      token: sanitizeString(parsedValue.token),
      loginAt: sanitizeString(parsedValue.loginAt)
    };
  } catch (error) {
    return createEmptyAuthSession();
  }
}

export function serializeWorkoutPlanLocalMeta(metaItems: WorkoutPlanLocalMeta[]): string {
  return JSON.stringify(metaItems);
}

export function deserializeWorkoutPlanLocalMeta(savedText: string): WorkoutPlanLocalMeta[] {
  if (savedText.trim().length === 0) {
    return [];
  }

  try {
    let parsedItems = JSON.parse(savedText) as WorkoutPlanLocalMeta[];
    if (!Array.isArray(parsedItems)) {
      return [];
    }

    let nextItems: WorkoutPlanLocalMeta[] = [];
    for (let index = 0; index < parsedItems.length; index++) {
      nextItems.push({
        planId: sanitizeString(parsedItems[index].planId),
        goalType: sanitizeString(parsedItems[index].goalType, 'duration'),
        goalValue: sanitizeNumber(parsedItems[index].goalValue, 30),
        manuallyCompleted: parsedItems[index].manuallyCompleted === true,
        collapsed: parsedItems[index].collapsed === true
      });
    }
    return nextItems;
  } catch (error) {
    return [];
  }
}
