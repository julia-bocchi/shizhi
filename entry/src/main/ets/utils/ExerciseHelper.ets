import {
  CUSTOM_INTENSITY_INTENSE,
  CUSTOM_INTENSITY_LIGHT,
  CUSTOM_INTENSITY_OPTIONS,
  CUSTOM_MODE_OPTIONS,
  EXERCISE_MODE_COUNT_RATE,
  EXERCISE_MODE_CUSTOM,
  EXERCISE_MODE_DISTANCE_PACE,
  EXERCISE_MODE_DISTANCE_SPEED,
  EXERCISE_MODE_DURATION,
  EXERCISE_MODE_SET_TIMER,
  EXERCISE_OPTIONS,
  ExerciseDraft,
  ExerciseOption,
  SavedCustomWorkout,
  WorkoutMetrics,
  createDefaultExerciseDraft
} from '../models/ExerciseOption';
import {
  GENDER_FEMALE,
  GENDER_MALE,
  GENDER_UNKNOWN,
  UserProfile,
  createEmptyUserProfile
} from '../models/UserProfile';
import { WorkoutRecord } from '../models/WorkoutRecord';

export interface BmiInfo {
  hasValue: boolean;
  value: number;
  valueText: string;
  statusText: string;
  suggestionText: string;
}

function parseNumber(value: string): number {
  let parsedValue = Number(value.trim());
  if (isNaN(parsedValue)) {
    return 0;
  }
  return parsedValue;
}

function parsePositiveNumber(value: string): number {
  let parsedValue = parseNumber(value);
  if (parsedValue <= 0) {
    return 0;
  }
  return parsedValue;
}

function formatDecimal(value: number, fractionDigits: number = 1): string {
  return value.toFixed(fractionDigits);
}

export function findExerciseOption(optionId: string): ExerciseOption {
  for (let index = 0; index < EXERCISE_OPTIONS.length; index++) {
    if (EXERCISE_OPTIONS[index].id === optionId) {
      return EXERCISE_OPTIONS[index];
    }
  }
  return EXERCISE_OPTIONS[0];
}

export function findCustomModeOption(modeId: string): ExerciseOption {
  for (let index = 0; index < CUSTOM_MODE_OPTIONS.length; index++) {
    if (CUSTOM_MODE_OPTIONS[index].id === modeId) {
      return CUSTOM_MODE_OPTIONS[index];
    }
  }
  return CUSTOM_MODE_OPTIONS[0];
}

export function getActiveWorkoutMode(draft: ExerciseDraft): string {
  let selectedOption = findExerciseOption(draft.exerciseId);
  if (selectedOption.mode === EXERCISE_MODE_CUSTOM) {
    return draft.customMode;
  }
  return selectedOption.mode;
}

export function getWorkoutModeLabel(mode: string): string {
  if (mode === EXERCISE_MODE_SET_TIMER) {
    return '按组计时';
  }
  if (mode === EXERCISE_MODE_DISTANCE_PACE) {
    return '配速 + 路程';
  }
  if (mode === EXERCISE_MODE_DISTANCE_SPEED) {
    return '均速 + 路程';
  }
  if (mode === EXERCISE_MODE_COUNT_RATE) {
    return '次数 + 节奏';
  }
  if (mode === EXERCISE_MODE_DURATION) {
    return '按时长';
  }
  return '自定义';
}

export function getWorkoutTitle(draft: ExerciseDraft): string {
  let selectedOption = findExerciseOption(draft.exerciseId);
  if (selectedOption.id === 'custom') {
    let trimmedName = draft.customName.trim();
    if (trimmedName.length > 0) {
      return trimmedName;
    }
    return '自定义运动';
  }
  return selectedOption.name;
}

export function getCustomMetValue(intensityId: string): number {
  for (let index = 0; index < CUSTOM_INTENSITY_OPTIONS.length; index++) {
    if (CUSTOM_INTENSITY_OPTIONS[index].id === intensityId) {
      return CUSTOM_INTENSITY_OPTIONS[index].met;
    }
  }
  return 5.5;
}

