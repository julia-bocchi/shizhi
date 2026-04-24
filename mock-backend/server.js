const fs = require('fs');
const path = require('path');
const http = require('http');
const { URL } = require('url');

const PORT = Number(process.env.MOCK_BACKEND_PORT || 3000);
const DATA_FILE = path.join(__dirname, 'data.json');
const LOG_FILE = path.join(__dirname, 'server.log');

const PRESET_FOOD_OPTIONS = [
  {
    id: 'preset-oatmeal',
    source: 'preset',
    name: '燕麦牛奶杯',
    description: '适合早餐或训练前补充碳水，饱腹感稳定。',
    calories: 280,
    serving: '1 杯',
    mealSuggestion: '早餐',
    image: '',
    accentColor: '#D86C3D'
  },
  {
    id: 'preset-chicken-salad',
    source: 'preset',
    name: '鸡胸肉沙拉',
    description: '高蛋白、轻负担，适合作为午餐或减脂晚餐。',
    calories: 320,
    serving: '1 份',
    mealSuggestion: '午餐',
    image: '',
    accentColor: '#10B981'
  },
  {
    id: 'preset-salmon',
    source: 'preset',
    name: '香煎三文鱼',
    description: '补充优质脂肪和蛋白质，适合主餐搭配。',
    calories: 410,
    serving: '180 g',
    mealSuggestion: '晚餐',
    image: '',
    accentColor: '#0F6BFF'
  }
];

const PRESET_WORKOUT_TYPES = [
  { id: 'hiit', source: 'preset', exerciseId: 'hiit', savedWorkoutId: '', name: 'HIIT 间歇', description: '按组训练，适合燃脂和爆发力练习。', mode: 'set_timer', intensity: '', accentColor: '#FF6B57' },
  { id: 'running', source: 'preset', exerciseId: 'running', savedWorkoutId: '', name: '跑步', description: '根据配速和路程估算总时长与热量。', mode: 'distance_pace', intensity: '', accentColor: '#0F6BFF' },
  { id: 'cycling', source: 'preset', exerciseId: 'cycling', savedWorkoutId: '', name: '骑行', description: '根据均速和路程估算本次运动时长。', mode: 'distance_speed', intensity: '', accentColor: '#10B981' },
  { id: 'jump_rope', source: 'preset', exerciseId: 'jump_rope', savedWorkoutId: '', name: '跳绳', description: '根据总个数和频率估算训练时长。', mode: 'count_rate', intensity: '', accentColor: '#FF4FA3' },
  { id: 'yoga', source: 'preset', exerciseId: 'yoga', savedWorkoutId: '', name: '瑜伽', description: '按持续时长估算消耗，适合拉伸和放松。', mode: 'duration', intensity: '', accentColor: '#7B61FF' },
  { id: 'strength', source: 'preset', exerciseId: 'strength', savedWorkoutId: '', name: '力量循环', description: '适合自重或器械训练，支持按组计时。', mode: 'set_timer', intensity: '', accentColor: '#14B8A6' }
];

function loadStore() {
  return JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
}

function saveStore(store) {
  fs.writeFileSync(DATA_FILE, JSON.stringify(store, null, 2) + '\n', 'utf8');
}

function maskSensitiveValue(value) {
  if (!value) {
    return '';
  }
  const text = `${value}`;
  if (text.length <= 12) {
    return '***';
  }
  return `${text.slice(0, 6)}...${text.slice(-4)}`;
}

function stringifyForLog(value) {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  return JSON.stringify(value);
}

function buildRequestLogHeaders(headers) {
  return {
    authorization: headers.authorization ? maskSensitiveValue(headers.authorization) : '',
    xUserId: headers['x-user-id'] || '',
    contentType: headers['content-type'] || ''
  };
}

function writeLog(message, payload) {
  const suffix = payload === undefined ? '' :
    ` ${typeof payload === 'string' ? payload : JSON.stringify(payload)}`;
  const line = `${message}${suffix}`;
  console.log(line);
  try {
    fs.appendFileSync(LOG_FILE, `${new Date().toISOString()} ${line}\n`, 'utf8');
  } catch (error) {
    console.error('[mock-backend][log-file-error]', `${error}`);
  }
}

function buildUserStoreCounts(user) {
  return {
    weightRecordCount: Array.isArray(user.weightRecords) ? user.weightRecords.length : 0,
    customFoodOptionCount: Array.isArray(user.customFoodOptions) ? user.customFoodOptions.length : 0,
    foodPlanCount: Array.isArray(user.foodPlans) ? user.foodPlans.length : 0,
    workoutTemplateCount: Array.isArray(user.workoutTemplates) ? user.workoutTemplates.length : 0,
    workoutPlanCount: Array.isArray(user.workoutPlans) ? user.workoutPlans.length : 0,
    workoutRecordCount: Array.isArray(user.workoutRecords) ? user.workoutRecords.length : 0
  };
}

function logSyncCache(moduleName, user, payload, persisted) {
  writeLog('[mock-backend][sync-cache]', {
    module: moduleName,
    userId: user && user.userId ? user.userId : '',
    username: user && user.username ? user.username : '',
    payload,
    persisted,
    storeCounts: user ? buildUserStoreCounts(user) : {}
  });
}

function getActionLabel(type) {
  if (type === 'query-food-plans') {
    return '查询饮食计划';
  }
  if (type === 'query-workout-plans') {
    return '查询训练计划';
  }
  if (type === 'auto-create-food-option') {
    return '自动补建食物';
  }
  if (type === 'save-food-plan') {
    return '保存饮食计划';
  }
  if (type === 'auto-create-workout-template') {
    return '自动补建运动模板';
  }
  if (type === 'save-workout-plan') {
    return '保存训练计划';
  }
  return type;
}

