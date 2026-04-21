import { describe, it, expect } from '@ohos/hypium';
import {
  buildMonthCalendarRows,
  formatMonthTitle,
  shiftCalendarMonth
} from '../main/ets/utils/MonthCalendarHelper';

export default function monthCalendarHelperTest() {
  describe('monthCalendarHelperTest', () => {
    it('buildMonthCalendarRows keeps six rows and monday-first layout', 0, () => {
      let rows = buildMonthCalendarRows(2026, 3, '2026-04-19');

      expect(rows.length).assertEqual(6);
      expect(rows[0].length).assertEqual(7);
      expect(rows[0][0].dateText).assertEqual('2026-03-30');
      expect(rows[5][6].dateText).assertEqual('2026-05-10');
    });

    it('buildMonthCalendarRows marks current month and today correctly', 0, () => {
      let rows = buildMonthCalendarRows(2026, 3, '2026-04-19');
      let todayCell = rows[2][6];
      let outsideCell = rows[0][0];

      expect(todayCell.dateText).assertEqual('2026-04-19');
      expect(todayCell.isToday).assertEqual(true);
      expect(todayCell.isCurrentMonth).assertEqual(true);
      expect(outsideCell.isCurrentMonth).assertEqual(false);
    });

    it('shiftCalendarMonth crosses year boundaries', 0, () => {
      let previousCursor = shiftCalendarMonth(2026, 0, -1);
      let nextCursor = shiftCalendarMonth(2026, 11, 1);

      expect(previousCursor.year).assertEqual(2025);
      expect(previousCursor.month).assertEqual(11);
      expect(nextCursor.year).assertEqual(2027);
      expect(nextCursor.month).assertEqual(0);
    });

    it('formatMonthTitle keeps expected label', 0, () => {
      expect(formatMonthTitle(2026, 3)).assertEqual('2026年4月');
    });
  });
}
