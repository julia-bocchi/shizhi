import http from '@ohos.net.http';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AuthSession, isAuthSessionValid, resolveApiBaseUrl } from '../models/AuthSession';
import { ApiEnvelope } from '../models/BackendApi';

const API_LOG_DOMAIN: number = 0xFF12;
const API_LOG_TAG: string = 'ApiClient';

export interface QueryParamItem {
  key: string;
  value: string;
}

export interface ApiRequestConfig {
  baseUrl: string;
  path: string;
  method: http.RequestMethod;
  authSession?: AuthSession;
  body?: Object;
  queryParams?: QueryParamItem[];
}

interface ApiRequestHeaders {
  contentType: string;
  authorization: string;
  xUserId: string;
}

interface HttpRequestHeaders {
  'Content-Type': string;
  'Accept': string;
  'ngrok-skip-browser-warning': string;
  'Authorization'?: string;
  'X-User-Id'?: string;
}

interface ApiLogHeaders {
  contentType: string;
  authorization: string;
  xUserId: string;
}

interface ApiRequestLog {
  method: string;
  url: string;
  headers: ApiLogHeaders;
  body: string;
}

interface ApiResponseLog {
  method: string;
  url: string;
  statusCode: number;
  body: string;
}

interface ApiErrorLog {
  method: string;
  url: string;
  error: string;
}

