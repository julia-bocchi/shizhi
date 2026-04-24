import { FoodOption, FOOD_MEAL_OPTIONS } from '../models/FoodOption';
import { FoodPlanItem } from '../models/FoodPlan';
import { buildStableIdentitySuffix, isSameUniqueName } from './IdentityHelper';

function sanitizeString(value: string | number | boolean | undefined | null, fallbackValue: string = ''): string {
  if (value === undefined || value === null) {
    return fallbackValue;
  }
  return `${value}`;
}

function sanitizeNumber(value: number | string | undefined | null, fallbackValue: number = 0): number {
  let parsedValue: number = Number(value);
  if (isNaN(parsedValue)) {
    return fallbackValue;
  }
  return parsedValue;
}

export function serializeCustomFoodOptions(options: FoodOption[]): string {
  return JSON.stringify(options);
}

export function deserializeCustomFoodOptions(savedText: string): FoodOption[] {
  if (savedText.trim().length === 0) {
    return [];
  }

  try {
    let parsedOptions = JSON.parse(savedText) as FoodOption[];
    if (!Array.isArray(parsedOptions)) {
      return [];
    }

    let nextOptions: FoodOption[] = [];
    for (let index = 0; index < parsedOptions.length; index++) {
      let currentOption = parsedOptions[index];
      nextOptions.push({
        id: sanitizeString(currentOption.id),
        name: sanitizeString(currentOption.name),
        description: sanitizeString(currentOption.description),
        calories: sanitizeNumber(currentOption.calories),
        serving: sanitizeString(currentOption.serving),
        mealSuggestion: sanitizeString(currentOption.mealSuggestion),
        image: sanitizeString(currentOption.image),
        accentColor: sanitizeString(currentOption.accentColor, '#D86C3D')
      });
    }
    return nextOptions;
  } catch (error) {
    return [];
  }
}

export interface UpsertCustomFoodOptionResult {
  options: FoodOption[];
  option: FoodOption;
  hasUpdated: boolean;
}

export function buildCustomFoodIdentityKey(name: string): string {
  return buildStableIdentitySuffix(name, 'custom-food');
}

export function createLocalCustomFoodOptionId(name: string): string {
  return `local-food-option-${buildCustomFoodIdentityKey(name)}`;
}

export function buildDefaultCustomFoodImage(mealType: string): string {
  return `builtin:meal:${sanitizeString(mealType, 'breakfast').trim() || 'breakfast'}`;
}

export function upsertCustomFoodOptionByIdentity(currentOptions: FoodOption[], nextOption: FoodOption,
  preferredId: string = ''): UpsertCustomFoodOptionResult {
  let resolvedId: string = sanitizeString(preferredId).trim();
  let hasUpdated: boolean = false;
  for (let index = 0; index < currentOptions.length; index++) {
    let currentOption = currentOptions[index];
    if ((resolvedId.length > 0 && currentOption.id === resolvedId) || currentOption.id === nextOption.id ||
      isSameUniqueName(currentOption.name, nextOption.name)) {
      resolvedId = currentOption.id;
      hasUpdated = true;
      break;
    }
  }
  if (resolvedId.length === 0) {
    let nextOptionId: string = sanitizeString(nextOption.id).trim();
    resolvedId = nextOptionId.length > 0 ? nextOptionId : createLocalCustomFoodOptionId(nextOption.name);
  }

  let resolvedOption: FoodOption = {
    id: resolvedId,
    name: sanitizeString(nextOption.name).trim(),
    description: sanitizeString(nextOption.description),
    calories: sanitizeNumber(nextOption.calories),
    serving: sanitizeString(nextOption.serving),
    mealSuggestion: sanitizeString(nextOption.mealSuggestion),
    image: sanitizeString(nextOption.image),
    accentColor: sanitizeString(nextOption.accentColor, '#D86C3D')
  };

  let nextOptions: FoodOption[] = [];
  let inserted: boolean = false;
  for (let index = 0; index < currentOptions.length; index++) {
    let currentOption = currentOptions[index];
    if (currentOption.id === resolvedOption.id || isSameUniqueName(currentOption.name, resolvedOption.name)) {
      if (!inserted) {
        nextOptions.push(resolvedOption);
        inserted = true;
      }
      continue;
    }
    nextOptions.push(currentOption);
  }
  if (!inserted) {
    nextOptions.unshift(resolvedOption);
  }

  return {
    options: nextOptions,
    option: resolvedOption,
    hasUpdated: hasUpdated
  };
}

export function serializeFoodPlans(plans: FoodPlanItem[]): string {
  return JSON.stringify(plans);
}

export function deserializeFoodPlans(savedText: string): FoodPlanItem[] {
  if (savedText.trim().length === 0) {
    return [];
  }

  try {
    let parsedPlans = JSON.parse(savedText) as FoodPlanItem[];
    if (!Array.isArray(parsedPlans)) {
      return [];
    }

    let nextPlans: FoodPlanItem[] = [];
    for (let index = 0; index < parsedPlans.length; index++) {
      let currentPlan = parsedPlans[index];
      nextPlans.push({
        id: sanitizeString(currentPlan.id),
        date: sanitizeString(currentPlan.date),
        foodId: sanitizeString(currentPlan.foodId),
        name: sanitizeString(currentPlan.name),
        description: sanitizeString(currentPlan.description),
        calories: sanitizeNumber(currentPlan.calories),
        serving: sanitizeString(currentPlan.serving),
        mealType: sanitizeString(currentPlan.mealType, 'breakfast'),
        image: sanitizeString(currentPlan.image),
        notes: sanitizeString(currentPlan.notes),
        accentColor: sanitizeString(currentPlan.accentColor, '#D86C3D')
      });
    }
    return nextPlans;
  } catch (error) {
    return [];
  }
}

export function createFoodPlanItem(date: string, option: FoodOption, mealType: string, notes: string): FoodPlanItem {
  return {
    id: `local-food-plan-${Date.now()}-${Math.round(Math.random() * 1000)}`,
    date: sanitizeString(date),
    foodId: sanitizeString(option.id),
    name: sanitizeString(option.name),
    description: sanitizeString(option.description),
    calories: sanitizeNumber(option.calories),
    serving: sanitizeString(option.serving),
    mealType: sanitizeString(mealType, 'breakfast'),
    image: sanitizeString(option.image),
    notes: sanitizeString(notes).trim(),
    accentColor: sanitizeString(option.accentColor, '#D86C3D')
  };
}

export function getFoodMealLabel(mealType: string): string {
  for (let index = 0; index < FOOD_MEAL_OPTIONS.length; index++) {
    if (FOOD_MEAL_OPTIONS[index].id === mealType) {
      return FOOD_MEAL_OPTIONS[index].label;
    }
  }
  return '未分类';
}

export function getFoodMealSortValue(mealType: string): number {
  if (mealType === 'breakfast') {
    return 0;
  }
  if (mealType === 'lunch') {
    return 1;
  }
  if (mealType === 'dinner') {
    return 2;
  }
  if (mealType === 'snack') {
    return 3;
  }
  return 4;
}