export function getCustomIntensityLabel(intensityId: string): string {
  if (intensityId === CUSTOM_INTENSITY_LIGHT) {
    return '轻松';
  }
  if (intensityId === CUSTOM_INTENSITY_INTENSE) {
    return '高强';
  }
  return '中等';
}

export function getWorkoutMetValue(draft: ExerciseDraft): number {
  let selectedOption = findExerciseOption(draft.exerciseId);
  if (selectedOption.id === 'custom') {
    return getCustomMetValue(draft.customIntensity);
  }
  return selectedOption.met;
}

export function getWorkoutDurationMinutes(draft: ExerciseDraft): number {
  let activeMode = getActiveWorkoutMode(draft);
  let distanceKm = parsePositiveNumber(draft.distanceKm);
  let paceMinutes = parsePositiveNumber(draft.paceMinutes);
  let speedKmH = parsePositiveNumber(draft.speedKmH);
  let count = parsePositiveNumber(draft.count);
  let cadence = parsePositiveNumber(draft.cadencePerMinute);
  let sets = parsePositiveNumber(draft.sets);
  let workSeconds = parsePositiveNumber(draft.workSeconds);
  let restSeconds = parsePositiveNumber(draft.restSeconds);

  if (activeMode === EXERCISE_MODE_DURATION) {
    return parsePositiveNumber(draft.durationMinutes);
  }

  if (activeMode === EXERCISE_MODE_DISTANCE_PACE) {
    if (distanceKm <= 0 || paceMinutes <= 0) {
      return 0;
    }
    return distanceKm * paceMinutes;
  }

  if (activeMode === EXERCISE_MODE_DISTANCE_SPEED) {
    if (distanceKm <= 0 || speedKmH <= 0) {
      return 0;
    }
    return distanceKm / speedKmH * 60;
  }

  if (activeMode === EXERCISE_MODE_COUNT_RATE) {
    if (count <= 0 || cadence <= 0) {
      return 0;
    }
    return count / cadence;
  }

  if (activeMode === EXERCISE_MODE_SET_TIMER) {
    if (sets <= 0 || workSeconds <= 0) {
      return 0;
    }
    return (sets * workSeconds + Math.max(0, sets - 1) * restSeconds) / 60;
  }

  return 0;
}

export function getSetTimerTotalSeconds(draft: ExerciseDraft): number {
  if (getActiveWorkoutMode(draft) !== EXERCISE_MODE_SET_TIMER) {
    return 0;
  }
  let sets = parsePositiveNumber(draft.sets);
  let workSeconds = parsePositiveNumber(draft.workSeconds);
  let restSeconds = parsePositiveNumber(draft.restSeconds);
  if (sets <= 0 || workSeconds <= 0) {
    return 0;
  }
  return Math.round(sets * workSeconds + Math.max(0, sets - 1) * restSeconds);
}

export function calculateCaloriesBurned(weightKg: number, met: number, durationMinutes: number): number {
  if (weightKg <= 0 || met <= 0 || durationMinutes <= 0) {
    return 0;
  }
  return met * 3.5 * weightKg / 200 * durationMinutes;
}

export function getWeightValue(profile: UserProfile): number {
  return parsePositiveNumber(profile.weightKg);
}

export function getHeightValue(profile: UserProfile): number {
  return parsePositiveNumber(profile.heightCm);
}

export function getAgeValue(profile: UserProfile): number {
  return parsePositiveNumber(profile.age);
}

export function getMissingProfileFields(profile: UserProfile): string[] {
  let missingFields: string[] = [];
  if (getHeightValue(profile) <= 0) {
    missingFields.push('身高');
  }
  if (getWeightValue(profile) <= 0) {
    missingFields.push('体重');
  }
  if (getAgeValue(profile) <= 0) {
    missingFields.push('年龄');
  }
  if (profile.gender === GENDER_UNKNOWN) {
    missingFields.push('性别');
  }
  return missingFields;
}

export function getProfileCompletionCount(profile: UserProfile): number {
  return 4 - getMissingProfileFields(profile).length;
}

