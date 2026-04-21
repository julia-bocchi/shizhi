export interface BottomTabItem {
  id: string;
  icon: string;
  label: string;
  index: number;
}

export const HOME_TAB_INDEX: number = 0;
export const AI_TAB_INDEX: number = 1;
export const EXERCISE_TAB_INDEX: number = 2;
export const FOOD_TAB_INDEX: number = 3;
export const RECORD_TAB_INDEX: number = 4;
export const PROFILE_TAB_INDEX: number = 5;

// 页面标签配置集中放在这里，后续新增页签时只需要补一项即可。
export const APP_TAB_ITEMS: BottomTabItem[] = [
  {
    id: 'home',
    icon: '⌂',
    label: '首页',
    index: HOME_TAB_INDEX
  },
  {
    id: 'assistant',
    icon: 'AI',
    label: '助手',
    index: AI_TAB_INDEX
  },
  {
    id: 'exercise',
    icon: '◉',
    label: '运动',
    index: EXERCISE_TAB_INDEX
  },
  {
    id: 'food',
    icon: '食',
    label: '饮食',
    index: FOOD_TAB_INDEX
  },
  {
    id: 'record',
    icon: '⚖',
    label: '记录',
    index: RECORD_TAB_INDEX
  },
  {
    id: 'profile',
    icon: '☺',
    label: '我的',
    index: PROFILE_TAB_INDEX
  }
];
