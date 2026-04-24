function sanitizeString(value: string | number | boolean | undefined | null, fallbackValue: string = ''): string {
  if (value === undefined || value === null) {
    return fallbackValue;
  }
  return `${value}`;
}

export function normalizeUniqueName(name: string): string {
  return sanitizeString(name)
    .trim()
    .replace(/\s+/g, ' ')
    .toLowerCase();
}

export function buildStableIdentitySuffix(name: string, fallbackValue: string = 'item'): string {
  let normalizedName: string = normalizeUniqueName(name);
  if (normalizedName.length === 0) {
    return fallbackValue;
  }
  let slugText: string = normalizedName
    .replace(/\s+/g, '-')
    .replace(/[^0-9a-z\u4e00-\u9fa5-]/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-+|-+$/g, '');
  return slugText.length > 0 ? slugText : fallbackValue;
}

export function isSameUniqueName(leftName: string, rightName: string): boolean {
  let leftNormalized: string = normalizeUniqueName(leftName);
  if (leftNormalized.length === 0) {
    return false;
  }
  return leftNormalized === normalizeUniqueName(rightName);
}