export function getProfileCompletionText(profile: UserProfile): string {
  return `${getProfileCompletionCount(profile)}/4 项已填写`;
}

export function getProfileReminderText(profile: UserProfile): string {
  let missingFields = getMissingProfileFields(profile);
  if (missingFields.length === 0) {
    return '资料完整，可以直接用于 BMI 和热量估算。';
  }
  return `还缺少：${missingFields.join('、')}。`;
}

export function getCalorieRequirementText(profile: UserProfile): string {
  let weightKg = getWeightValue(profile);
  if (weightKg <= 0) {
    return '缺少体重，暂时无法计算热量。';
  }
  return `当前使用体重 ${formatDecimal(weightKg)} kg 参与热量估算。`;
}

export function getGenderSuggestion(profile: UserProfile): string {
  if (profile.gender === GENDER_MALE) {
    return '已按男性资料保存，可继续补充身高和体重。';
  }
  if (profile.gender === GENDER_FEMALE) {
    return '已按女性资料保存，可继续补充身高和体重。';
  }
  return '性别暂未填写，不影响基础热量公式，但会影响资料完整度。';
}

export function getBmiInfo(profile: UserProfile): BmiInfo {
  let heightCm = getHeightValue(profile);
  let weightKg = getWeightValue(profile);

  if (heightCm <= 0 || weightKg <= 0) {
    return {
      hasValue: false,
      value: 0,
      valueText: '--',
      statusText: '等待资料',
      suggestionText: '填写身高和体重后即可自动生成 BMI。'
    };
  }

  let heightMeter = heightCm / 100;
  let bmiValue = weightKg / (heightMeter * heightMeter);

  if (bmiValue < 18.5) {
    return {
      hasValue: true,
      value: bmiValue,
      valueText: formatDecimal(bmiValue, 1),
      statusText: '偏瘦',
      suggestionText: '可以适当增加力量训练和蛋白质摄入，避免长期能量不足。'
    };
  }

  if (bmiValue < 24) {
    return {
      hasValue: true,
      value: bmiValue,
      valueText: formatDecimal(bmiValue, 1),
      statusText: '正常',
      suggestionText: '当前体型处于常见健康区间，适合维持规律训练。'
    };
  }

  if (bmiValue < 28) {
    return {
      hasValue: true,
      value: bmiValue,
      valueText: formatDecimal(bmiValue, 1),
      statusText: '超重',
      suggestionText: '建议优先安排中等强度有氧和力量训练的组合。'
    };
  }

  return {
    hasValue: true,
    value: bmiValue,
    valueText: formatDecimal(bmiValue, 1),
    statusText: '肥胖',
    suggestionText: '建议先从低冲击运动开始，循序渐进提高训练量。'
  };
}

export function formatDurationText(durationMinutes: number): string {
  if (durationMinutes <= 0) {
    return '--';
  }

  let totalMinutes = Math.round(durationMinutes);
  if (totalMinutes < 60) {
    return `${totalMinutes} 分钟`;
  }

  let hours = Math.floor(totalMinutes / 60);
  let minutes = totalMinutes % 60;
  if (minutes === 0) {
    return `${hours} 小时`;
  }
  return `${hours} 小时 ${minutes} 分钟`;
}

export function formatClockText(totalSeconds: number): string {
  if (totalSeconds < 0) {
    totalSeconds = 0;
  }
  let minutes = Math.floor(totalSeconds / 60);
  let seconds = totalSeconds % 60;
  let minuteText = minutes < 10 ? `0${minutes}` : `${minutes}`;
  let secondText = seconds < 10 ? `0${seconds}` : `${seconds}`;
  return `${minuteText}:${secondText}`;
}

