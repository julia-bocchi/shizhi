export interface BottomTabItem {
  id: string;
  icon: string;
  label: string;
  index: number;
}

export const HOME_TAB_INDEX: number = 0;
export const RECORD_TAB_INDEX: number = 1;

// 页面标签配置集中放在这里，后续新增页签时只需要补一项即可。
export const APP_TAB_ITEMS: BottomTabItem[] = [
  {
    id: 'home',
    icon: '⌂',
    label: '首页',
    index: HOME_TAB_INDEX
  },
  {
    id: 'record',
    icon: '⚖',
    label: '记录',
    index: RECORD_TAB_INDEX
  }
];
