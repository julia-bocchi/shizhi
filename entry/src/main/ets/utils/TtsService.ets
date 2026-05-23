import http from '@ohos.net.http';
import media from '@ohos.multimedia.media';
import { hilog } from '@kit.PerformanceAnalysisKit';

export const DEFAULT_TTS_ENDPOINT: string = 'http://192.168.186.1:8000/api/v1/tts/briefing';
export const DEFAULT_TTS_VOICE: string = 'housekeeper_default';

const TTS_LOG_DOMAIN: number = 0xFF16;
const TTS_LOG_TAG: string = 'TtsService';
const TTS_CACHE_LIMIT: number = 12;

export interface TtsBriefingRequest {
  userId: string;
  date: string;
  text: string;
  voice: string;
}

export interface TtsBriefingResponse {
  audioUrl: string;
  cached: boolean;
  durationMs: number;
}

export interface TtsAudioCacheRecord {
  date: string;
  textHash: string;
  voice: string;
  audioUrl: string;
  durationMs: number;
  updatedAt: number;
}

export type TtsPlaybackState = 'idle' | 'loading' | 'playing' | 'paused';
export type TtsPlaybackStateChangeHandler = (state: TtsPlaybackState) => void;

interface ParsedTtsBriefingResponse {
  audioUrl?: string | number;
  cached?: boolean;
  durationMs?: string | number;
  data?: ParsedTtsBriefingResponse;
}

let currentTtsPlayer: media.AVPlayer | undefined = undefined;
let currentTtsPlaybackState: TtsPlaybackState = 'idle';
let currentTtsPlaybackStateChangeHandler: TtsPlaybackStateChangeHandler | undefined = undefined;

function buildLogPreview(text: string, maxLength: number = 120): string {
  let trimmedText = text.trim();
  if (trimmedText.length <= maxLength) {
    return trimmedText;
  }
  return `${trimmedText.substring(0, maxLength)}...`;
}

function sanitizeString(value: string | number | boolean | undefined | null, fallbackValue: string = ''): string {
  if (value === undefined || value === null) {
    return fallbackValue;
  }
  return `${value}`;
}

function sanitizeNumber(value: string | number | boolean | undefined | null, fallbackValue: number = 0): number {
  if (typeof value === 'number') {
    return isNaN(value) ? fallbackValue : value;
  }
  if (value === undefined || value === null) {
    return fallbackValue;
  }
  let parsedValue: number = Number(`${value}`);
  return isNaN(parsedValue) ? fallbackValue : parsedValue;
}

function getHttpResponseText(result: string | Object | ArrayBuffer): string {
  if (typeof result === 'string') {
    return result;
  }
  if (result instanceof ArrayBuffer) {
    return '';
  }
  return JSON.stringify(result);
}

function resolveErrorText(error: Object | string | undefined | null, fallbackMessage: string): string {
  if (typeof error === 'string') {
    let trimmedError = error.trim();
    return trimmedError.length > 0 ? trimmedError : fallbackMessage;
  }
  let rawText = `${error}`;
  if (rawText.trim().length > 0 && rawText !== '[object Object]') {
    return rawText;
  }
  try {
    let serialized = JSON.stringify(error);
    if (serialized.trim().length > 0 && serialized !== '{}') {
      return serialized;
    }
  } catch (parseError) {
  }
  return fallbackMessage;
}

function updateTtsPlaybackState(state: TtsPlaybackState): void {
  currentTtsPlaybackState = state;
  hilog.info(TTS_LOG_DOMAIN, TTS_LOG_TAG, 'TTS 播放业务状态：state=%{public}s', state);
  if (currentTtsPlaybackStateChangeHandler === undefined) {
    return;
  }
  try {
    currentTtsPlaybackStateChangeHandler(state);
  } catch (error) {
    hilog.warn(TTS_LOG_DOMAIN, TTS_LOG_TAG,
      'TTS 播放状态回调失败：%{public}s',
      resolveErrorText(error, 'state callback failed'));
  }
}