export function getWorkoutMetrics(profile: UserProfile, draft: ExerciseDraft): WorkoutMetrics {
  let exerciseName = getWorkoutTitle(draft);
  let activeMode = getActiveWorkoutMode(draft);
  let durationMinutes = getWorkoutDurationMinutes(draft);
  let distanceKm = parsePositiveNumber(draft.distanceKm);
  let count = parsePositiveNumber(draft.count);
  let weightKg = getWeightValue(profile);
  let met = getWorkoutMetValue(draft);
  let calories = calculateCaloriesBurned(weightKg, met, durationMinutes);
  let validationMessage = getWorkoutValidationMessage(draft);
  let missingProfileMessage = getCalorieRequirementText(profile);
  let summaryText = buildWorkoutSummary(draft, durationMinutes);
  let detailText = buildWorkoutDetail(draft, durationMinutes, met);
  let recommendationText = buildWorkoutRecommendation(profile, draft, durationMinutes);
  let canEstimateCalories = validationMessage.length === 0 && weightKg > 0 && durationMinutes > 0;

  return {
    exerciseName: exerciseName,
    mode: activeMode,
    modeLabel: getWorkoutModeLabel(activeMode),
    durationMinutes: durationMinutes,
    durationText: formatDurationText(durationMinutes),
    distanceKm: distanceKm,
    distanceText: distanceKm > 0 ? `${formatDecimal(distanceKm)} km` : '--',
    count: count,
    countText: count > 0 ? `${Math.round(count)} 次` : '--',
    calories: calories,
    calorieText: canEstimateCalories ? `${Math.round(calories)} kcal` : '--',
    met: met,
    validationMessage: validationMessage,
    missingProfileMessage: missingProfileMessage,
    summaryText: summaryText,
    detailText: detailText,
    recommendationText: recommendationText,
    canEstimateCalories: canEstimateCalories
  };
}

export function getWorkoutValidationMessage(draft: ExerciseDraft): string {
  let activeMode = getActiveWorkoutMode(draft);

  if (draft.exerciseId === 'custom' && draft.customName.trim().length === 0) {
    return '自定义运动请先填写运动名称。';
  }

  if (activeMode === EXERCISE_MODE_DURATION) {
    if (parsePositiveNumber(draft.durationMinutes) <= 0) {
      return '请输入本次运动时长（分钟）。';
    }
    return '';
  }

  if (activeMode === EXERCISE_MODE_DISTANCE_PACE) {
    if (parsePositiveNumber(draft.distanceKm) <= 0) {
      return '请输入运动路程（km）。';
    }
    if (parsePositiveNumber(draft.paceMinutes) <= 0) {
      return '请输入平均配速（分钟 / km）。';
    }
    return '';
  }

  if (activeMode === EXERCISE_MODE_DISTANCE_SPEED) {
    if (parsePositiveNumber(draft.distanceKm) <= 0) {
      return '请输入运动路程（km）。';
    }
    if (parsePositiveNumber(draft.speedKmH) <= 0) {
      return '请输入平均速度（km/h）。';
    }
    return '';
  }

  if (activeMode === EXERCISE_MODE_COUNT_RATE) {
    if (parsePositiveNumber(draft.count) <= 0) {
      return '请输入运动个数或总次数。';
    }
    if (parsePositiveNumber(draft.cadencePerMinute) <= 0) {
      return '请输入平均节奏（次 / 分钟）。';
    }
    return '';
  }

  if (activeMode === EXERCISE_MODE_SET_TIMER) {
    if (parsePositiveNumber(draft.sets) <= 0) {
      return '请输入训练组数。';
    }
    if (parsePositiveNumber(draft.workSeconds) <= 0) {
      return '请输入每组训练秒数。';
    }
    return '';
  }

  return '';
}

