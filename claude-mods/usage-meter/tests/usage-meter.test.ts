import { describe, expect, mock, test } from 'claude-code/testing'
import type { On } from 'claude-code'

import { format_line, format_money, format_remaining, parse_usage_body } from '../hooks/usage'

const NOW = Date.parse('2026-10-09T12:00:00Z')

const BODY = {
  five_hour: { utilization: 23, resets_at: '2026-10-09T14:10:00Z' },
  seven_day: { utilization: 41.4, resets_at: '2026-10-12T17:00:00Z' },
  seven_day_opus: null,
  extra_usage: { is_enabled: true, monthly_limit: 5000, used_credits: 1230, utilization: 24.6, currency: 'USD' },
}

// The world beneath the mod: an authorized subscription login, an endpoint
// answering BODY (counted), and a status line recorded as it is pinned.
function stage(on: On, store: Record<string, unknown> = {}) {
  const clock = mock.clock(on, { now: NOW })
  mock.store(on, store)
  const seen = { fetches: 0, status: [] as (string | undefined)[] }

  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('session.measure', ($, e) => ({ changed: e.changed }))
  on('command.register', ($, e) => ({ value: { command: e.name } }))
  on('session.usage', () => ({
    value: { startedAt: NOW, context: { window: 200_000 }, rateLimits: [] },
  }))
  on('session.authorize', () => ({ value: { handle: 'handle', kind: 'bearer' as const } }))
  on('http.fetch', () => {
    seen.fetches += 1
    return { value: { status: 200, ok: true, headers: {}, text: JSON.stringify(BODY) } }
  })
  on('ui.status', ($, e) => {
    seen.status.push(e.text)
    return { value: undefined }
  })
  on('ui.log', () => ({ value: undefined }))

  return { clock, seen }
}

describe('formatting', () => {
  test('a full reading is one line', () => {
    expect(format_line(parse_usage_body(BODY, NOW), NOW)).toBe(
      '5h 23% (2h10m 후 리셋) | 7d 41% (3d 5h 후) | 추가 $12.30/$50',
    )
  })

  test('money keeps cents only when there are some', () => {
    expect(format_money(1230, 'USD')).toBe('$12.30')
    expect(format_money(5000, 'USD')).toBe('$50')
  })

  test('remaining time drops to minutes under an hour', () => {
    expect(format_remaining('2026-10-09T12:45:00Z', NOW)).toBe('45m')
  })

  test('extra usage that is off and unused says so', () => {
    const body = { extra_usage: { is_enabled: false, monthly_limit: null, used_credits: null } }
    expect(format_line(parse_usage_body(body, NOW), NOW)).toBe('추가 꺼짐')
  })

  test('a window past its reset is marked', () => {
    const body = { five_hour: { utilization: 90, resets_at: '2026-10-09T11:00:00Z' } }
    expect(format_line(parse_usage_body(body, NOW), NOW)).toBe('5h 90% (리셋됨)')
  })
})

describe('the status line', () => {
  test('an interactive session pins the endpoint reading', async ($, on) => {
    const { clock, seen } = stage(on)

    await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
    await clock.settle()

    expect(seen.fetches).toBe(1)
    expect(seen.status.at(-1)).toBe('5h 23% (2h10m 후 리셋) | 7d 41% (3d 5h 후) | 추가 $12.30/$50')
  })

  test('a fresh reading another session cached is used without a fetch', async ($, on) => {
    const cached = { ...parse_usage_body(BODY, NOW - 30_000) }
    const { clock, seen } = stage(on, { reading: cached })

    await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
    await clock.settle()

    expect(seen.fetches).toBe(0)
    expect(seen.status.at(-1)).toContain('추가 $12.30/$50')
  })

  test('the endpoint is read again once the poll interval has passed', async ($, on) => {
    const { clock, seen } = stage(on)

    await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
    await clock.settle()
    await clock.advance(60_000)
    expect(seen.fetches).toBe(1)
    await clock.advance(60_000)
    expect(seen.fetches).toBe(2)
  })

  test('a measured window replaces the 5h figure at once', async ($, on) => {
    const { clock, seen } = stage(on)

    await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
    await clock.settle()
    await $.session.measure({
      context: { window: 200_000 },
      rateLimits: [{ kind: 'five_hour', percentUsed: 57, resetsAt: '2026-10-09T14:10:00Z' }],
      changed: ['rateLimits'],
    })

    expect(seen.status.at(-1)).toContain('5h 57% (2h10m 후 리셋)')
    expect(seen.status.at(-1)).toContain('추가 $12.30/$50')
  })

  test('a -p run pins nothing and fetches nothing', async ($, on) => {
    const { clock, seen } = stage(on)

    await $.session.start({ cwd: '/', surface: null, isInteractive: false })
    await clock.settle()

    expect(seen.fetches).toBe(0)
    expect(seen.status).toEqual([])
  })
})