function isExpectedPlayerState(stateText: string, expectedStates: string[]): boolean {
  for (let index = 0; index < expectedStates.length; index++) {
    if (stateText === expectedStates[index]) {
      return true;
    }
  }
  return false;
}

function shouldReleasePlayerAtState(stateText: string): boolean {
  return stateText === 'completed' || stateText === 'stopped' || stateText === 'released' || stateText === 'error';
}

function waitForPlayerState(player: media.AVPlayer, getCurrentState: () => string, expectedStates: string[],
  actionText: string, timeoutMs: number = 12000): Promise<void> {
  if (isExpectedPlayerState(getCurrentState(), expectedStates)) {
    return Promise.resolve();
  }
  return new Promise<void>((resolve: () => void, reject: (reason: Error) => void) => {
    let settled: boolean = false;
    let timeoutId: number = setTimeout(() => {
      if (settled) {
        return;
      }
      settled = true;
      reject(new Error(`${actionText}超时，播放器状态没有进入 ${expectedStates.join('/')}`));
    }, timeoutMs);

    let finishSuccessfully = (): void => {
      if (settled) {
        return;
      }
      settled = true;
      clearTimeout(timeoutId);
      resolve();
    };

    let failWithError = (message: string): void => {
      if (settled) {
        return;
      }
      settled = true;
      clearTimeout(timeoutId);
      reject(new Error(message));
    };

    player.on('stateChange', (state: media.AVPlayerState): void => {
      let stateText = `${state}`;
      if (isExpectedPlayerState(stateText, expectedStates)) {
        finishSuccessfully();
        return;
      }
      if (stateText === 'error' || stateText === 'released') {
        failWithError(`${actionText}失败，播放器状态为 ${stateText}`);
      }
    });

    player.on('error', (): void => {
      failWithError(`${actionText}失败，播放器上报 error 事件。`);
    });
  });
}

export function getTtsPlaybackState(): TtsPlaybackState {
  return currentTtsPlaybackState;
}

export function createTtsTextHash(text: string): string {
  let hash: number = 5381;
  for (let index = 0; index < text.length; index++) {
    hash = ((hash * 33) + text.charCodeAt(index)) >>> 0;
  }
  return `${hash}`;
}

export function deserializeTtsAudioCache(cacheText: string): TtsAudioCacheRecord[] {
  if (cacheText.trim().length === 0) {
    return [];
  }
  try {
    let parsedRecords = JSON.parse(cacheText) as TtsAudioCacheRecord[];
    if (!Array.isArray(parsedRecords)) {
      return [];
    }
    let result: TtsAudioCacheRecord[] = [];
    for (let index = 0; index < parsedRecords.length; index++) {
      let currentRecord = parsedRecords[index];
      let audioUrl = sanitizeString(currentRecord.audioUrl).trim();
      if (audioUrl.length === 0) {
        continue;
      }
      result.push({
        date: sanitizeString(currentRecord.date),
        textHash: sanitizeString(currentRecord.textHash),
        voice: sanitizeString(currentRecord.voice, DEFAULT_TTS_VOICE),
        audioUrl: audioUrl,
        durationMs: sanitizeNumber(currentRecord.durationMs, 0),
        updatedAt: sanitizeNumber(currentRecord.updatedAt, Date.now())
      });
    }
    return result;
  } catch (error) {
    return [];
  }
}

export function serializeTtsAudioCache(records: TtsAudioCacheRecord[]): string {
  return JSON.stringify(records);
}

export function getCachedTtsAudioUrl(cacheText: string, dateText: string, text: string,
  voice: string = DEFAULT_TTS_VOICE): string {
  let textHash = createTtsTextHash(text);
  let records = deserializeTtsAudioCache(cacheText);
  hilog.info(TTS_LOG_DOMAIN, TTS_LOG_TAG,
    '查询 TTS 本地音频缓存：date=%{public}s，voice=%{public}s，textHash=%{public}s，cacheCount=%{public}d',
    dateText, voice, textHash, records.length);
  for (let index = 0; index < records.length; index++) {
    let currentRecord = records[index];
    if (currentRecord.date === dateText && currentRecord.textHash === textHash && currentRecord.voice === voice) {
      hilog.info(TTS_LOG_DOMAIN, TTS_LOG_TAG,
        '命中 TTS 本地音频缓存：audioUrl=%{public}s，durationMs=%{public}d',
        currentRecord.audioUrl, currentRecord.durationMs);
      return currentRecord.audioUrl;
    }
  }
  hilog.info(TTS_LOG_DOMAIN, TTS_LOG_TAG, '未命中 TTS 本地音频缓存：textHash=%{public}s', textHash);
  return '';
}