function buildWorkoutSummary(draft: ExerciseDraft, durationMinutes: number): string {
  let activeMode = getActiveWorkoutMode(draft);

  if (activeMode === EXERCISE_MODE_SET_TIMER) {
    let sets = parsePositiveNumber(draft.sets);
    let workSeconds = parsePositiveNumber(draft.workSeconds);
    let restSeconds = parsePositiveNumber(draft.restSeconds);
    if (sets <= 0 || workSeconds <= 0) {
      return '输入组数和每组秒数后，这里会给出完整训练摘要。';
    }
    return `${Math.round(sets)} 组训练，每组 ${Math.round(workSeconds)} 秒，组间休息 ${Math.round(restSeconds)} 秒，总时长约 ${formatDurationText(durationMinutes)}。`;
  }

  if (activeMode === EXERCISE_MODE_DISTANCE_PACE) {
    let distanceKm = parsePositiveNumber(draft.distanceKm);
    let paceMinutes = parsePositiveNumber(draft.paceMinutes);
    if (distanceKm <= 0 || paceMinutes <= 0) {
      return '输入路程和配速后，我会自动估算本次训练总时长。';
    }
    return `按 ${formatDecimal(paceMinutes)} 分钟 / km 的配速完成 ${formatDecimal(distanceKm)} km，预计用时 ${formatDurationText(durationMinutes)}。`;
  }

  if (activeMode === EXERCISE_MODE_DISTANCE_SPEED) {
    let distanceKm = parsePositiveNumber(draft.distanceKm);
    let speedKmH = parsePositiveNumber(draft.speedKmH);
    if (distanceKm <= 0 || speedKmH <= 0) {
      return '输入路程和均速后，我会自动估算训练用时。';
    }
    return `按 ${formatDecimal(speedKmH)} km/h 的均速完成 ${formatDecimal(distanceKm)} km，预计用时 ${formatDurationText(durationMinutes)}。`;
  }

  if (activeMode === EXERCISE_MODE_COUNT_RATE) {
    let count = parsePositiveNumber(draft.count);
    let cadence = parsePositiveNumber(draft.cadencePerMinute);
    if (count <= 0 || cadence <= 0) {
      return '输入总次数和节奏后，我会自动估算本次训练时长。';
    }
    return `总计 ${Math.round(count)} 次，平均 ${Math.round(cadence)} 次 / 分钟，预计用时 ${formatDurationText(durationMinutes)}。`;
  }

  if (activeMode === EXERCISE_MODE_DURATION) {
    if (parsePositiveNumber(draft.durationMinutes) <= 0) {
      return '输入训练分钟数后，我会估算热量和强度。';
    }
    return `本次训练持续 ${formatDurationText(durationMinutes)}，适合做稳定节奏的持续运动。`;
  }

  return '选择运动后即可生成训练摘要。';
}

function buildWorkoutDetail(draft: ExerciseDraft, durationMinutes: number, met: number): string {
  let activeMode = getActiveWorkoutMode(draft);
  if (activeMode === EXERCISE_MODE_SET_TIMER) {
    return `热量会按总训练时长估算，当前 MET 取值 ${formatDecimal(met)}。`;
  }
  if (activeMode === EXERCISE_MODE_DISTANCE_PACE || activeMode === EXERCISE_MODE_DISTANCE_SPEED) {
    return `时长由路程换算得到，当前预计总时长 ${formatDurationText(durationMinutes)}，MET ${formatDecimal(met)}。`;
  }
  if (activeMode === EXERCISE_MODE_COUNT_RATE) {
    return `时长根据“总个数 ÷ 平均节奏”推算，当前 MET ${formatDecimal(met)}。`;
  }
  return `热量采用常见公式：MET × 3.5 × 体重(kg) ÷ 200 × 时长(分钟)，当前 MET ${formatDecimal(met)}。`;
}

function buildWorkoutRecommendation(profile: UserProfile, draft: ExerciseDraft, durationMinutes: number): string {
  let bmiInfo = getBmiInfo(profile);
  let activeMode = getActiveWorkoutMode(draft);

  if (!bmiInfo.hasValue) {
    return '补充身高和体重后，我会结合 BMI 给出更贴近你的训练建议。';
  }

  if (bmiInfo.statusText === '偏瘦') {
    return activeMode === EXERCISE_MODE_SET_TIMER
      ? '偏瘦用户建议控制高强度训练总量，优先保证恢复和力量增长。'
      : '偏瘦用户建议把有氧时长控制在可恢复范围内，并配合力量训练。';
  }

  if (bmiInfo.statusText === '正常') {
    return durationMinutes >= 40
      ? '训练时长比较充足，记得补水和拉伸，维持一周 3 到 5 次会更稳定。'
      : '当前训练强度适中，适合配合规律作息和持续跟踪。';
  }

  if (bmiInfo.statusText === '超重') {
    return activeMode === EXERCISE_MODE_SET_TIMER
      ? '如果感觉冲击较大，可以适当拉长休息时间，循序渐进增加训练量。'
      : '建议优先选择中等强度、对关节更友好的运动方式。';
  }

  return '建议从低冲击、可持续完成的训练开始，先建立稳定运动习惯。';
}