interface ApiFinishLog {
  method: string;
  url: string;
  success: boolean;
  statusCode: number;
  durationMs: number;
  error: string;
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

function normalizeBaseUrl(baseUrl: string): string {
  let trimmed = baseUrl.trim();
  if (trimmed.endsWith('/')) {
    return trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}

function normalizePath(path: string): string {
  return path.startsWith('/') ? path : `/${path}`;
}

function buildQueryString(queryParams?: QueryParamItem[]): string {
  if (!queryParams || queryParams.length === 0) {
    return '';
  }

  let fields: string[] = [];
  for (let index = 0; index < queryParams.length; index++) {
    let item = queryParams[index];
    if (item.key.trim().length === 0 || item.value.trim().length === 0) {
      continue;
    }
    fields.push(`${encodeURIComponent(item.key)}=${encodeURIComponent(item.value)}`);
  }
  if (fields.length === 0) {
    return '';
  }
  return `?${fields.join('&')}`;
}

function buildUrl(baseUrl: string, path: string, queryParams?: QueryParamItem[]): string {
  return `${normalizeBaseUrl(baseUrl)}${normalizePath(path)}${buildQueryString(queryParams)}`;
}

function maskSensitiveText(value: string): string {
  if (value.trim().length <= 12) {
    return '***';
  }
  return `${value.substring(0, 6)}...${value.substring(value.length - 4)}`;
}

function buildHeaders(authSession?: AuthSession): ApiRequestHeaders {
  if (authSession && isAuthSessionValid(authSession)) {
    return {
      contentType: 'application/json',
      authorization: `Bearer ${authSession.token.trim()}`,
      xUserId: `${authSession.userId}`
    };
  }
  return {
    contentType: 'application/json',
    authorization: '',
    xUserId: ''
  };
}

function serializeLogValue(value: Object | string | undefined | null): string {
  if (value === undefined || value === null) {
    return '';
  }
  if (typeof value === 'string') {
    return value;
  }
  return JSON.stringify(value);
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

  let serializedError = serializeLogValue(error);
  if (serializedError.trim().length > 0 && serializedError !== '{}') {
    return serializedError;
  }
  return fallbackMessage;
}

function isApiSuccess(code: number): boolean {
  return code === 0 || code === 200;
}

function resolveApiMessage<T>(response: ApiEnvelope<T>): string {
  let message = response.message ?? response.msg ?? '';
  return `${message}`.trim();
}

function buildLogHeaders(headers: ApiRequestHeaders): ApiLogHeaders {
  return {
    contentType: headers.contentType,
    authorization: headers.authorization.length > 0 ? maskSensitiveText(headers.authorization) : '',
    xUserId: headers.xUserId
  };
}

function buildHttpHeaders(headers: ApiRequestHeaders): HttpRequestHeaders {
  return {
    'Content-Type': headers.contentType,
    'Accept': 'application/json, text/plain, */*',
    'ngrok-skip-browser-warning': 'true',
    'Authorization': headers.authorization.length > 0 ? headers.authorization : undefined,
    'X-User-Id': headers.xUserId.length > 0 ? headers.xUserId : undefined
  };
}

function looksLikeJsonText(text: string): boolean {
  let trimmed = text.trim();
  return trimmed.startsWith('{') || trimmed.startsWith('[');
}

function resolveResponseErrorMessage(statusCode: number, responseText: string, requestUrl: string,
  headers: ApiRequestHeaders): string {
  let trimmedBody = responseText.trim();
  let normalizedBody = trimmedBody.toLowerCase();
  let normalizedUrl = requestUrl.toLowerCase();

  if ((normalizedUrl.indexOf('.ngrok-free.dev') >= 0 || normalizedUrl.indexOf('.ngrok.io') >= 0) &&
    (normalizedBody.indexOf('err_ngrok_3200') >= 0 || normalizedBody.indexOf('endpoint') >= 0 && normalizedBody.indexOf('offline') >= 0)) {
    return '联调地址当前离线：ngrok 隧道未在线，请先启动或更换新的公网地址。';
  }
  if (statusCode === 401 || statusCode === 403) {
    if (headers.authorization.trim().length === 0 || headers.xUserId.trim().length === 0) {
      return '当前没有有效登录态，请先登录后再同步数据。';
    }
    return '登录态已失效或无权限访问，请重新登录后重试。';
  }
  if (trimmedBody.length > 0) {
    return `请求失败（${statusCode}）：${trimmedBody}`;
  }
  return `请求失败（${statusCode}）。`;
}

function isApiEnvelopeLike(value: Object): boolean {
  let envelope = value as ApiEnvelope<Object>;
  return typeof envelope.code === 'number';
}

export async function requestApiData<T>(config: ApiRequestConfig): Promise<T> {
  let httpRequest = http.createHttp();
  let resolvedBaseUrl = resolveApiBaseUrl(config.baseUrl);
  if (resolvedBaseUrl.trim().length === 0) {
    throw new Error('请先填写联调后端地址。');
  }
  let requestUrl = buildUrl(resolvedBaseUrl, config.path, config.queryParams);
  let requestHeaders = buildHeaders(config.authSession);
  let startedAt = Date.now();
  let responseStatusCode = -1;
  let errorText = '';
  try {
    let requestLog: ApiRequestLog = {
      method: `${config.method}`,
      url: requestUrl,
      headers: buildLogHeaders(requestHeaders),
      body: config.body ? serializeLogValue(config.body) : ''
    };
    hilog.info(API_LOG_DOMAIN, API_LOG_TAG, '发起请求，请求方法=%{public}s，请求链接=%{public}s，请求头=%{public}s，请求体=%{public}s',
      requestLog.method, requestLog.url, serializeLogValue(requestLog.headers), requestLog.body);
    hilog.info(API_LOG_DOMAIN, API_LOG_TAG, '请求详情 %{public}s', serializeLogValue(requestLog));

    let response = await httpRequest.request(requestUrl, {
      method: config.method,
      header: buildHttpHeaders(requestHeaders),
      extraData: config.body ? JSON.stringify(config.body) : '',
      connectTimeout: 10000,
      readTimeout: 20000,
      expectDataType: http.HttpDataType.STRING
    });

    responseStatusCode = response.responseCode;
    let responseText: string = getHttpResponseText(response.result);
    let responseLog: ApiResponseLog = {
      method: `${config.method}`,
      url: requestUrl,
      statusCode: response.responseCode,
      body: responseText
    };
    hilog.info(API_LOG_DOMAIN, API_LOG_TAG, '收到响应，请求方法=%{public}s，请求链接=%{public}s，状态码=%{public}d，响应头=%{public}s，响应体=%{public}s',
      responseLog.method, responseLog.url, responseLog.statusCode, serializeLogValue(response.header as Object), responseLog.body);
    hilog.info(API_LOG_DOMAIN, API_LOG_TAG, '响应详情 %{public}s', serializeLogValue(responseLog));
    if (response.responseCode >= 400) {
      throw new Error(resolveResponseErrorMessage(response.responseCode, responseText, requestUrl, requestHeaders));
    }

    if (response.responseCode === 204 || responseText.trim().length === 0) {
      return undefined as T;
    }
    if (!looksLikeJsonText(responseText)) {
      return responseText as T;
    }

    let parsedResponse = JSON.parse(responseText) as ApiEnvelope<T>;
    if (isApiEnvelopeLike(parsedResponse as Object)) {
      if (!isApiSuccess(parsedResponse.code)) {
        let message = resolveApiMessage(parsedResponse);
        throw new Error(message.length > 0 ? message : `服务返回错误码 ${parsedResponse.code}`);
      }
      return parsedResponse.data;
    }
    return parsedResponse as T;
  } catch (error) {
    errorText = resolveErrorText(error, '接口请求失败，请检查联调服务与网络。');
    let errorLog: ApiErrorLog = {
      method: `${config.method}`,
      url: requestUrl,
      error: errorText
    };
    hilog.error(API_LOG_DOMAIN, API_LOG_TAG, '请求异常，请求方法=%{public}s，请求链接=%{public}s，错误信息=%{public}s',
      errorLog.method, errorLog.url, errorLog.error);
    hilog.error(API_LOG_DOMAIN, API_LOG_TAG, '异常详情 %{public}s', serializeLogValue(errorLog));
    throw new Error(errorText);
  } finally {
    let finishLog: ApiFinishLog = {
      method: `${config.method}`,
      url: requestUrl,
      success: errorText.length === 0,
      statusCode: responseStatusCode,
      durationMs: Date.now() - startedAt,
      error: errorText
    };
    hilog.info(API_LOG_DOMAIN, API_LOG_TAG,
      '请求结束，请求方法=%{public}s，请求链接=%{public}s，是否成功=%{public}s，状态码=%{public}d，耗时=%{public}dms，错误信息=%{public}s',
      finishLog.method,
      finishLog.url,
      finishLog.success ? '是' : '否',
      finishLog.statusCode,
      finishLog.durationMs,
      finishLog.error);
    hilog.info(API_LOG_DOMAIN, API_LOG_TAG, '结束详情 %{public}s', serializeLogValue(finishLog));
    httpRequest.destroy();
  }
}
