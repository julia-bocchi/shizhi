export const EXERCISE_MODE_SET_TIMER: string = 'set_timer';
export const EXERCISE_MODE_DISTANCE_PACE: string = 'distance_pace';
export const EXERCISE_MODE_DISTANCE_SPEED: string = 'distance_speed';
export const EXERCISE_MODE_COUNT_RATE: string = 'count_rate';
export const EXERCISE_MODE_DURATION: string = 'duration';
export const EXERCISE_MODE_CUSTOM: string = 'custom';

export const CUSTOM_INTENSITY_LIGHT: string = 'light';
export const CUSTOM_INTENSITY_MODERATE: string = 'moderate';
export const CUSTOM_INTENSITY_INTENSE: string = 'intense';

export interface ExerciseOption {
  id: string;
  name: string;
  description: string;
  mode: string;
  met: number;
  accentColor: string;
}

export interface ExerciseDraft {
  exerciseId: string;
  customName: string;
  customMode: string;
  customIntensity: string;
  durationMinutes: string;
  distanceKm: string;
  paceMinutes: string;
  speedKmH: string;
  count: string;
  cadencePerMinute: string;
  sets: string;
  workSeconds: string;
  restSeconds: string;
}

export interface SavedCustomWorkout {
  id: string;
  name: string;
  mode: string;
  intensity: string;
  durationMinutes: string;
  distanceKm: string;
  paceMinutes: string;
  speedKmH: string;
  count: string;
  cadencePerMinute: string;
  sets: string;
  workSeconds: string;
  restSeconds: string;
}

export interface CustomIntensityOption {
  id: string;
  label: string;
  description: string;
  met: number;
}

export interface WorkoutMetrics {
  exerciseName: string;
  mode: string;
  modeLabel: string;
  durationMinutes: number;
  durationText: string;
  distanceKm: number;
  distanceText: string;
  count: number;
  countText: string;
  calories: number;
  calorieText: string;
  met: number;
  validationMessage: string;
  missingProfileMessage: string;
  summaryText: string;
  detailText: string;
  recommendationText: string;
  canEstimateCalories: boolean;
}

export const EXERCISE_OPTIONS: ExerciseOption[] = [
  {
    id: 'hiit',
    name: 'HIIT 间歇',
    description: '按组训练，适合燃脂和爆发力练习。',
    mode: EXERCISE_MODE_SET_TIMER,
    met: 8.5,
    accentColor: '#D86C3D'
  },
  {
    id: 'running',
    name: '跑步',
    description: '根据配速和路程估算总时长与热量。',
    mode: EXERCISE_MODE_DISTANCE_PACE,
    met: 9.8,
    accentColor: '#2F6FED'
  },
  {
    id: 'cycling',
    name: '骑行',
    description: '根据均速和路程估算本次运动时长。',
    mode: EXERCISE_MODE_DISTANCE_SPEED,
    met: 7.5,
    accentColor: '#2E8B57'
  },
  {
    id: 'jump_rope',
    name: '跳绳',
    description: '根据总个数和频率估算训练时长。',
    mode: EXERCISE_MODE_COUNT_RATE,
    met: 11.8,
    accentColor: '#C14D7F'
  },
  {
    id: 'yoga',
    name: '瑜伽',
    description: '按持续时长估算消耗，适合拉伸和放松。',
    mode: EXERCISE_MODE_DURATION,
    met: 3.0,
    accentColor: '#8B6BC7'
  },
  {
    id: 'strength',
    name: '力量循环',
    description: '适合自重或器械训练，支持按组计时。',
    mode: EXERCISE_MODE_SET_TIMER,
    met: 6.0,
    accentColor: '#355C7D'
  },
  {
    id: 'custom',
    name: '自定义运动',
    description: '输入关键数据，自行组合时长、组数、次数或距离。',
    mode: EXERCISE_MODE_CUSTOM,
    met: 5.5,
    accentColor: '#7A5C2E'
  }
];

export const CUSTOM_MODE_OPTIONS: ExerciseOption[] = [
  {
    id: EXERCISE_MODE_DURATION,
    name: '按时长',
    description: '适合瑜伽、散步、拉伸等持续型运动。',
    mode: EXERCISE_MODE_DURATION,
    met: 5.5,
    accentColor: '#7A5C2E'
  },
  {
    id: EXERCISE_MODE_SET_TIMER,
    name: '按组计时',
    description: '适合循环训练、力量训练或间歇训练。',
    mode: EXERCISE_MODE_SET_TIMER,
    met: 5.5,
    accentColor: '#7A5C2E'
  },
  {
    id: EXERCISE_MODE_COUNT_RATE,
    name: '按个数',
    description: '适合俯卧撑、跳绳、仰卧起坐等计数运动。',
    mode: EXERCISE_MODE_COUNT_RATE,
    met: 5.5,
    accentColor: '#7A5C2E'
  },
  {
    id: EXERCISE_MODE_DISTANCE_PACE,
    name: '按配速+路程',
    description: '适合跑步、徒步、游走等有路线的运动。',
    mode: EXERCISE_MODE_DISTANCE_PACE,
    met: 5.5,
    accentColor: '#7A5C2E'
  },
  {
    id: EXERCISE_MODE_DISTANCE_SPEED,
    name: '按均速+路程',
    description: '适合骑行、滑板、自行车等速度型运动。',
    mode: EXERCISE_MODE_DISTANCE_SPEED,
    met: 5.5,
    accentColor: '#7A5C2E'
  }
];

export const CUSTOM_INTENSITY_OPTIONS: CustomIntensityOption[] = [
  {
    id: CUSTOM_INTENSITY_LIGHT,
    label: '轻松',
    description: '恢复、拉伸或轻度活动。',
    met: 3.5
  },
  {
    id: CUSTOM_INTENSITY_MODERATE,
    label: '中等',
    description: '日常锻炼最常见的强度区间。',
    met: 5.5
  },
  {
    id: CUSTOM_INTENSITY_INTENSE,
    label: '高强',
    description: '心率更高，适合冲刺或高密度循环。',
    met: 8.0
  }
];

export function createDefaultExerciseDraft(): ExerciseDraft {
  return {
    exerciseId: 'hiit',
    customName: '',
    customMode: EXERCISE_MODE_DURATION,
    customIntensity: CUSTOM_INTENSITY_MODERATE,
    durationMinutes: '30',
    distanceKm: '5',
    paceMinutes: '6',
    speedKmH: '18',
    count: '300',
    cadencePerMinute: '120',
    sets: '4',
    workSeconds: '40',
    restSeconds: '20'
  };
}
