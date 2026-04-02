export interface BottomTabItem {
  id: string;
  label: string;
  index: number;
}

export const HOME_TAB_INDEX: number = 0;
export const RECORD_TAB_INDEX: number = 1;

export const APP_TAB_ITEMS: BottomTabItem[] = [
  {
    id: 'home',
    label: '首页',
    index: HOME_TAB_INDEX
  },
  {
    id: 'record',
    label: '记录',
    index: RECORD_TAB_INDEX
  }
];
