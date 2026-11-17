import type { SessionRateLimit } from 'claude-code'

// One rate-limit window: percent used (0 to 100) and when it resets (ISO 8601).
export type Window = { percentUsed: number; resetsAt?: string }

// Extra-usage (overage) spend; amounts are in minor units of `currency`.
export type Extra = {
  isEnabled: boolean
  usedMinor: number | null
  limitMinor: number | null
  currency: string
}

// What the meter shows. `fetchedAt` is when the usage endpoint answered
// (0 before the first answer); `windowsAt` is when the 5h and 7d windows were
// last set, by the endpoint or by a session.measure event.
export type Reading = {
  fiveHour?: Window
  sevenDay?: Window
  extra?: Extra
  fetchedAt: number
  windowsAt: number
}

export const EMPTY_READING: Reading = { fetchedAt: 0, windowsAt: 0 }

// Reads the /api/oauth/usage body; fields it does not know are ignored.
export function parse_usage_body(body: unknown, fetchedAt: number): Reading {
  const root = as_record(body)

  return {
    fiveHour: parse_window(root?.five_hour),
    sevenDay: parse_window(root?.seven_day),
    extra: parse_extra(root?.extra_usage),
    fetchedAt,
    windowsAt: fetchedAt,
  }
}

// Takes a newer endpoint reading over the current one, keeping windows that a
// session.measure event set after that reading was fetched.
export function adopt_reading(current: Reading, incoming: Reading): Reading {
  if (incoming.fetchedAt < current.fetchedAt) {
    return current
  }

  const isWindowsNewer = incoming.fetchedAt >= current.windowsAt

  return {
    fiveHour: isWindowsNewer ? incoming.fiveHour : current.fiveHour,
    sevenDay: isWindowsNewer ? incoming.sevenDay : current.sevenDay,
    extra: incoming.extra ?? current.extra,
    fetchedAt: incoming.fetchedAt,
    windowsAt: Math.max(current.windowsAt, incoming.fetchedAt),
  }
}

// Folds the windows the session's last API response reported into a reading.
export function apply_rate_limits(
  current: Reading,
  limits: readonly SessionRateLimit[],
  now: number,
): Reading {
  const fiveHour = limits.find(limit => limit.kind === 'five_hour')
  const sevenDay = limits.find(limit => limit.kind === 'seven_day')

  if (fiveHour === undefined && sevenDay === undefined) {
    return current
  }

  return {
    ...current,
    fiveHour: fiveHour ? to_window(fiveHour) : current.fiveHour,
    sevenDay: sevenDay ? to_window(sevenDay) : current.sevenDay,
    windowsAt: now,
  }
}

// The status line: `5h 23% (2h10m 후 리셋) | 7d 41% (3d 5h 후) | 추가 $12.30/$50`.
export function format_line(reading: Reading, now: number): string | undefined {
  const parts: string[] = []

  if (reading.fiveHour) {
    parts.push(`5h ${format_window(reading.fiveHour, now, ' 후 리셋')}`)
  }

  if (reading.sevenDay) {
    parts.push(`7d ${format_window(reading.sevenDay, now, ' 후')}`)
  }

  if (reading.extra) {
    parts.push(format_extra(reading.extra))
  }

  return parts.length === 0 ? undefined : parts.join(' | ')
}

// Time left until `resetsAt`: `45m`, `2h10m`, `3d 5h`.
export function format_remaining(resetsAt: string, now: number): string | undefined {
  const at = Date.parse(resetsAt)

  if (Number.isNaN(at)) {
    return undefined
  }

  const minutes = Math.max(0, Math.ceil((at - now) / 60_000))
  const days = Math.floor(minutes / 1440)
  const hours = Math.floor((minutes % 1440) / 60)

  if (days > 0) {
    return `${days}d ${hours}h`
  }

  return hours > 0 ? `${hours}h${minutes % 60}m` : `${minutes}m`
}

export function format_money(minor: number, currency: string): string {
  try {
    const digits = new Intl.NumberFormat('en-US', { style: 'currency', currency })
      .resolvedOptions().maximumFractionDigits ?? 2
    const amount = minor / 10 ** digits
    const isWhole = Number.isInteger(amount)

    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency,
      minimumFractionDigits: isWhole ? 0 : digits,
      maximumFractionDigits: digits,
    }).format(amount)
  } catch {
    return `${(minor / 100).toFixed(2)} ${currency}`
  }
}

function format_window(window: Window, now: number, suffix: string): string {
  const percent = `${Math.round(window.percentUsed)}%`

  if (window.resetsAt === undefined) {
    return percent
  }

  if (Date.parse(window.resetsAt) <= now) {
    return `${percent} (리셋됨)`
  }

  const remaining = format_remaining(window.resetsAt, now)

  return remaining === undefined ? percent : `${percent} (${remaining}${suffix})`
}

function format_extra(extra: Extra): string {
  if (!extra.isEnabled && !extra.usedMinor) {
    return '추가 꺼짐'
  }

  const used = format_money(extra.usedMinor ?? 0, extra.currency)
  const limit = extra.limitMinor === null ? '' : `/${format_money(extra.limitMinor, extra.currency)}`

  return `추가 ${used}${limit}${extra.isEnabled ? '' : ' (꺼짐)'}`
}

function to_window(limit: SessionRateLimit): Window {
  return { percentUsed: limit.percentUsed, resetsAt: limit.resetsAt }
}

function parse_window(value: unknown): Window | undefined {
  const row = as_record(value)

  if (row === undefined || typeof row.utilization !== 'number') {
    return undefined
  }

  return {
    percentUsed: row.utilization,
    resetsAt: typeof row.resets_at === 'string' ? row.resets_at : undefined,
  }
}

function parse_extra(value: unknown): Extra | undefined {
  const row = as_record(value)

  if (row === undefined) {
    return undefined
  }

  return {
    isEnabled: row.is_enabled === true,
    usedMinor: typeof row.used_credits === 'number' ? row.used_credits : null,
    limitMinor: typeof row.monthly_limit === 'number' ? row.monthly_limit : null,
    currency: typeof row.currency === 'string' && row.currency !== '' ? row.currency : 'USD',
  }
}

function as_record(value: unknown): Record<string, unknown> | undefined {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined
}
