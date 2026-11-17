import type { EngineInterface, Register } from 'claude-code'

import {
  EMPTY_READING,
  adopt_reading,
  apply_rate_limits,
  format_line,
  parse_usage_body,
  type Reading,
} from './usage'

// The endpoint `/usage` reads; it is the only source of the extra-usage spend.
const USAGE_URL = 'https://api.anthropic.com/api/oauth/usage'
const OAUTH_BETA = 'oauth-2025-04-20'
// The last endpoint reading, shared by every session of this machine.
const CACHE_KEY = 'reading'
// How often the line is redrawn so the reset countdown stays current.
const TICK_MS = 60_000

// Module state; a hot reload starts it over and session.start fills it again.
let reading: Reading = EMPTY_READING
let pollMs = 120_000
let isLive = false
let isFetching = false

export const register: Register = (on, options) => {
  pollMs = Math.max(30, Number(options.pollSeconds ?? 120)) * 1000

  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'usage-meter',
      description: 'Re-read the 5-hour, weekly and extra-credit usage now',
    })

    if (e.isInteractive) {
      isLive = true
      const usage = await $.session.usage()
      reading = apply_rate_limits(reading, usage.rateLimits, await $.clock.now())
      await draw($)
      $.clock.after(0, () => void refresh($, false))
      $.clock.every(TICK_MS, () => void tick($))
    }

    return next(e)
  })

  on('session.measure', async ($, e, next) => {
    if (e.changed.includes('rateLimits')) {
      reading = apply_rate_limits(reading, e.rateLimits, await $.clock.now())
      await draw($)
    }

    return next(e)
  })

  on('command.run', { command: 'usage-meter' }, async $ => {
    await refresh($, true)
    const line = format_line(reading, await $.clock.now())

    return { text: line ?? 'Usage is not available (no subscription login, or the endpoint did not answer).' }
  })
}

async function draw($: EngineInterface) {
  if (isLive) {
    $.ui.status(format_line(reading, await $.clock.now()))
  }
}

async function tick($: EngineInterface) {
  const now = await $.clock.now()

  if (now - reading.fetchedAt >= pollMs) {
    await refresh($, false)
  } else {
    await draw($)
  }
}

// Reads the shared cache, and the endpoint when the cache is older than the
// poll interval (or when forced); failures keep the last reading.
async function refresh($: EngineInterface, isForced: boolean) {
  if (isFetching) {
    return
  }

  isFetching = true

  try {
    const now = await $.clock.now()
    const cached = (await $.store.get(CACHE_KEY)) as Reading | undefined

    if (cached !== undefined) {
      reading = adopt_reading(reading, cached)
    }

    if (!isForced && now - reading.fetchedAt < pollMs) {
      return
    }

    const auth = await $.session.authorize()

    if (auth === null || auth.kind !== 'bearer') {
      return
    }

    const response = await $.http.fetch(USAGE_URL, {
      headers: { 'anthropic-beta': OAUTH_BETA },
      auth: auth.handle,
    })

    if (!response.ok) {
      $.ui.log(`usage endpoint answered ${response.status}`, { to: 'debug' })
      return
    }

    const fetched = parse_usage_body(JSON.parse(response.text), now)
    reading = adopt_reading(reading, fetched)
    await $.store.set(CACHE_KEY, fetched)
  } catch (error) {
    $.ui.log(`usage refresh failed: ${String(error)}`, { to: 'debug' })
  } finally {
    isFetching = false
    await draw($)
  }
}