export function getSetTimerStageText(draft: ExerciseDraft, elapsedSeconds: number): string {
  let totalSeconds = getSetTimerTotalSeconds(draft);
  if (totalSeconds <= 0) {
    return '请先输入组数和每组训练秒数';
  }
  if (elapsedSeconds >= totalSeconds) {
    return '全部训练已完成';
  }

  let sets = Math.round(parsePositiveNumber(draft.sets));
  let workSeconds = Math.round(parsePositiveNumber(draft.workSeconds));
  let restSeconds = Math.round(parsePositiveNumber(draft.restSeconds));
  let remainingElapsed = elapsedSeconds;

  for (let setIndex = 1; setIndex <= sets; setIndex++) {
    if (remainingElapsed < workSeconds) {
      return `第 ${setIndex} 组训练中`;
    }
    remainingElapsed -= workSeconds;
    if (setIndex === sets) {
      break;
    }
    if (remainingElapsed < restSeconds) {
      return `第 ${setIndex} 组休息中`;
    }
    remainingElapsed -= restSeconds;
  }

  return '准备开始';
}

export function getSetTimerStageRemainingText(draft: ExerciseDraft, elapsedSeconds: number): string {
  let totalSeconds = getSetTimerTotalSeconds(draft);
  if (totalSeconds <= 0) {
    return '00:00';
  }
  if (elapsedSeconds >= totalSeconds) {
    return '00:00';
  }

  let sets = Math.round(parsePositiveNumber(draft.sets));
  let workSeconds = Math.round(parsePositiveNumber(draft.workSeconds));
  let restSeconds = Math.round(parsePositiveNumber(draft.restSeconds));
  let remainingElapsed = elapsedSeconds;

  for (let setIndex = 1; setIndex <= sets; setIndex++) {
    if (remainingElapsed < workSeconds) {
      return formatClockText(workSeconds - remainingElapsed);
    }
    remainingElapsed -= workSeconds;
    if (setIndex === sets) {
      break;
    }
    if (remainingElapsed < restSeconds) {
      return formatClockText(restSeconds - remainingElapsed);
    }
    remainingElapsed -= restSeconds;
  }

  return '00:00';
}

export function getSetTimerProgress(draft: ExerciseDraft, elapsedSeconds: number): number {
  let totalSeconds = getSetTimerTotalSeconds(draft);
  if (totalSeconds <= 0) {
    return 0;
  }
  if (elapsedSeconds <= 0) {
    return 0;
  }
  if (elapsedSeconds >= totalSeconds) {
    return 1;
  }
  return elapsedSeconds / totalSeconds;
}

export function getProfileTagline(profile: UserProfile): string {
  let nickname = profile.nickname.trim();
  if (nickname.length > 0) {
    return `${nickname} 的运动资料`;
  }
  return '补充资料后，运动页会自动联动计算。';
}

function encodePersistedText(value: string): string {
  return encodeURIComponent(value);
}

function decodePersistedText(value: string): string {
  if (value.length === 0) {
    return '';
  }
  return decodeURIComponent(value);
}

export function serializeExerciseDraft(draft: ExerciseDraft): string {
  let fields: string[] = [
    draft.exerciseId,
    draft.customName,
    draft.customMode,
    draft.customIntensity,
    draft.durationMinutes,
    draft.distanceKm,
    draft.paceMinutes,
    draft.speedKmH,
    draft.count,
    draft.cadencePerMinute,
    draft.sets,
    draft.workSeconds,
    draft.restSeconds
  ];
  let encodedFields: string[] = [];
  for (let index = 0; index < fields.length; index++) {
    encodedFields.push(encodePersistedText(fields[index]));
  }
  return encodedFields.join('|');
}