function buildActionSummary(type, details = {}) {
  if (type === 'query-food-plans') {
    return `${details.dateRangeText || '查询饮食计划'}，共 ${Number(details.planCount || 0)} 条`;
  }
  if (type === 'query-workout-plans') {
    return `${details.dateRangeText || '查询训练计划'}，共 ${Number(details.planCount || 0)} 条`;
  }
  if (type === 'auto-create-food-option') {
    const mealText = details.mealSuggestion ? `${details.mealSuggestion}用` : '';
    const calorieText = Number.isFinite(Number(details.calories)) && Number(details.calories) > 0 ?
      `，${Number(details.calories)} kcal` : '';
    const servingText = details.serving ? `，${details.serving}` : '';
    return `${mealText}食物 ${details.foodName || details.foodId || ''}${calorieText}${servingText}`;
  }
  if (type === 'save-food-plan') {
    const mealText = details.mealTypeLabel || details.mealType || '未分类';
    const noteText = details.notes ? `，备注：${details.notes}` : '';
    return `${details.date || ''} ${mealText} ${details.foodName || details.foodId || ''}${noteText}`;
  }
  if (type === 'auto-create-workout-template') {
    const triggerText = details.trigger === 'savedWorkoutId_missing' ? '因模板不存在自动补建' :
      details.trigger === 'exerciseId_missing' ? '因运动类型不存在自动补建' : '自动补建';
    const modeText = details.mode ? `，模式：${details.mode}` : '';
    const intensityText = details.intensity ? `，强度：${details.intensity}` : '';
    return `${triggerText} ${details.templateName || details.templateId || ''}${modeText}${intensityText}`;
  }
  if (type === 'save-workout-plan') {
    const summaryText = details.planSummary || details.summary ? `，${details.planSummary || details.summary}` : '';
    const templateText = details.savedWorkoutId ? `，模板：${details.savedWorkoutId}` : '';
    return `${details.date || ''} ${details.title || '训练计划'}${summaryText}${templateText}`;
  }
  return JSON.stringify(details);
}

function pushRequestAction(res, type, details = {}) {
  const requestContext = res && res.__requestContext ? res.__requestContext : null;
  if (!requestContext) {
    return;
  }
  if (!Array.isArray(requestContext.actions)) {
    requestContext.actions = [];
  }
  const action = {
    type,
    label: getActionLabel(type),
    ...details
  };
  action.summary = buildActionSummary(type, action);
  requestContext.actions.push(action);
  writeLog('[mock-backend][action]', {
    method: requestContext.method,
    url: requestContext.url,
    ...action
  });
}

function getMealSuggestionLabel(mealType) {
  const normalized = `${mealType || ''}`.trim();
  if (normalized === 'breakfast') {
    return '早餐';
  }
  if (normalized === 'lunch') {
    return '午餐';
  }
  if (normalized === 'dinner') {
    return '晚餐';
  }
  if (normalized === 'snack') {
    return '加餐';
  }
  return normalized || '未分类';
}

function buildDateRangeLabel(startDate, endDate) {
  const normalizedStartDate = `${startDate || ''}`.trim();
  const normalizedEndDate = `${endDate || ''}`.trim();
  if (normalizedStartDate && normalizedEndDate) {
    if (normalizedStartDate === normalizedEndDate) {
      return `${normalizedStartDate} 的饮食计划`;
    }
    return `${normalizedStartDate} 到 ${normalizedEndDate} 的饮食计划`;
  }
  if (normalizedStartDate) {
    return `${normalizedStartDate} 之后的饮食计划`;
  }
  if (normalizedEndDate) {
    return `${normalizedEndDate} 之前的饮食计划`;
  }
  return '全部饮食计划';
}

function buildWorkoutDateRangeLabel(startDate, endDate) {
  const normalizedStartDate = `${startDate || ''}`.trim();
  const normalizedEndDate = `${endDate || ''}`.trim();
  if (normalizedStartDate && normalizedEndDate) {
    if (normalizedStartDate === normalizedEndDate) {
      return `${normalizedStartDate} 的训练计划`;
    }
    return `${normalizedStartDate} 到 ${normalizedEndDate} 的训练计划`;
  }
  if (normalizedStartDate) {
    return `${normalizedStartDate} 之后的训练计划`;
  }
  if (normalizedEndDate) {
    return `${normalizedEndDate} 之前的训练计划`;
  }
  return '全部训练计划';
}

function buildAutoCreatedFoodOption(body) {
  const requestedFoodId = `${body.foodId || ''}`.trim();
  const generatedFoodId = requestedFoodId || nextId('custom-food');
  const foodName = `${body.foodName || body.name || body.title || ''}`.trim();
  return {
    id: generatedFoodId,
    source: 'custom',
    name: foodName || `自动补建食物(${generatedFoodId})`,
    description: `${body.description || '根据计划保存请求自动补建，方便联调测试。'}`,
    calories: Number(body.calories || 0),
    serving: `${body.serving || '1 份'}`,
    mealSuggestion: `${body.mealSuggestion || getMealSuggestionLabel(body.mealType)}`,
    image: `${body.image || ''}`,
    accentColor: `${body.accentColor || '#F59E0B'}`
  };
}

