import { formatDate } from './WeightRecordHelper';

export interface CalendarMonthCell {
  key: string;
  dateText: string;
  dayNumber: number;
  isCurrentMonth: boolean;
  isToday: boolean;
}

export interface CalendarMonthCursor {
  year: number;
  month: number;
}

export const CALENDAR_WEEK_LABELS: string[] = ['一', '二', '三', '四', '五', '六', '日'];

export function formatMonthTitle(year: number, month: number): string {
  return `${year}年${month + 1}月`;
}

export function shiftCalendarMonth(year: number, month: number, step: number): CalendarMonthCursor {
  let nextMonth: number = month + step;
  let nextYear: number = year;

  while (nextMonth < 0) {
    nextMonth += 12;
    nextYear -= 1;
  }

  while (nextMonth > 11) {
    nextMonth -= 12;
    nextYear += 1;
  }

  return {
    year: nextYear,
    month: nextMonth
  };
}

export function buildMonthCalendarRows(
  year: number,
  month: number,
  todayText: string = formatDate(new Date())
): CalendarMonthCell[][] {
  let monthStart = new Date(year, month, 1);
  let offset = (monthStart.getDay() + 6) % 7;
  let firstCellDate = new Date(year, month, 1 - offset);
  let rows: CalendarMonthCell[][] = [];
  let currentRow: CalendarMonthCell[] = [];

  for (let index = 0; index < 42; index++) {
    let currentDate = new Date(firstCellDate.getTime());
    currentDate.setDate(firstCellDate.getDate() + index);
    let currentDateText: string = formatDate(currentDate);
    let isCurrentMonth: boolean = currentDate.getMonth() === month;

    currentRow.push({
      key: currentDateText,
      dateText: currentDateText,
      dayNumber: currentDate.getDate(),
      isCurrentMonth: isCurrentMonth,
      isToday: currentDateText === todayText
    });

    if (currentRow.length === 7) {
      rows.push(currentRow.slice());
      currentRow = [];
    }
  }

  while (rows.length > 4) {
    let lastRow = rows[rows.length - 1];
    let lastRowHasCurrentMonthDate = false;
    for (let index = 0; index < lastRow.length; index++) {
      if (lastRow[index].isCurrentMonth) {
        lastRowHasCurrentMonthDate = true;
        break;
      }
    }
    if (lastRowHasCurrentMonthDate) {
      break;
    }
    rows.pop();
  }

  return rows;
}
