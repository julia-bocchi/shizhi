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
      id: `${index + 1}`,
      date: formatDate(sampleDate),
      weight: sampleWeights[index]
    });
  }

  return result;
}

export function serializeWeightRecords(records: WeightRecord[]): string {
  let sanitizedRecords: WeightRecord[] = [];
  for (let index = 0; index < records.length; index++) {
    sanitizedRecords.push({
      id: `${records[index].id}`,
      date: records[index].date,
      weight: records[index].weight
    });
  }
  return JSON.stringify(sanitizedRecords);
}

export function deserializeWeightRecords(savedText: string): WeightRecord[] {
  if (savedText.trim().length === 0) {
    return [];
  }

  try {
    let parsedRecords = JSON.parse(savedText) as WeightRecord[];
    if (!Array.isArray(parsedRecords)) {
      return [];
    }

    let result: WeightRecord[] = [];
    for (let index = 0; index < parsedRecords.length; index++) {
      let currentRecord = parsedRecords[index];
      let parsedWeight = Number(currentRecord.weight);
      if (isNaN(parsedWeight)) {
        continue;
      }
      result.push({
        id: `${currentRecord.id}`,
        date: `${currentRecord.date}`,
        weight: parsedWeight
      });
    }

    result.sort((left: WeightRecord, right: WeightRecord) => compareRecordDate(left, right));
    return result;
  } catch (error) {
    return [];
  }
}

export function getNextWeightRecordId(records: WeightRecord[]): string {
  let nextId: number = 1;
  for (let index = 0; index < records.length; index++) {
    let parsedId = Number(records[index].id);
    if (!isNaN(parsedId) && parsedId >= nextId) {
      nextId = parsedId + 1;
    }
  }
  return `${nextId}`;
}

export function getRecentWeightRecords(records: WeightRecord[], limit: number = 7): WeightRecord[] {
  let sortedRecords = records.slice();
  sortedRecords.sort((left: WeightRecord, right: WeightRecord) => compareRecordDate(left, right));
  if (sortedRecords.length <= limit) {
    return sortedRecords;
  }
  return sortedRecords.slice(sortedRecords.length - limit, sortedRecords.length);
}

export function getLatestWeightRecord(records: WeightRecord[]): WeightRecord | undefined {
  let recentRecords = getRecentWeightRecords(records, records.length);
  if (recentRecords.length === 0) {
    return undefined;
  }
  return recentRecords[recentRecords.length - 1];
}

export function getAverageWeight(records: WeightRecord[]): number {
  if (records.length === 0) {
    return 0;
  }

  let totalWeight: number = 0;
  for (let index = 0; index < records.length; index++) {
    totalWeight += records[index].weight;
  }
  return totalWeight / records.length;
}

export function getWeightChange(records: WeightRecord[]): number {
  if (records.length < 2) {
    return 0;
  }
  return records[records.length - 1].weight - records[0].weight;
}
