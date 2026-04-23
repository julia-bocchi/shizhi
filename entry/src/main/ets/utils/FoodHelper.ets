import { FoodOption, FOOD_MEAL_OPTIONS } from '../models/FoodOption';
import { FoodPlanItem } from '../models/FoodPlan';

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
