export interface FoodOption {
  id: string;
  name: string;
  description: string;
  calories: number;
  serving: string;
  mealSuggestion: string;
  image: string;
  accentColor: string;
}

export interface FoodMealOption {
  id: string;
  label: string;
}

export const FOOD_MEAL_OPTIONS: FoodMealOption[] = [
  {
    id: 'breakfast',
    label: '早餐'
  },
  {
    id: 'lunch',
    label: '午餐'
  },
  {
    id: 'dinner',
    label: '晚餐'
  },
  {
    id: 'snack',
    label: '加餐'
  }
];

export const PRESET_FOOD_OPTIONS: FoodOption[] = [
  {
    id: 'preset-oatmeal',
    name: '燕麦牛奶杯',
    description: '适合早餐或训练前补充碳水，饱腹感稳定。',
    calories: 280,
    serving: '1 杯',
    mealSuggestion: '早餐',
    image: 'builtin:food:oatmeal',
    accentColor: '#D86C3D'
  },
  {
    id: 'preset-chicken-salad',
    name: '鸡胸肉沙拉',
    description: '高蛋白、轻负担，适合作为午餐或减脂晚餐。',
    calories: 320,
    serving: '1 份',
    mealSuggestion: '午餐',
    image: 'builtin:food:chicken-salad',
    accentColor: '#10B981'
  },
  {
    id: 'preset-salmon',
    name: '香煎三文鱼',
    description: '补充优质脂肪和蛋白质，适合主餐搭配。',
    calories: 410,
    serving: '180 g',
    mealSuggestion: '晚餐',
    image: 'builtin:food:salmon',
    accentColor: '#0F6BFF'
  },
  {
    id: 'preset-yogurt',
    name: '无糖酸奶坚果碗',
    description: '可以放在早餐或下午加餐，制作简单。',
    calories: 230,
    serving: '1 碗',
    mealSuggestion: '加餐',
    image: 'builtin:food:yogurt',
    accentColor: '#7B61FF'
  },
  {
    id: 'preset-rice-beef',
    name: '牛肉饭',
    description: '常规主食搭配蛋白质，适合作为中午能量补充。',
    calories: 560,
    serving: '1 份',
    mealSuggestion: '午餐',
    image: 'builtin:food:rice-beef',
    accentColor: '#14B8A6'
  },
  {
    id: 'preset-egg-toast',
    name: '鸡蛋全麦吐司',
    description: '快捷早餐选择，适合通勤前准备。',
    calories: 260,
    serving: '2 片',
    mealSuggestion: '早餐',
    image: 'builtin:food:egg-toast',
    accentColor: '#F59E0B'
  }
];
