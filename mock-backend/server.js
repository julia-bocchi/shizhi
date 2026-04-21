const fs = require('fs');
const path = require('path');
const http = require('http');
const { URL } = require('url');

const PORT = Number(process.env.MOCK_BACKEND_PORT || 3000);
const DATA_FILE = path.join(__dirname, 'data.json');

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

function sendJson(res, code, message, data, statusCode = 200) {
  res.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-User-Id',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
  });
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
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(chunks));
      } catch (error) {
        reject(error);
      }
    });
    req.on('error', reject);
  });
}

function createDefaultUser(username) {
  return {
    userId: `user-${username}`,
    username,
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
  return '已保存训练计划';
}

const server = http.createServer(async (req, res) => {
  if (!req.url) {
    sendJson(res, 404, 'Not Found', {}, 404);
    return;
  }
  if (req.method === 'OPTIONS') {
    sendJson(res, 0, 'ok', {});
    return;
  }

  const urlObj = new URL(req.url, `http://127.0.0.1:${PORT}`);
  const pathname = urlObj.pathname;
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
      if (!store.users[username]) {
        store.users[username] = createDefaultUser(username);
      }
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
      sendJson(res, 0, 'ok', { ...target, isUpdated });
      return;
    }

    if (pathname === '/api/v1/food-options' && req.method === 'GET') {
      sendJson(res, 0, 'ok', { items: PRESET_FOOD_OPTIONS.concat(user.customFoodOptions) });
      return;
    }
    if (pathname === '/api/v1/food-options/custom' && req.method === 'POST') {
      const body = await parseBody(req);
      const item = {
        id: nextId('custom-food'),
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
      sendJson(res, 0, 'ok', target);
      return;
    }
    if (pathname.startsWith('/api/v1/food-options/custom/') && req.method === 'DELETE') {
      const foodId = decodeURIComponent(pathname.split('/').pop());
      user.customFoodOptions = user.customFoodOptions.filter(item => item.id !== foodId);
      saveStore(store);
      sendJson(res, 0, 'ok', {});
      return;
    }

    if (pathname === '/api/v1/food-plans' && req.method === 'GET') {
      const startDate = urlObj.searchParams.get('startDate') || '';
      const endDate = urlObj.searchParams.get('endDate') || '';
      const plans = user.foodPlans.filter(item => withinRange(item.date, startDate, endDate));
      sortByDateAsc(plans);
      sendJson(res, 0, 'ok', { plans });
      return;
    }
    if (pathname === '/api/v1/food-plans' && req.method === 'POST') {
      const body = await parseBody(req);
      const sourceOption = PRESET_FOOD_OPTIONS.concat(user.customFoodOptions).find(item => item.id === body.foodId);
      if (!sourceOption) {
        sendJson(res, 404, '食物不存在', {}, 404);
        return;
      }
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
      saveStore(store);
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
      sendJson(res, 0, 'ok', target);
      return;
    }
    if (pathname.startsWith('/api/v1/food-plans/') && req.method === 'DELETE') {
      const planId = decodeURIComponent(pathname.split('/').pop());
      user.foodPlans = user.foodPlans.filter(item => item.id !== planId);
      saveStore(store);
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
      const template = { id: nextId('template'), ...body };
      user.workoutTemplates.unshift(template);
      saveStore(store);
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
      sendJson(res, 0, 'ok', template);
      return;
    }
    if (pathname.startsWith('/api/v1/workout-templates/') && req.method === 'DELETE') {
      const templateId = decodeURIComponent(pathname.split('/').pop());
      user.workoutTemplates = user.workoutTemplates.filter(item => item.id !== templateId);
      saveStore(store);
      sendJson(res, 0, 'ok', {});
      return;
    }

    if (pathname === '/api/v1/workout-plans' && req.method === 'GET') {
      const startDate = urlObj.searchParams.get('startDate') || '';
      const endDate = urlObj.searchParams.get('endDate') || '';
      const plans = user.workoutPlans.filter(item => withinRange(item.date, startDate, endDate));
      sortByDateAsc(plans);
      sendJson(res, 0, 'ok', { plans });
      return;
    }
    if (pathname === '/api/v1/workout-plans' && req.method === 'POST') {
      const body = await parseBody(req);
      const plan = {
        id: nextId('plan'),
        date: `${body.date || ''}`,
        title: `${body.title || '训练计划'}`,
        summary: buildWorkoutSummary(body),
        notes: `${body.notes || ''}`,
        draftText: `${body.draftText || ''}`,
        savedWorkoutId: `${body.savedWorkoutId || ''}`,
        accentColor: pickAccentColorFromDraft(`${body.draftText || ''}`)
      };
      user.workoutPlans.unshift(plan);
      saveStore(store);
      sendJson(res, 0, 'ok', plan);
      return;
    }
    if (pathname.startsWith('/api/v1/workout-plans/') && req.method === 'DELETE') {
      const planId = decodeURIComponent(pathname.split('/').pop());
      user.workoutPlans = user.workoutPlans.filter(item => item.id !== planId);
      saveStore(store);
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
  console.log(`Mock backend running at http://127.0.0.1:${PORT}/api/v1`);
});