export function deserializeExerciseDraft(draftText: string): ExerciseDraft {
  if (draftText.trim().length === 0) {
    return createDefaultExerciseDraft();
  }

  let fields = draftText.split('|');
  if (fields.length < 13) {
    return createDefaultExerciseDraft();
  }

  return {
    exerciseId: decodePersistedText(fields[0]),
    customName: decodePersistedText(fields[1]),
    customMode: decodePersistedText(fields[2]),
    customIntensity: decodePersistedText(fields[3]),
    durationMinutes: decodePersistedText(fields[4]),
    distanceKm: decodePersistedText(fields[5]),
    paceMinutes: decodePersistedText(fields[6]),
    speedKmH: decodePersistedText(fields[7]),
    count: decodePersistedText(fields[8]),
    cadencePerMinute: decodePersistedText(fields[9]),
    sets: decodePersistedText(fields[10]),
    workSeconds: decodePersistedText(fields[11]),
    restSeconds: decodePersistedText(fields[12])
  };
}

export function serializeUserProfile(profile: UserProfile): string {
  let fields: string[] = [
    profile.nickname,
    profile.heightCm,
    profile.weightKg,
    profile.age,
    profile.gender
  ];
  let encodedFields: string[] = [];
  for (let index = 0; index < fields.length; index++) {
    encodedFields.push(encodePersistedText(fields[index]));
  }
  return encodedFields.join('|');
}

export function deserializeUserProfile(profileText: string): UserProfile {
  if (profileText.trim().length === 0) {
    return createEmptyUserProfile();
  }

  let fields = profileText.split('|');
  if (fields.length < 5) {
    return createEmptyUserProfile();
  }

  return {
    nickname: decodePersistedText(fields[0]),
    heightCm: decodePersistedText(fields[1]),
    weightKg: decodePersistedText(fields[2]),
    age: decodePersistedText(fields[3]),
    gender: decodePersistedText(fields[4])
  };
}

export function createSavedCustomWorkoutFromDraft(draft: ExerciseDraft): SavedCustomWorkout {
  return {
    id: `${Date.now()}`,
    name: draft.customName.trim(),
    mode: draft.customMode,
    intensity: draft.customIntensity,
    durationMinutes: draft.durationMinutes,
    distanceKm: draft.distanceKm,
    paceMinutes: draft.paceMinutes,
    speedKmH: draft.speedKmH,
    count: draft.count,
    cadencePerMinute: draft.cadencePerMinute,
    sets: draft.sets,
    workSeconds: draft.workSeconds,
    restSeconds: draft.restSeconds
  };
}

export function createDraftFromSavedCustomWorkout(savedWorkout: SavedCustomWorkout): ExerciseDraft {
  return {
    exerciseId: 'custom',
    customName: savedWorkout.name,
    customMode: savedWorkout.mode,
    customIntensity: savedWorkout.intensity,
    durationMinutes: savedWorkout.durationMinutes,
    distanceKm: savedWorkout.distanceKm,
    paceMinutes: savedWorkout.paceMinutes,
    speedKmH: savedWorkout.speedKmH,
    count: savedWorkout.count,
    cadencePerMinute: savedWorkout.cadencePerMinute,
    sets: savedWorkout.sets,
    workSeconds: savedWorkout.workSeconds,
    restSeconds: savedWorkout.restSeconds
  };
}

export function getSavedCustomWorkoutSummary(savedWorkout: SavedCustomWorkout): string {
  let draft = createDraftFromSavedCustomWorkout(savedWorkout);
  let durationMinutes = getWorkoutDurationMinutes(draft);
  let modeLabel = getWorkoutModeLabel(savedWorkout.mode);
  let intensityLabel = getCustomIntensityLabel(savedWorkout.intensity);
  if (durationMinutes > 0) {
    return `${modeLabel} · ${intensityLabel} · ${formatDurationText(durationMinutes)}`;
  }
  return `${modeLabel} · ${intensityLabel}`;
}