function ensureFoodOptionForPlan(user, body, res) {
  const existingOption = PRESET_FOOD_OPTIONS.concat(user.customFoodOptions).find(item => item.id === body.foodId);
  if (existingOption) {
    return existingOption;
  }
  const createdOption = buildAutoCreatedFoodOption(body);
  user.customFoodOptions.unshift(createdOption);
  pushRequestAction(res, 'auto-create-food-option', {
    foodId: createdOption.id,
    foodName: createdOption.name,
    calories: createdOption.calories,
    serving: createdOption.serving,
    mealSuggestion: createdOption.mealSuggestion
  });
  return createdOption;
}

function buildAutoCreatedWorkoutTemplate(body, draft, templateId = '') {
  const normalizedTemplateId = `${templateId || body.savedWorkoutId || ''}`.trim() || nextId('template');
  const draftExerciseId = draft ? `${draft.exerciseId || ''}`.trim() : '';
  const templateName = `${body.templateName || body.workoutName || body.title || ''}`.trim();
  const draftName = draft && draft.customName ? `${draft.customName}`.trim() : '';
  return {
    id: normalizedTemplateId,
    name: templateName || draftName || (draftExerciseId && draftExerciseId !== 'custom' ? `自动补建运动(${draftExerciseId})` : '自动补建自定义运动'),
    mode: draft ? getDraftMode(draft) : `${body.mode || 'duration'}`,
    intensity: `${draft && draft.customIntensity ? draft.customIntensity : body.intensity || 'moderate'}`,
    durationMinutes: `${draft && draft.durationMinutes ? draft.durationMinutes : body.durationMinutes || '0'}`,
    distanceKm: `${draft && draft.distanceKm ? draft.distanceKm : body.distanceKm || '0'}`,
    paceMinutes: `${draft && draft.paceMinutes ? draft.paceMinutes : body.paceMinutes || '0'}`,
    speedKmH: `${draft && draft.speedKmH ? draft.speedKmH : body.speedKmH || '0'}`,
    count: `${draft && draft.count ? draft.count : body.count || '0'}`,
    cadencePerMinute: `${draft && draft.cadencePerMinute ? draft.cadencePerMinute : body.cadencePerMinute || '0'}`,
    sets: `${draft && draft.sets ? draft.sets : body.sets || '0'}`,
    workSeconds: `${draft && draft.workSeconds ? draft.workSeconds : body.workSeconds || '0'}`,
    restSeconds: `${draft && draft.restSeconds ? draft.restSeconds : body.restSeconds || '0'}`
  };
}

function ensureWorkoutTemplateForPlan(user, body, res) {
  const requestedSavedWorkoutId = `${body.savedWorkoutId || ''}`.trim();
  const draft = decodeWorkoutDraft(body.draftText || '');
  if (requestedSavedWorkoutId) {
    const existingTemplate = user.workoutTemplates.find(item => item.id === requestedSavedWorkoutId);
    if (existingTemplate) {
      return { savedWorkoutId: existingTemplate.id, autoCreatedTemplate: null };
    }
    const createdTemplate = buildAutoCreatedWorkoutTemplate(body, draft, requestedSavedWorkoutId);
    user.workoutTemplates.unshift(createdTemplate);
    pushRequestAction(res, 'auto-create-workout-template', {
      templateId: createdTemplate.id,
      templateName: createdTemplate.name,
      trigger: 'savedWorkoutId_missing',
      mode: createdTemplate.mode,
      intensity: createdTemplate.intensity
    });
    return { savedWorkoutId: createdTemplate.id, autoCreatedTemplate: createdTemplate };
  }

  if (draft && draft.exerciseId && draft.exerciseId !== 'custom') {
    const preset = PRESET_WORKOUT_TYPES.find(item => item.exerciseId === draft.exerciseId);
    if (!preset) {
      const createdTemplate = buildAutoCreatedWorkoutTemplate(body, draft);
      user.workoutTemplates.unshift(createdTemplate);
      pushRequestAction(res, 'auto-create-workout-template', {
        templateId: createdTemplate.id,
        templateName: createdTemplate.name,
        trigger: 'exerciseId_missing',
        exerciseId: draft.exerciseId,
        mode: createdTemplate.mode,
        intensity: createdTemplate.intensity
      });
      return { savedWorkoutId: createdTemplate.id, autoCreatedTemplate: createdTemplate };
    }
  }

  return { savedWorkoutId: requestedSavedWorkoutId, autoCreatedTemplate: null };
}

function sendJson(res, code, message, data, statusCode = 200) {
  const requestContext = res.__requestContext || null;
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-User-Id',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
  });
  if (requestContext) {
    writeLog('[mock-backend][response]', {
      method: requestContext.method,
      url: requestContext.url,
      statusCode,
      code,
      message,
      durationMs: Date.now() - requestContext.startAt,
      actionSummary: Array.isArray(requestContext.actions) ? requestContext.actions.map(item => item.summary) : [],
      actions: Array.isArray(requestContext.actions) ? requestContext.actions : [],
      requestBody: requestContext.request && requestContext.request.__loggedBody !== undefined ?
        requestContext.request.__loggedBody : requestContext.bodyForLog
    });
  }
  res.end(JSON.stringify({ code, message, data }));
}

function parseBody(req) {
  return new Promise((resolve, reject) => {
    let chunks = '';
    req.on('data', chunk => {
      chunks += chunk;
    });
    req.on('end', () => {
      if (!chunks) {
        req.__loggedBody = {};
        resolve({});
        return;
      }
      try {
        const parsedBody = JSON.parse(chunks);
        req.__loggedBody = parsedBody;
        resolve(parsedBody);
      } catch (error) {
        reject(error);
      }
    });
    req.on('error', reject);
  });
}