export function upsertTtsAudioCache(cacheText: string, dateText: string, text: string, voice: string,
  response: TtsBriefingResponse): string {
  let textHash = createTtsTextHash(text);
  let records = deserializeTtsAudioCache(cacheText);
  hilog.info(TTS_LOG_DOMAIN, TTS_LOG_TAG,
    '写入 TTS 本地音频缓存：date=%{public}s，voice=%{public}s，textHash=%{public}s，audioUrl=%{public}s，durationMs=%{public}d',
    dateText, voice, textHash, response.audioUrl, response.durationMs);
  let nextRecords: TtsAudioCacheRecord[] = [{
    date: dateText,
    textHash: textHash,
    voice: voice,
    audioUrl: response.audioUrl,
    durationMs: response.durationMs,
    updatedAt: Date.now()
  }];
  for (let index = 0; index < records.length; index++) {
    let currentRecord = records[index];
    if (currentRecord.date === dateText && currentRecord.textHash === textHash && currentRecord.voice === voice) {
      continue;
    }
    nextRecords.push(currentRecord);
    if (nextRecords.length >= TTS_CACHE_LIMIT) {
      break;
    }
  }
  return serializeTtsAudioCache(nextRecords);
}

export async function requestTtsBriefing(endpoint: string,
  requestBody: TtsBriefingRequest): Promise<TtsBriefingResponse> {
  let requestUrl = endpoint.trim();
  if (requestUrl.length === 0) {
    throw new Error('请先配置 IndexTTS2 本地服务地址。');
  }
  let httpRequest = http.createHttp();
  let startedAt: number = Date.now();
  let responseStatusCode: number = -1;
  let textHash = createTtsTextHash(requestBody.text);
  hilog.info(TTS_LOG_DOMAIN, TTS_LOG_TAG,
    '发起 IndexTTS2 请求：url=%{public}s，userId=%{public}s，date=%{public}s，voice=%{public}s，textLength=%{public}d，textHash=%{public}s，textPreview=%{public}s',
    requestUrl,
    requestBody.userId,
    requestBody.date,
    requestBody.voice,
    requestBody.text.length,
    textHash,
    buildLogPreview(requestBody.text));
  try {
    let response = await httpRequest.request(requestUrl, {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/plain, */*'
      },
      extraData: JSON.stringify(requestBody),
      connectTimeout: 15000,
      readTimeout: 120000,
      expectDataType: http.HttpDataType.STRING
    });
    responseStatusCode = response.responseCode;
    let responseText = getHttpResponseText(response.result);
    hilog.info(TTS_LOG_DOMAIN, TTS_LOG_TAG,
      '收到 IndexTTS2 响应：status=%{public}d，bodyLength=%{public}d，bodyPreview=%{public}s',
      response.responseCode,
      responseText.length,
      buildLogPreview(responseText, 240));
    if (response.responseCode >= 400) {
      throw new Error(`IndexTTS2 请求失败（${response.responseCode}）：${responseText}`);
    }
    let parsedResponse = JSON.parse(responseText) as ParsedTtsBriefingResponse;
    let payload = parsedResponse.data ? parsedResponse.data : parsedResponse;
    let audioUrl = sanitizeString(payload.audioUrl).trim();
    if (audioUrl.length === 0) {
      throw new Error('IndexTTS2 服务没有返回 audioUrl。');
    }
    hilog.info(TTS_LOG_DOMAIN, TTS_LOG_TAG,
      'IndexTTS2 响应解析完成：audioUrl=%{public}s，cached=%{public}s，durationMs=%{public}d',
      audioUrl,
      payload.cached === true ? 'true' : 'false',
      sanitizeNumber(payload.durationMs, 0));
    return {
      audioUrl: audioUrl,
      cached: payload.cached === true,
      durationMs: sanitizeNumber(payload.durationMs, 0)
    };
  } catch (error) {
    let errorText = resolveErrorText(error, 'IndexTTS2 语音生成失败，请稍后重试。');
    hilog.error(TTS_LOG_DOMAIN, TTS_LOG_TAG, 'IndexTTS2 请求异常：%{public}s', errorText);
    throw new Error(errorText);
  } finally {
    hilog.info(TTS_LOG_DOMAIN, TTS_LOG_TAG,
      'IndexTTS2 请求结束：status=%{public}d，durationMs=%{public}d，userId=%{public}s，date=%{public}s，voice=%{public}s，textHash=%{public}s',
      responseStatusCode,
      Date.now() - startedAt,
      requestBody.userId,
      requestBody.date,
      requestBody.voice,
      textHash);
    httpRequest.destroy();
  }
}

async function releaseTtsPlayer(player: media.AVPlayer): Promise<void> {
  hilog.info(TTS_LOG_DOMAIN, TTS_LOG_TAG, '释放 TTS 播放器资源。');
  if (currentTtsPlayer === player) {
    currentTtsPlayer = undefined;
    updateTtsPlaybackState('idle');
    currentTtsPlaybackStateChangeHandler = undefined;
  }
  try {
    await player.release();
  } catch (error) {
    hilog.warn(TTS_LOG_DOMAIN, TTS_LOG_TAG, '释放 TTS 播放器失败：%{public}s', resolveErrorText(error, 'release failed'));
  }
}

export async function stopTtsPlayback(): Promise<void> {
  if (currentTtsPlayer === undefined) {
    hilog.info(TTS_LOG_DOMAIN, TTS_LOG_TAG, '停止 TTS 播放：当前没有活动播放器。');
    updateTtsPlaybackState('idle');
    currentTtsPlaybackStateChangeHandler = undefined;
    return;
  }
  let player = currentTtsPlayer;
  currentTtsPlayer = undefined;
  updateTtsPlaybackState('idle');
  currentTtsPlaybackStateChangeHandler = undefined;
  try {
    hilog.info(TTS_LOG_DOMAIN, TTS_LOG_TAG, '停止 TTS 播放器。');
    await player.stop();
  } catch (error) {
    hilog.warn(TTS_LOG_DOMAIN, TTS_LOG_TAG, '停止 TTS 播放器失败：%{public}s', resolveErrorText(error, 'stop failed'));
  }
  await releaseTtsPlayer(player);
}

export async function pauseTtsPlayback(): Promise<boolean> {
  if (currentTtsPlayer === undefined) {
    hilog.info(TTS_LOG_DOMAIN, TTS_LOG_TAG, '暂停 TTS 播放：当前没有活动播放器。');
    updateTtsPlaybackState('idle');
    return false;
  }
  if (currentTtsPlaybackState !== 'playing') {
    hilog.info(TTS_LOG_DOMAIN, TTS_LOG_TAG,
      '暂停 TTS 播放：当前业务状态不允许暂停，state=%{public}s',
      currentTtsPlaybackState);
    return false;
  }
  try {
    hilog.info(TTS_LOG_DOMAIN, TTS_LOG_TAG, '暂停 TTS 播放器。');
    await currentTtsPlayer.pause();
    updateTtsPlaybackState('paused');
    return true;
  } catch (error) {
    let errorText = resolveErrorText(error, '暂停语音失败。');
    hilog.error(TTS_LOG_DOMAIN, TTS_LOG_TAG, '暂停 TTS 播放失败：%{public}s', errorText);
    throw new Error(errorText);
  }
}

export async function resumeTtsPlayback(): Promise<boolean> {
  if (currentTtsPlayer === undefined) {
    hilog.info(TTS_LOG_DOMAIN, TTS_LOG_TAG, '继续 TTS 播放：当前没有活动播放器。');
    updateTtsPlaybackState('idle');
    return false;
  }
  if (currentTtsPlaybackState !== 'paused') {
    hilog.info(TTS_LOG_DOMAIN, TTS_LOG_TAG,
      '继续 TTS 播放：当前业务状态不允许继续，state=%{public}s',
      currentTtsPlaybackState);
    return false;
  }
  try {
    hilog.info(TTS_LOG_DOMAIN, TTS_LOG_TAG, '继续 TTS 播放器。');
    await currentTtsPlayer.play();
    updateTtsPlaybackState('playing');
    return true;
  } catch (error) {
    let errorText = resolveErrorText(error, '继续语音失败。');
    hilog.error(TTS_LOG_DOMAIN, TTS_LOG_TAG, '继续 TTS 播放失败：%{public}s', errorText);
    throw new Error(errorText);
  }
}

export async function playTtsAudioUrl(audioUrl: string,
  stateChangeHandler?: TtsPlaybackStateChangeHandler): Promise<boolean> {
  let trimmedUrl = audioUrl.trim();
  if (trimmedUrl.length === 0) {
    throw new Error('没有可播放的语音地址。');
  }

  await stopTtsPlayback();
  let player: media.AVPlayer | undefined = undefined;
  try {
    hilog.info(TTS_LOG_DOMAIN, TTS_LOG_TAG, '开始播放 TTS 音频：audioUrl=%{public}s', trimmedUrl);
    currentTtsPlaybackStateChangeHandler = stateChangeHandler;
    updateTtsPlaybackState('loading');
    let activePlayer: media.AVPlayer = await media.createAVPlayer();
    player = activePlayer;
    currentTtsPlayer = activePlayer;
    let lastPlayerState: string = 'idle';

    // IndexTTS2 只作为统一音色播报源，播放失败时交给页面提示重试，不切换系统 TTS。
    activePlayer.on('stateChange', (state: media.AVPlayerState): void => {
      let stateText = `${state}`;
      lastPlayerState = stateText;
      hilog.info(TTS_LOG_DOMAIN, TTS_LOG_TAG, 'TTS 播放状态变化：state=%{public}s', stateText);
      if (currentTtsPlayer !== activePlayer) {
        return;
      }
      if (stateText === 'playing') {
        updateTtsPlaybackState('playing');
        return;
      }
      if (stateText === 'paused') {
        updateTtsPlaybackState('paused');
        return;
      }
      if (shouldReleasePlayerAtState(stateText)) {
        releaseTtsPlayer(activePlayer);
      }
    });
    activePlayer.on('error', (): void => {
      hilog.error(TTS_LOG_DOMAIN, TTS_LOG_TAG, 'TTS 播放器上报 error 事件。');
      if (currentTtsPlayer === activePlayer) {
        releaseTtsPlayer(activePlayer);
      }
    });

    let initializedPromise = waitForPlayerState(
      activePlayer,
      (): string => lastPlayerState,
      ['initialized'],
      '初始化 TTS 音频'
    );
    activePlayer.url = trimmedUrl;
    await initializedPromise;

    let preparedPromise = waitForPlayerState(
      activePlayer,
      (): string => lastPlayerState,
      ['prepared'],
      '准备 TTS 音频'
    );
    await activePlayer.prepare();
    await preparedPromise;

    let playingPromise = waitForPlayerState(
      activePlayer,
      (): string => lastPlayerState,
      ['playing', 'completed'],
      '播放 TTS 音频'
    );
    await activePlayer.play();
    await playingPromise;
    hilog.info(TTS_LOG_DOMAIN, TTS_LOG_TAG, 'TTS 音频已进入播放流程。');
    return true;
  } catch (error) {
    if (player !== undefined && currentTtsPlayer === player) {
      await releaseTtsPlayer(player);
    } else {
      updateTtsPlaybackState('idle');
      currentTtsPlaybackStateChangeHandler = undefined;
    }
    let errorText = resolveErrorText(error, '语音播放失败，请检查音频地址是否可访问。');
    hilog.error(TTS_LOG_DOMAIN, TTS_LOG_TAG, 'TTS 音频播放失败：%{public}s', errorText);
    throw new Error(errorText);
  }
}