export function serializeSavedCustomWorkouts(savedWorkouts: SavedCustomWorkout[]): string {
  let lines: string[] = [];
  for (let index = 0; index < savedWorkouts.length; index++) {
    let currentWorkout = savedWorkouts[index];
    let currentFields: string[] = [
      currentWorkout.id,
      currentWorkout.name,
      currentWorkout.mode,
      currentWorkout.intensity,
      currentWorkout.durationMinutes,
      currentWorkout.distanceKm,
      currentWorkout.paceMinutes,
      currentWorkout.speedKmH,
      currentWorkout.count,
      currentWorkout.cadencePerMinute,
      currentWorkout.sets,
      currentWorkout.workSeconds,
      currentWorkout.restSeconds
    ];
    let encodedFields: string[] = [];
    for (let fieldIndex = 0; fieldIndex < currentFields.length; fieldIndex++) {
      encodedFields.push(encodePersistedText(currentFields[fieldIndex]));
    }
    lines.push(encodedFields.join('|'));
  }
  return lines.join('\n');
}

export function deserializeSavedCustomWorkouts(savedText: string): SavedCustomWorkout[] {
  let result: SavedCustomWorkout[] = [];
  if (savedText.trim().length === 0) {
    return result;
  }

  let lines = savedText.split('\n');
  for (let index = 0; index < lines.length; index++) {
    let currentLine = lines[index].trim();
    if (currentLine.length === 0) {
      continue;
    }

    let fields = currentLine.split('|');
    if (fields.length < 13) {
      continue;
    }

    result.push({
      id: decodePersistedText(fields[0]),
      name: decodePersistedText(fields[1]),
      mode: decodePersistedText(fields[2]),
      intensity: decodePersistedText(fields[3]),
      durationMinutes: decodePersistedText(fields[4]),
      distanceKm: decodePersistedText(fields[5]),
      paceMinutes: decodePersistedText(fields[6]),
      speedKmH: decodePersistedText(fields[7]),
      count: decodePersistedText(fields[8]),
      cadencePerMinute: decodePersistedText(fields[9]),
      sets: decodePersistedText(fields[10]),
      workSeconds: decodePersistedText(fields[11]),
      restSeconds: decodePersistedText(fields[12])
    });
  }

  return result;
}

export function serializeWorkoutRecords(records: WorkoutRecord[]): string {
  let lines: string[] = [];
  for (let index = 0; index < records.length; index++) {
    let record = records[index];
    let fields: string[] = [
      record.id,
      record.date,
      record.name,
      `${record.calories}`,
      `${record.durationSeconds}`
    ];
    let encodedFields: string[] = [];
    for (let fieldIndex = 0; fieldIndex < fields.length; fieldIndex++) {
      encodedFields.push(encodePersistedText(fields[fieldIndex]));
    }
    lines.push(encodedFields.join('|'));
  }
  return lines.join('\n');
}

export function deserializeWorkoutRecords(savedText: string): WorkoutRecord[] {
  let result: WorkoutRecord[] = [];
  if (savedText.trim().length === 0) {
    return result;
  }

  let lines = savedText.split('\n');
  for (let index = 0; index < lines.length; index++) {
    let currentLine = lines[index].trim();
    if (currentLine.length === 0) {
      continue;
    }
    let fields = currentLine.split('|');
    if (fields.length < 5) {
      continue;
    }

    let caloriesValue = Number(decodePersistedText(fields[3]));
    if (isNaN(caloriesValue)) {
      caloriesValue = 0;
    }
    let durationSecondsValue = Number(decodePersistedText(fields[4]));
    if (isNaN(durationSecondsValue)) {
      durationSecondsValue = 0;
    }

    result.push({
      id: decodePersistedText(fields[0]),
      date: decodePersistedText(fields[1]),
      name: decodePersistedText(fields[2]),
      calories: caloriesValue,
      durationSeconds: durationSecondsValue
    });
  }

  return result;
}
