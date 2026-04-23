import { FoodOption } from '../models/FoodOption';
import { FoodPlanItem } from '../models/FoodPlan';

export interface FoodVisualDescriptor {
  token: string;
  primaryText: string;
  secondaryText: string;
  topColor: string;
  bottomColor: string;
  accentColor: string;
}

const BUILTIN_PREFIX: string = 'builtin:food:';
const BUILTIN_MEAL_PREFIX: string = 'builtin:meal:';

function normalizeMealTypeFromSuggestion(mealSuggestion: string): string {
  if (mealSuggestion === '早餐') {
    return 'breakfast';
  }
  if (mealSuggestion === '午餐') {
    return 'lunch';
  }
  if (mealSuggestion === '晚餐') {
    return 'dinner';
  }
  if (mealSuggestion === '加餐') {
    return 'snack';
  }
  return 'breakfast';
}

export function isBuiltinFoodImage(image: string): boolean {
  return image.indexOf(BUILTIN_PREFIX) === 0 || image.indexOf(BUILTIN_MEAL_PREFIX) === 0;
}

export function getBuiltinFoodImageById(foodId: string, mealType: string = 'breakfast'): string {
  if (foodId === 'preset-oatmeal') {
    return `${BUILTIN_PREFIX}oatmeal`;
  }
  if (foodId === 'preset-chicken-salad') {
    return `${BUILTIN_PREFIX}chicken-salad`;
  }
  if (foodId === 'preset-salmon') {
    return `${BUILTIN_PREFIX}salmon`;
  }
  if (foodId === 'preset-yogurt') {
    return `${BUILTIN_PREFIX}yogurt`;
  }
  if (foodId === 'preset-rice-beef') {
    return `${BUILTIN_PREFIX}rice-beef`;
  }
  if (foodId === 'preset-egg-toast') {
    return `${BUILTIN_PREFIX}egg-toast`;
  }
  if (foodId === 'create-custom-card') {
    return `${BUILTIN_PREFIX}custom-card`;
  }
  return `${BUILTIN_MEAL_PREFIX}${mealType}`;
}

export function resolveFoodImage(image: string, foodId: string, mealType: string = 'breakfast'): string {
  if (image.trim().length > 0) {
    return image;
  }
  return getBuiltinFoodImageById(foodId, mealType);
}

export function resolveFoodOptionImage(option: FoodOption): string {
  return resolveFoodImage(option.image, option.id, normalizeMealTypeFromSuggestion(option.mealSuggestion));
}

export function resolveFoodPlanImage(plan: FoodPlanItem): string {
  return resolveFoodImage(plan.image, plan.foodId, plan.mealType);
}

export function getFoodVisualDescriptor(image: string, name: string): FoodVisualDescriptor {
  if (image === `${BUILTIN_PREFIX}oatmeal`) {
    return {
      token: image,
      primaryText: '燕麦',
      secondaryText: '牛奶杯',
      topColor: '#F8D4A5',
      bottomColor: '#D86C3D',
      accentColor: '#FFF6E8'
    };
  }
  if (image === `${BUILTIN_PREFIX}chicken-salad`) {
    return {
      token: image,
      primaryText: '鸡胸',
      secondaryText: '沙拉',
      topColor: '#B8E6C6',
      bottomColor: '#10B981',
      accentColor: '#ECFFF4'
    };
  }
  if (image === `${BUILTIN_PREFIX}salmon`) {
    return {
      token: image,
      primaryText: '三文鱼',
      secondaryText: '主餐',
      topColor: '#9EC7FF',
      bottomColor: '#0F6BFF',
      accentColor: '#EEF4FF'
    };
  }
  if (image === `${BUILTIN_PREFIX}yogurt`) {
    return {
      token: image,
      primaryText: '酸奶',
      secondaryText: '坚果碗',
      topColor: '#DEC9FF',
      bottomColor: '#7B61FF',
      accentColor: '#F5EEFF'
    };
  }
  if (image === `${BUILTIN_PREFIX}rice-beef`) {
    return {
      token: image,
      primaryText: '牛肉',
      secondaryText: '能量饭',
      topColor: '#9DE3DA',
      bottomColor: '#14B8A6',
      accentColor: '#EAFEF9'
    };
  }
  if (image === `${BUILTIN_PREFIX}egg-toast`) {
    return {
      token: image,
      primaryText: '鸡蛋',
      secondaryText: '吐司',
      topColor: '#FFD99A',
      bottomColor: '#F59E0B',
      accentColor: '#FFF7E8'
    };
  }
  if (image === `${BUILTIN_PREFIX}custom-card`) {
    return {
      token: image,
      primaryText: '自定义',
      secondaryText: '食物卡',
      topColor: '#B7D5FF',
      bottomColor: '#5373A6',
      accentColor: '#F3F7FF'
    };
  }
  if (image === `${BUILTIN_MEAL_PREFIX}lunch`) {
    return {
      token: image,
      primaryText: '午餐',
      secondaryText: '占位图',
      topColor: '#C8F1D6',
      bottomColor: '#10B981',
      accentColor: '#ECFFF4'
    };
  }
  if (image === `${BUILTIN_MEAL_PREFIX}dinner`) {
    return {
      token: image,
      primaryText: '晚餐',
      secondaryText: '占位图',
      topColor: '#C6DCFF',
      bottomColor: '#0F6BFF',
      accentColor: '#EEF4FF'
    };
  }
  if (image === `${BUILTIN_MEAL_PREFIX}snack`) {
    return {
      token: image,
      primaryText: '加餐',
      secondaryText: '占位图',
      topColor: '#E5D7FF',
      bottomColor: '#7B61FF',
      accentColor: '#F5EEFF'
    };
  }
  if (image === `${BUILTIN_MEAL_PREFIX}breakfast`) {
    return {
      token: image,
      primaryText: '早餐',
      secondaryText: '占位图',
      topColor: '#FFE1B0',
      bottomColor: '#F59E0B',
      accentColor: '#FFF7E8'
    };
  }
  return {
    token: image,
    primaryText: name.trim().length > 2 ? name.trim().substring(0, 2) : name.trim(),
    secondaryText: '食物',
    topColor: '#D7E5F7',
    bottomColor: '#6B8AB3',
    accentColor: '#F5F8FF'
  };
}