function createDefaultUser(username, password = '123456') {
  return {
    userId: `user-${username}`,
    username,
    password,
    token: `mock-token-user-${username}`,
    profile: {
      nickname: username,
      heightCm: '170',
      weightKg: '68.5',
      age: '26',
      gender: '男'
    },
    weightRecords: [],
    customFoodOptions: [],
    foodPlans: [],
    workoutTemplates: [],
    workoutPlans: [],
    workoutRecords: []
  };
}

function getUserFromRequest(store, req, urlObj) {
  const authHeader = req.headers.authorization || '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
  const headerUserId = req.headers['x-user-id'] || '';
  const queryUserId = urlObj.searchParams.get('userId') || '';
  const candidateUserId = headerUserId || queryUserId;

  for (const username of Object.keys(store.users)) {
    const user = store.users[username];
    if (token && user.token === token) {
      return user;
    }
    if (candidateUserId && user.userId === candidateUserId) {
      return user;
    }
  }
  return null;
}

function ensureUser(req, res, store, urlObj) {
  const user = getUserFromRequest(store, req, urlObj);
  if (!user) {
    sendJson(res, 401, '未登录', {}, 401);
    return null;
  }
  return user;
}

function nextId(prefix) {
  return `${prefix}-${Date.now()}-${Math.round(Math.random() * 1000)}`;
}

function sortByDateAsc(items) {
  items.sort((a, b) => `${a.date}`.localeCompare(`${b.date}`));
}

function withinRange(date, startDate, endDate) {
  if (startDate && date < startDate) {
    return false;
  }
  if (endDate && date > endDate) {
    return false;
  }
  return true;
}

