import http from '@ohos.net.http';
import { AuthSession, isAuthSessionValid } from '../models/AuthSession';
import { ApiEnvelope } from '../models/BackendApi';

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
  'Content-Type': string;
  'Authorization'?: string;
  'X-User-Id'?: string;
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

function buildHeaders(authSession?: AuthSession): ApiRequestHeaders {
  if (authSession && isAuthSessionValid(authSession)) {
    return {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${authSession.token.trim()}`,
      'X-User-Id': authSession.userId.trim()
    };
  }
  return {
    'Content-Type': 'application/json'
  };
}

export async function requestApiData<T>(config: ApiRequestConfig): Promise<T> {
  if (config.baseUrl.trim().length === 0) {
    throw new Error('请先填写联调后端地址。');
  }

  let httpRequest = http.createHttp();
  try {
    let response = await httpRequest.request(buildUrl(config.baseUrl, config.path, config.queryParams), {
      method: config.method,
      header: buildHeaders(config.authSession),
      extraData: config.body ? JSON.stringify(config.body) : '',
      connectTimeout: 10000,
      readTimeout: 20000,
      expectDataType: http.HttpDataType.STRING
    });

    let responseText: string = getHttpResponseText(response.result);
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
    throw new Error(errorText);
  } finally {
    httpRequest.destroy();
  }
}
