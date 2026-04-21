import http from '@ohos.net.http';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AuthSession, isAuthSessionValid } from '../models/AuthSession';
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
      xUserId: authSession.userId.trim()
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
    'Authorization': headers.authorization.length > 0 ? headers.authorization : undefined,
    'X-User-Id': headers.xUserId.length > 0 ? headers.xUserId : undefined
  };
}

export async function requestApiData<T>(config: ApiRequestConfig): Promise<T> {
  if (config.baseUrl.trim().length === 0) {
    throw new Error('请先填写联调后端地址。');
  }

  let httpRequest = http.createHttp();
  let requestUrl = buildUrl(config.baseUrl, config.path, config.queryParams);
  let requestHeaders = buildHeaders(config.authSession);
  try {
    let requestLog: ApiRequestLog = {
      method: `${config.method}`,
      url: requestUrl,
      headers: buildLogHeaders(requestHeaders),
      body: config.body ? serializeLogValue(config.body) : ''
    };
    hilog.info(API_LOG_DOMAIN, API_LOG_TAG, 'request %{public}s', serializeLogValue(requestLog));

    let response = await httpRequest.request(requestUrl, {
      method: config.method,
      header: buildHttpHeaders(requestHeaders),
      extraData: config.body ? JSON.stringify(config.body) : '',
      connectTimeout: 10000,
      readTimeout: 20000,
      expectDataType: http.HttpDataType.STRING
    });

    let responseText: string = getHttpResponseText(response.result);
    let responseLog: ApiResponseLog = {
      method: `${config.method}`,
      url: requestUrl,
      statusCode: response.responseCode,
      body: responseText
    };
    hilog.info(API_LOG_DOMAIN, API_LOG_TAG, 'response %{public}s', serializeLogValue(responseLog));
    if (response.responseCode >= 400) {
      throw new Error(`请求失败（${response.responseCode}）：${responseText}`);
    }

    let parsedResponse = JSON.parse(responseText) as ApiEnvelope<T>;
    if (parsedResponse.code !== 0) {
      throw new Error(parsedResponse.message.trim().length > 0 ? parsedResponse.message : `服务返回错误码 ${parsedResponse.code}`);
    }
    return parsedResponse.data;
  } catch (error) {
    let errorText = `${error}`;
    if (errorText.trim().length === 0 || errorText === '[object Object]') {
      errorText = '接口请求失败，请检查联调服务与网络。';
    }
    let errorLog: ApiErrorLog = {
      method: `${config.method}`,
      url: requestUrl,
      error: errorText
    };
    hilog.error(API_LOG_DOMAIN, API_LOG_TAG, 'error %{public}s', serializeLogValue(errorLog));
    throw new Error(errorText);
  } finally {
    httpRequest.destroy();
  }
}