function parseWeight(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function parsePositiveNumber(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
}

function trimDecimal(value) {
  const normalized = Math.round(value * 10) / 10;
  const text = normalized.toFixed(1);
  return text.endsWith('.0') ? text.slice(0, -2) : text;
}

function normalizeUniqueName(name) {
  return `${name || ''}`.trim().replace(/\s+/g, ' ').toLowerCase();
}

function buildIdentityKey(name, fallbackValue = 'item') {
  const normalizedName = normalizeUniqueName(name);
  if (!normalizedName) {
    return fallbackValue;
  }
  const slugText = normalizedName
    .replace(/\s+/g, '-')
    .replace(/[^0-9a-z\u4e00-\u9fa5-]/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-+|-+$/g, '');
  return slugText || fallbackValue;
}

function findItemByIdentity(items, identityKey, name) {
  const normalizedIdentityKey = `${identityKey || ''}`.trim();
  const normalizedName = normalizeUniqueName(name);
  return items.find(item => {
    const currentIdentityKey = `${item.identityKey || ''}`.trim();
    if (normalizedIdentityKey && currentIdentityKey === normalizedIdentityKey) {
      return true;
    }
    if (normalizedName && normalizeUniqueName(item.name) === normalizedName) {
      return true;
    }
    return false;
  });
}

function formatDurationMinutes(minutes) {
  const normalized = Math.round(parsePositiveNumber(minutes));
  if (normalized <= 0) {
    return '--';
  }
  if (normalized < 60) {
    return `${normalized} 分钟`;
  }
  const hours = Math.floor(normalized / 60);
  const remainMinutes = normalized % 60;
  return remainMinutes > 0 ? `${hours} 小时 ${remainMinutes} 分钟` : `${hours} 小时`;
}

function decodeWorkoutDraft(draftText) {
  const fields = `${draftText || ''}`.split('|');
  if (fields.length < 13) {
    return null;
  }
  return {
    exerciseId: decodeURIComponent(fields[0] || ''),
    customName: decodeURIComponent(fields[1] || ''),
    customMode: decodeURIComponent(fields[2] || ''),
    customIntensity: decodeURIComponent(fields[3] || ''),
    durationMinutes: decodeURIComponent(fields[4] || ''),
    distanceKm: decodeURIComponent(fields[5] || ''),
    paceMinutes: decodeURIComponent(fields[6] || ''),
    speedKmH: decodeURIComponent(fields[7] || ''),
    count: decodeURIComponent(fields[8] || ''),
    cadencePerMinute: decodeURIComponent(fields[9] || ''),
    sets: decodeURIComponent(fields[10] || ''),
    workSeconds: decodeURIComponent(fields[11] || ''),
    restSeconds: decodeURIComponent(fields[12] || '')
  };
}

function getUserPassword(user) {
  if (!user || user.password === undefined || user.password === null) {
    return '123456';
  }
  return `${user.password}`;
}

function getDraftExerciseName(draft) {
  const preset = PRESET_WORKOUT_TYPES.find(item => item.exerciseId === draft.exerciseId);
  if (preset) {
    return preset.name;
  }
  return draft.customName && `${draft.customName}`.trim() ? `${draft.customName}`.trim() : '自定义运动';
}

function getDraftMode(draft) {
  if (draft.exerciseId !== 'custom') {
    const preset = PRESET_WORKOUT_TYPES.find(item => item.exerciseId === draft.exerciseId);
    return preset ? preset.mode : 'duration';
  }
  return draft.customMode || 'duration';
}

function getDraftDurationMinutes(draft) {
  const mode = getDraftMode(draft);
  const distanceKm = parsePositiveNumber(draft.distanceKm);
  const paceMinutes = parsePositiveNumber(draft.paceMinutes);
  const speedKmH = parsePositiveNumber(draft.speedKmH);
  const count = parsePositiveNumber(draft.count);
  const cadencePerMinute = parsePositiveNumber(draft.cadencePerMinute);
  const sets = parsePositiveNumber(draft.sets);
  const workSeconds = parsePositiveNumber(draft.workSeconds);
  const restSeconds = parsePositiveNumber(draft.restSeconds);

  if (mode === 'duration') {
    return parsePositiveNumber(draft.durationMinutes);
  }
  if (mode === 'distance_pace') {
    return distanceKm > 0 && paceMinutes > 0 ? distanceKm * paceMinutes : 0;
  }
  if (mode === 'distance_speed') {
    return distanceKm > 0 && speedKmH > 0 ? distanceKm / speedKmH * 60 : 0;
  }
  if (mode === 'count_rate') {
    return count > 0 && cadencePerMinute > 0 ? count / cadencePerMinute : 0;
  }
  if (mode === 'set_timer') {
    return sets > 0 && workSeconds > 0 ? (sets * workSeconds + Math.max(0, sets - 1) * restSeconds) / 60 : 0;
  }
  return 0;
}

function summarizeWeights(records, days) {
  const sorted = records.slice();
  sortByDateAsc(sorted);
  const recent = days > 0 ? sorted.slice(Math.max(0, sorted.length - days)) : sorted;
  const latestRecord = sorted.length > 0 ? sorted[sorted.length - 1] : null;
  const previousRecord = sorted.length > 1 ? sorted[sorted.length - 2] : null;
  const averageWeight = recent.length > 0 ? recent.reduce((sum, item) => sum + parseWeight(item.weight), 0) / recent.length : 0;
  const changeInRange = recent.length > 1 ? parseWeight(recent[recent.length - 1].weight) - parseWeight(recent[0].weight) : 0;
  const changeFromPrevious = latestRecord && previousRecord ? parseWeight(latestRecord.weight) - parseWeight(previousRecord.weight) : 0;
  return {
    latestRecord,
    previousRecord,
    recentCount: recent.length,
    averageWeight,
    changeInRange,
    changeFromPrevious
  };
}

function pickAccentColorFromDraft(draftText) {
  const decoded = decodeURIComponent(draftText || '');
  if (decoded.startsWith('running')) {
    return '#0F6BFF';
  }
  if (decoded.startsWith('cycling')) {
    return '#10B981';
  }
  if (decoded.startsWith('jump_rope')) {
    return '#FF4FA3';
  }
  if (decoded.startsWith('yoga')) {
    return '#7B61FF';
  }
  if (decoded.startsWith('strength')) {
    return '#14B8A6';
  }
  return '#FF7A59';
}

function buildWorkoutSummary(item) {
  if (item.summary && `${item.summary}`.trim()) {
    return item.summary;
  }
  const draft = decodeWorkoutDraft(item.draftText || '');
  if (!draft) {
    return '已保存训练计划';
  }
  const mode = getDraftMode(draft);
  const durationMinutes = getDraftDurationMinutes(draft);
  if (mode === 'set_timer') {
    const sets = parsePositiveNumber(draft.sets);
    const workSeconds = parsePositiveNumber(draft.workSeconds);
    const restSeconds = parsePositiveNumber(draft.restSeconds);
    if (sets > 0 && workSeconds > 0) {
      return `${Math.round(sets)} 组训练，每组 ${Math.round(workSeconds)} 秒，组间休息 ${Math.round(restSeconds)} 秒，总时长约 ${formatDurationMinutes(durationMinutes)}。`;
    }
  }
  if (mode === 'distance_pace') {
    const distanceKm = parsePositiveNumber(draft.distanceKm);
    const paceMinutes = parsePositiveNumber(draft.paceMinutes);
    if (distanceKm > 0 && paceMinutes > 0) {
      return `${getDraftExerciseName(draft)} ${trimDecimal(distanceKm)} km，配速 ${trimDecimal(paceMinutes)} 分/km，预计用时 ${formatDurationMinutes(durationMinutes)}。`;
    }
  }
  if (mode === 'distance_speed') {
    const distanceKm = parsePositiveNumber(draft.distanceKm);
    const speedKmH = parsePositiveNumber(draft.speedKmH);
    if (distanceKm > 0 && speedKmH > 0) {
      return `${getDraftExerciseName(draft)} ${trimDecimal(distanceKm)} km，均速 ${trimDecimal(speedKmH)} km/h，预计用时 ${formatDurationMinutes(durationMinutes)}。`;
    }
  }
  if (mode === 'count_rate') {
    const count = parsePositiveNumber(draft.count);
    const cadencePerMinute = parsePositiveNumber(draft.cadencePerMinute);
    if (count > 0 && cadencePerMinute > 0) {
      return `${getDraftExerciseName(draft)} 共 ${Math.round(count)} 次，节奏 ${Math.round(cadencePerMinute)} 次/分，预计用时 ${formatDurationMinutes(durationMinutes)}。`;
    }
  }
  if (mode === 'duration') {
    if (durationMinutes > 0) {
      return `${getDraftExerciseName(draft)} 持续 ${formatDurationMinutes(durationMinutes)}。`;
    }
  }
  return '已保存训练计划';
}

const server = http.createServer(async (req, res) => {
  if (!req.url) {
    sendJson(res, 404, 'Not Found', {}, 404);
    return;
  }

  const urlObj = new URL(req.url, `http://127.0.0.1:${PORT}`);
  const pathname = urlObj.pathname;
  res.__requestContext = {
    method: req.method || 'GET',
    url: `${pathname}${urlObj.search}`,
    startAt: Date.now(),
    bodyForLog: {},
    headers: buildRequestLogHeaders(req.headers),
    actions: [],
    request: req
  };
  writeLog('[mock-backend][request]', {
    method: res.__requestContext.method,
    url: res.__requestContext.url,
    headers: res.__requestContext.headers
  });

  if (req.method === 'OPTIONS') {
    sendJson(res, 0, 'ok', {});
    return;
  }
  const store = loadStore();

  try {
    if (pathname === '/api/v1/auth/login' && req.method === 'POST') {
      const body = await parseBody(req);
      const username = `${body.username || ''}`.trim();
      const password = `${body.password || ''}`;
      if (!username || !password) {
        sendJson(res, 400, '账号和密码不能为空', {}, 400);
        return;
      }
      const user = store.users[username];
      if (!user) {
        sendJson(res, 404, '用户不存在，请先注册', {}, 404);
        return;
      }
      if (getUserPassword(user) !== password) {
        sendJson(res, 401, '账号或密码错误', {}, 401);
        return;
      }
      user.token = `mock-token-${user.userId}`;
      saveStore(store);
      sendJson(res, 0, 'ok', {
        userId: user.userId,
        username,
        token: user.token
      });
      return;
    }

    if (pathname === '/api/v1/auth/register' && req.method === 'POST') {
      const body = await parseBody(req);
      const username = `${body.username || ''}`.trim();
      const password = `${body.password || ''}`;
      if (!username || !password) {
        sendJson(res, 400, '账号和密码不能为空', {}, 400);
        return;
      }
      if (store.users[username]) {
        sendJson(res, 409, '用户已存在，请直接登录', {}, 409);
        return;
      }
      store.users[username] = createDefaultUser(username, password);
      store.users[username].token = `mock-token-${store.users[username].userId}`;
      saveStore(store);
      sendJson(res, 0, 'ok', {
        userId: store.users[username].userId,
        username,
        token: store.users[username].token
      });
      return;
    }

    if (pathname === '/api/v1/ai-assistant/chat') {
      sendJson(res, 501, 'mock backend 未实现 AI 接口', {}, 501);
      return;
    }

    const user = ensureUser(req, res, store, urlObj);
    if (!user) {
      return;
    }

    if (pathname === '/api/v1/user-profile' && req.method === 'GET') {
      sendJson(res, 0, 'ok', user.profile);
      return;
    }
    if (pathname === '/api/v1/user-profile' && req.method === 'PUT') {
      const body = await parseBody(req);
      user.profile = {
        nickname: `${body.nickname || ''}`,
        heightCm: `${body.heightCm || ''}`,
        weightKg: `${body.weightKg || ''}`,
        age: `${body.age || ''}`,
        gender: `${body.gender || '未填写'}`
      };
      saveStore(store);
      logSyncCache('user-profile:put', user, body, user.profile);
      sendJson(res, 0, 'ok', user.profile);
      return;
    }

    if (pathname === '/api/v1/weight-records' && req.method === 'GET') {
      const startDate = urlObj.searchParams.get('startDate') || '';
      const endDate = urlObj.searchParams.get('endDate') || '';
      const items = user.weightRecords.filter(item => withinRange(item.date, startDate, endDate));
      sortByDateAsc(items);
      sendJson(res, 0, 'ok', items);
      return;
    }
    if (pathname === '/api/v1/weight-records/summary' && req.method === 'GET') {
      const days = Number(urlObj.searchParams.get('days') || '7');
      sendJson(res, 0, 'ok', summarizeWeights(user.weightRecords, days));
      return;
    }
    if (pathname.startsWith('/api/v1/weight-records/') && req.method === 'PUT') {
      const date = decodeURIComponent(pathname.split('/').pop());
      const body = await parseBody(req);
      const weight = parseWeight(body.weight);
      let target = user.weightRecords.find(item => item.date === date);
      let isUpdated = true;
      if (!target) {
        target = { id: nextId('weight'), date, weight };
        user.weightRecords.push(target);
        isUpdated = false;
      } else {
        target.weight = weight;
      }
      sortByDateAsc(user.weightRecords);
      saveStore(store);
      logSyncCache('weight-record:put', user, { date, ...body }, { ...target, isUpdated });
      sendJson(res, 0, 'ok', { ...target, isUpdated });
      return;
    }

    if (pathname === '/api/v1/food-options' && req.method === 'GET') {
      sendJson(res, 0, 'ok', { items: PRESET_FOOD_OPTIONS.concat(user.customFoodOptions) });
      return;
    }
    if (pathname === '/api/v1/food-options/custom' && req.method === 'POST') {
      const body = await parseBody(req);
      const identityKey = `${body.identityKey || ''}`.trim() || buildIdentityKey(body.name, 'custom-food');
      const existingItem = findItemByIdentity(user.customFoodOptions, identityKey, body.name);
      if (existingItem) {
        Object.assign(existingItem, {
          identityKey,
          source: 'custom',
          name: `${body.name || existingItem.name || ''}`,
          description: `${body.description || ''}`,
          calories: Number(body.calories || 0),
          serving: `${body.serving || ''}`,
          mealSuggestion: `${body.mealSuggestion || ''}`,
          image: `${body.image || ''}`,
          accentColor: `${body.accentColor || '#10B981'}`
        });
        saveStore(store);
        logSyncCache('food-option:post-upsert', user, body, existingItem);
        sendJson(res, 0, 'ok', existingItem);
        return;
      }
      const item = {
        id: nextId('custom-food'),
        identityKey,
        source: 'custom',
        name: `${body.name || ''}`,
        description: `${body.description || ''}`,
        calories: Number(body.calories || 0),
        serving: `${body.serving || ''}`,
        mealSuggestion: `${body.mealSuggestion || ''}`,
        image: `${body.image || ''}`,
        accentColor: `${body.accentColor || '#10B981'}`
      };
      user.customFoodOptions.unshift(item);
      saveStore(store);
      logSyncCache('food-option:post', user, body, item);
      sendJson(res, 0, 'ok', item);
      return;
    }
    if (pathname.startsWith('/api/v1/food-options/custom/') && req.method === 'PUT') {
      const foodId = decodeURIComponent(pathname.split('/').pop());
      const body = await parseBody(req);
      const target = user.customFoodOptions.find(item => item.id === foodId);
      if (!target) {
        sendJson(res, 404, '食物不存在', {}, 404);
        return;
      }
      Object.assign(target, body);
      saveStore(store);
      logSyncCache('food-option:put', user, { foodId, ...body }, target);
      sendJson(res, 0, 'ok', target);
      return;
    }
    if (pathname.startsWith('/api/v1/food-options/custom/') && req.method === 'DELETE') {
      const foodId = decodeURIComponent(pathname.split('/').pop());
      user.customFoodOptions = user.customFoodOptions.filter(item => item.id !== foodId);
      saveStore(store);
      logSyncCache('food-option:delete', user, { foodId }, { deletedId: foodId });
      sendJson(res, 0, 'ok', {});
      return;
    }

    if (pathname === '/api/v1/food-plans' && req.method === 'GET') {
      const startDate = urlObj.searchParams.get('startDate') || '';
      const endDate = urlObj.searchParams.get('endDate') || '';
      const plans = user.foodPlans.filter(item => withinRange(item.date, startDate, endDate));
      sortByDateAsc(plans);
      pushRequestAction(res, 'query-food-plans', {
        dateRangeText: buildDateRangeLabel(startDate, endDate),
        planCount: plans.length
      });
      sendJson(res, 0, 'ok', { plans });
      return;
    }
    if (pathname === '/api/v1/food-plans' && req.method === 'POST') {
      const body = await parseBody(req);
      const sourceOption = ensureFoodOptionForPlan(user, body, res);
      const plan = {
        id: nextId('food-plan'),
        date: `${body.date || ''}`,
        foodId: sourceOption.id,
        name: sourceOption.name,
        description: sourceOption.description,
        calories: sourceOption.calories,
        serving: sourceOption.serving,
        mealType: `${body.mealType || 'breakfast'}`,
        image: sourceOption.image || '',
        notes: `${body.notes || ''}`,
        accentColor: sourceOption.accentColor
      };
      user.foodPlans.push(plan);
      pushRequestAction(res, 'save-food-plan', {
        planId: plan.id,
        foodId: plan.foodId,
        foodName: plan.name,
        date: plan.date,
        mealType: plan.mealType,
        mealTypeLabel: getMealSuggestionLabel(plan.mealType),
        calories: plan.calories,
        serving: plan.serving,
        notes: plan.notes
      });
      saveStore(store);
      logSyncCache('food-plan:post', user, body, plan);
      sendJson(res, 0, 'ok', plan);
      return;
    }
    if (pathname.startsWith('/api/v1/food-plans/') && req.method === 'PUT') {
      const planId = decodeURIComponent(pathname.split('/').pop());
      const body = await parseBody(req);
      const target = user.foodPlans.find(item => item.id === planId);
      if (!target) {
        sendJson(res, 404, '饮食计划不存在', {}, 404);
        return;
      }
      if (body.mealType !== undefined) {
        target.mealType = `${body.mealType || target.mealType}`;
      }
      if (body.notes !== undefined) {
        target.notes = `${body.notes || ''}`;
      }
      saveStore(store);
      logSyncCache('food-plan:put', user, { planId, ...body }, target);
      sendJson(res, 0, 'ok', target);
      return;
    }
    if (pathname.startsWith('/api/v1/food-plans/') && req.method === 'DELETE') {
      const planId = decodeURIComponent(pathname.split('/').pop());
      user.foodPlans = user.foodPlans.filter(item => item.id !== planId);
      saveStore(store);
      logSyncCache('food-plan:delete', user, { planId }, { deletedId: planId });
      sendJson(res, 0, 'ok', {});
      return;
    }

    if (pathname === '/api/v1/workout-types' && req.method === 'GET') {
      const items = PRESET_WORKOUT_TYPES.concat(user.workoutTemplates.map(item => ({
        id: item.id,
        source: 'saved_template',
        exerciseId: 'custom',
        savedWorkoutId: item.id,
        name: item.name,
        description: '自定义模板',
        mode: item.mode,
        intensity: item.intensity,
        accentColor: '#7B61FF'
      })));
      sendJson(res, 0, 'ok', { items });
      return;
    }
    if (pathname === '/api/v1/workout-templates' && req.method === 'GET') {
      sendJson(res, 0, 'ok', { items: user.workoutTemplates });
      return;
    }
    if (pathname === '/api/v1/workout-templates' && req.method === 'POST') {
      const body = await parseBody(req);
      const identityKey = `${body.identityKey || ''}`.trim() || buildIdentityKey(body.name, 'custom-workout');
      const existingTemplate = findItemByIdentity(user.workoutTemplates, identityKey, body.name);
      if (existingTemplate) {
        Object.assign(existingTemplate, { identityKey, ...body });
        saveStore(store);
        logSyncCache('workout-template:post-upsert', user, body, existingTemplate);
        sendJson(res, 0, 'ok', existingTemplate);
        return;
      }
      const template = { id: nextId('template'), identityKey, ...body };
      user.workoutTemplates.unshift(template);
      saveStore(store);
      logSyncCache('workout-template:post', user, body, template);
      sendJson(res, 0, 'ok', template);
      return;
    }
    if (pathname.startsWith('/api/v1/workout-templates/') && req.method === 'PUT') {
      const templateId = decodeURIComponent(pathname.split('/').pop());
      const body = await parseBody(req);
      const template = user.workoutTemplates.find(item => item.id === templateId);
      if (!template) {
        sendJson(res, 404, '模板不存在', {}, 404);
        return;
      }
      Object.assign(template, body);
      saveStore(store);
      logSyncCache('workout-template:put', user, { templateId, ...body }, template);
      sendJson(res, 0, 'ok', template);
      return;
    }
    if (pathname.startsWith('/api/v1/workout-templates/') && req.method === 'DELETE') {
      const templateId = decodeURIComponent(pathname.split('/').pop());
      user.workoutTemplates = user.workoutTemplates.filter(item => item.id !== templateId);
      saveStore(store);
      logSyncCache('workout-template:delete', user, { templateId }, { deletedId: templateId });
      sendJson(res, 0, 'ok', {});
      return;
    }

    if (pathname === '/api/v1/workout-plans' && req.method === 'GET') {
      const startDate = urlObj.searchParams.get('startDate') || '';
      const endDate = urlObj.searchParams.get('endDate') || '';
      const plans = user.workoutPlans.filter(item => withinRange(item.date, startDate, endDate));
      sortByDateAsc(plans);
      pushRequestAction(res, 'query-workout-plans', {
        dateRangeText: buildWorkoutDateRangeLabel(startDate, endDate),
        planCount: plans.length
      });
      sendJson(res, 0, 'ok', { plans });
      return;
    }
    if (pathname === '/api/v1/workout-plans' && req.method === 'POST') {
      const body = await parseBody(req);
      const ensuredWorkout = ensureWorkoutTemplateForPlan(user, body, res);
      const plan = {
        id: nextId('plan'),
        date: `${body.date || ''}`,
        title: `${body.title || '训练计划'}`,
        summary: buildWorkoutSummary(body),
        notes: `${body.notes || ''}`,
        draftText: `${body.draftText || ''}`,
        savedWorkoutId: ensuredWorkout.savedWorkoutId,
        accentColor: pickAccentColorFromDraft(`${body.draftText || ''}`)
      };
      user.workoutPlans.unshift(plan);
      pushRequestAction(res, 'save-workout-plan', {
        planId: plan.id,
        title: plan.title,
        date: plan.date,
        planSummary: plan.summary,
        savedWorkoutId: plan.savedWorkoutId
      });
      saveStore(store);
      logSyncCache('workout-plan:post', user, body, plan);
      sendJson(res, 0, 'ok', plan);
      return;
    }
    if (pathname.startsWith('/api/v1/workout-plans/') && req.method === 'DELETE') {
      const planId = decodeURIComponent(pathname.split('/').pop());
      user.workoutPlans = user.workoutPlans.filter(item => item.id !== planId);
      saveStore(store);
      logSyncCache('workout-plan:delete', user, { planId }, { deletedId: planId });
      sendJson(res, 0, 'ok', {});
      return;
    }

    if (pathname === '/api/v1/workout-records' && req.method === 'GET') {
      const startDate = urlObj.searchParams.get('startDate') || '';
      const endDate = urlObj.searchParams.get('endDate') || '';
      const items = user.workoutRecords.filter(item => withinRange(item.date, startDate, endDate));
      sortByDateAsc(items);
      sendJson(res, 0, 'ok', { items });
      return;
    }
    if (pathname === '/api/v1/workout-records' && req.method === 'POST') {
      const body = await parseBody(req);
      const record = {
        id: nextId('record'),
        date: `${body.date || ''}`,
        name: `${body.name || ''}`,
        calories: Number(body.calories || 0),
        durationSeconds: Number(body.durationSeconds || 0),
        exerciseId: `${body.exerciseId || ''}`,
        planId: `${body.planId || ''}`,
        distanceKm: Number(body.distanceKm || 0),
        count: Number(body.count || 0),
        configSnapshot: body.configSnapshot || {}
      };
      user.workoutRecords.unshift(record);
      saveStore(store);
      logSyncCache('workout-record:post', user, body, record);
      sendJson(res, 0, 'ok', record);
      return;
    }
    if (pathname === '/api/v1/workout-records/daily-summary' && req.method === 'GET') {
      const date = urlObj.searchParams.get('date') || '';
      const records = user.workoutRecords.filter(item => item.date === date);
      sendJson(res, 0, 'ok', {
        date,
        workoutCount: records.length,
        totalCalories: records.reduce((sum, item) => sum + Number(item.calories || 0), 0),
        totalDurationSeconds: records.reduce((sum, item) => sum + Number(item.durationSeconds || 0), 0)
      });
      return;
    }

    sendJson(res, 404, '接口不存在', {}, 404);
  } catch (error) {
    sendJson(res, 500, `${error}`, {}, 500);
  }
});

server.listen(PORT, '0.0.0.0', () => {
  writeLog(`Mock backend running at http://127.0.0.1:${PORT}/api/v1`);
});
