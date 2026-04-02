import { WeightRecord } from '../models/WeightRecord';

export const CHART_BAR_TRACK_HEIGHT: number = 140;
export const CHART_BAR_MIN_HEIGHT: number = 30;
export const CHART_BAR_MAX_HEIGHT: number = 112;
export const CHART_MIN_SPAN: number = 3;
export const CHART_SCALE_STEP: number = 0.5;

function padDate(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}

export function formatDate(date: Date): string {
  return `${date.getFullYear()}-${padDate(date.getMonth() + 1)}-${padDate(date.getDate())}`;
}

export function clamp(value: number, minValue: number, maxValue: number): number {
  if (value < minValue) {
    return minValue;
  }
  if (value > maxValue) {
    return maxValue;
  }
  return value;
}

export function roundDownToStep(value: number, step: number): number {
  return Math.floor(value / step) * step;
}

export function roundUpToStep(value: number, step: number): number {
  return Math.ceil(value / step) * step;
}

export function compareRecordDate(left: WeightRecord, right: WeightRecord): number {
  if (left.date > right.date) {
    return 1;
  }
  if (left.date < right.date) {
    return -1;
  }
  return 0;
}

export function createSampleRecords(): WeightRecord[] {
  const sampleWeights: number[] = [69.8, 69.5, 69.3, 69.1, 68.9, 68.7, 68.5];
  let result: WeightRecord[] = [];
  let today = new Date();

  for (let index = 0; index < sampleWeights.length; index++) {
    let sampleDate = new Date(today.getTime());
    sampleDate.setDate(today.getDate() - (sampleWeights.length - 1 - index));
    result.push({
      id: index + 1,
      date: formatDate(sampleDate),
      weight: sampleWeights[index]
    });
  }

  return result;
}
