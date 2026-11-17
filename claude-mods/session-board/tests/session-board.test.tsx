import { describe, expect, mock, test } from 'claude-code/testing'
import type { On } from 'claude-code'

import type { Board } from '../types'
import {
  EMPTY_BOARD,
  apply_update,
  format_age,
  format_band,
  format_text,
  pane_rows,
  parse_board,
  type BoardUpdate,
} from '../hooks/board'

const NOW = Date.parse('2026-11-03T12:00:00Z')
const TOOL = 'mcp__session-board__update'
const FILE = '/home/t/.claude/session-boards/s1.json'

function applied(board: Board, input: BoardUpdate, now = NOW): Board {
  const result = apply_update(board, input, now)

  if ('error' in result) {
    throw new Error(result.error)
  }

  return result.board
}

const SAMPLE = applied(EMPTY_BOARD, {
  goal: '세션 현황 제안',
  doneWhen: '사용자가 방식을 고름',
  items: [
    { text: '제안서 작성', state: 'doing' },
    { text: '승인', state: 'waiting', waitingOn: '사용자' },
    { text: 'mod 구현' },
    { text: '실측', state: 'done', evidence: '세션 12개 측정' },
  ],
})

describe('apply_update', () => {
  test('adds items with increasing ids and leaves omitted fields alone', () => {
    expect(SAMPLE.items.map(item => item.id)).toEqual([1, 2, 3, 4])

    const next = applied(SAMPLE, { items: [{ id: 3, state: 'doing' }] })

    expect(next.goal).toBe('세션 현황 제안')
    expect(next.items.find(item => item.id === 3)?.text).toBe('mod 구현')
    expect(next.nextId).toBe(5)
  })

  test('a waiting item needs waitingOn, a done item needs evidence', () => {
    expect(apply_update(SAMPLE, { items: [{ id: 3, state: 'waiting' }] }, NOW)).toEqual({
      error: expect.stringContaining('waitingOn'),
    })
    expect(apply_update(SAMPLE, { items: [{ id: 3, state: 'done' }] }, NOW)).toEqual({
      error: expect.stringContaining('evidence'),
    })
  })

  test('leaving waiting drops waitingOn', () => {
    const next = applied(SAMPLE, { items: [{ id: 2, state: 'doing' }] })

    expect(next.items.find(item => item.id === 2)?.waitingOn).toBeUndefined()
  })

  test('an item that finishes moves to the end, newest last', () => {
    const next = applied(SAMPLE, { items: [{ id: 1, state: 'done', evidence: 'abc123' }] })

    expect(next.items.map(item => item.id)).toEqual([2, 3, 4, 1])
  })

  test('a new goal retires the old one with its done items and keeps open work', () => {
    const next = applied(SAMPLE, { goal: '배포', startNewGoal: true })

    expect(next.goal).toBe('배포')
    expect(next.doneWhen).toBe('')
    expect(next.pastGoals[0]?.goal).toBe('세션 현황 제안')
    expect(next.pastGoals[0]?.done.map(item => item.id)).toEqual([4])
    expect(next.items.map(item => item.id)).toEqual([1, 2, 3])
  })

  test('rewording the goal retires nothing', () => {
    const next = applied(SAMPLE, { goal: '세션 현황 방안' })

    expect(next.pastGoals).toEqual([])
    expect(next.items.length).toBe(4)
  })

  test('startNewGoal without a goal is an error', () => {
    expect(apply_update(SAMPLE, { startNewGoal: true }, NOW)).toEqual({
      error: expect.stringContaining('goal'),
    })
  })

  test('unknown ids and states are errors, and an empty update is a confirmation', () => {
    expect('error' in apply_update(SAMPLE, { items: [{ id: 99, text: 'x' }] }, NOW)).toBe(true)
    expect('error' in apply_update(SAMPLE, { removeIds: [99] }, NOW)).toBe(true)
    expect('error' in apply_update(SAMPLE, { items: [{ text: 'x', state: 'nope' as 'todo' }] }, NOW)).toBe(true)

    const stale = { ...SAMPLE, staleTurns: 3 }
    const confirmed = applied(stale, {}, NOW + 1000)

    expect(confirmed.staleTurns).toBe(0)
    expect(confirmed.updatedAt).toBe(NOW + 1000)
    expect(confirmed.items).toEqual(SAMPLE.items)
  })

  test('removeIds drops an item', () => {
    expect(applied(SAMPLE, { removeIds: [3] }).items.map(item => item.id)).toEqual([1, 2, 4])
  })
})

describe('formatting', () => {
  test('the band is one line with what is live and the counts', () => {
    expect(format_band(SAMPLE, NOW + 120_000)).toBe(
      '🎯 세션 현황 제안 │ ▶ 제안서 작성 │ ⏸ 1 │ ☐ 1 │ ✓ 1 │ 2분 전 갱신',
    )
  })

  test('the band says when the board is behind', () => {
    expect(format_band({ ...SAMPLE, staleTurns: 3 }, NOW)).toContain('⚠ 3턴째 미갱신')
  })

  test('ages step from minutes to hours to days', () => {
    expect(format_age(10_000)).toBe('방금')
    expect(format_age(45 * 60_000)).toBe('45분 전')
    expect(format_age(3 * 3_600_000)).toBe('3시간 전')
    expect(format_age(50 * 3_600_000)).toBe('2일 전')
  })

  test('the pane lists live work before finished work, and folds old done items', () => {
    let board = SAMPLE

    for (let n = 0; n < 6; n += 1) {
      board = applied(board, { items: [{ text: `일 ${n}`, state: 'done', evidence: 'x' }] })
    }

    const texts = pane_rows(board, NOW).map(row => row.text)

    expect(texts.indexOf('▶ 진행중 1')).toBeLessThan(texts.indexOf('⏸ 기다림 1'))
    expect(texts.indexOf('☐ 남음 1')).toBeLessThan(texts.indexOf('✓ 완료 7'))
    expect(texts).toContain('#2 승인 [사용자]')
    expect(texts).toContain('외 2개')
  })

  test('the text form carries evidence and past goals', () => {
    const text = format_text(applied(SAMPLE, { goal: '배포', startNewGoal: true }), NOW)

    expect(text).toContain('지난 목표: 세션 현황 제안 (완료 1개)')
    expect(format_text(SAMPLE, NOW)).toContain('#4 실측 (근거: 세션 12개 측정)')
  })

  test('a saved board reads back, and anything else is null', () => {
    expect(parse_board(JSON.stringify(SAMPLE))).toEqual(SAMPLE)
    expect(parse_board('not json')).toBeNull()
    expect(parse_board('{"version":2,"items":[],"pastGoals":[]}')).toBeNull()
  })
})

// The world beneath the mod: a session id, a file system held in memory, and a
// pane list the test sets. Records what the mod opened, closed and registered.
function stage(
  on: On,
  files: Record<string, string> = {},
  panes: { value: unknown[] } = { value: [] },
  runExit = 0,
) {
  mock.clock(on, { now: NOW })
  mock.env(on, { HOME: '/home/t' })
  const seen = {
    tools: [] as string[],
    commands: [] as string[],
    opened: 0,
    closed: 0,
    contexts: [] as string[][],
    runs: [] as string[][],
  }

  on('process.run', ($, e) => {
    seen.runs.push([...e.argv])
    const stderr = runExit === 0 ? '' : 'Operation not permitted'
    return { value: { exitCode: runExit, stdout: '', stderr, isStdoutTruncated: false, isStderrTruncated: false } }
  })

  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('session.id', () => ({ value: 's1' }))
  on('tool.register', ($, e) => {
    seen.tools.push(e.name)
    return { value: { tool: `mcp__session-board__${e.name}` } }
  })
  on('command.register', ($, e) => {
    seen.commands.push(e.name)
    return { value: { command: e.name } }
  })
  on('fs.exists', ($, e) => ({ value: e.path in files }))
  on('fs.read', ($, e) => ({ value: files[e.path] ?? '' }))
  on('fs.write', ($, e) => {
    files[e.path] = e.text
    return { value: undefined }
  })
  on('ui.panes', () => ({ value: panes.value as never }))
  on('ui.open', () => {
    seen.opened += 1
    return { value: { isPlaced: true } }
  })
  on('ui.close', () => {
    seen.closed += 1
    return { value: undefined }
  })
  on('ui.invalidate', () => ({ value: undefined }))
  on('ui.log', () => ({ value: undefined }))
  on('tool.call', () => ({ result: {} }))
  on('turn.complete', ($, e) => ({ text: e.answer }))
  on('prompt.submit', ($, e) => {
    seen.contexts.push([...(e.context ?? [])])
    return { text: e.text }
  })

  return seen
}

const ORIGIN = { kind: 'composer' } as const
const PRESENTATION = { isFullscreen: true, columns: 200 }

function prompt(text: string) {
  return { text, wait: true, origin: ORIGIN } as never
}

function command(args: string) {
  return { command: 'board', args, origin: ORIGIN, presentation: PRESENTATION } as const
}

const INTERACTIVE = { cwd: '/', surface: 'terminal', isInteractive: true } as const
const SHOWN_PANE = { id: 'session-board', title: '세션 보드', isShown: true, isFocused: false, isPlaced: true }

const BAND = {
  plugin: 'session-board',
  component: 'AbovePrompt',
  surface: 'terminal',
  requestId: 'band',
  props: {
    hasSurvey: false,
    isWorking: false,
    maxRows: 5,
    bodyColumns: 100,
    scroll: { offset: 0, bodyRows: 5 },
    view: {},
  },
} as const

function pane_mount(placement: 'dock' | 'inline') {
  return {
    plugin: 'session-board',
    component: 'Pane',
    surface: 'terminal',
    requestId: 'session-board',
    props: {
      title: '세션 보드',
      isFocused: false,
      bodyColumns: 42,
      placement,
      scroll: { offset: 0, bodyRows: 40 },
      view: {},
    },
  } as const
}

test('a headless session gets no tool and no command', async ($, on) => {
  const seen = stage(on)

  await $.session.start({ cwd: '/', surface: null, isInteractive: false })

  expect(seen.tools).toEqual([])
  expect(seen.commands).toEqual([])
})

test('the tool saves the board by session id and answers with it', async ($, on) => {
  const files: Record<string, string> = {}
  const seen = stage(on, files)

  await $.session.start(INTERACTIVE)
  expect(seen.tools).toEqual(['update'])

  const ran = await $.tool.call({ tool: TOOL, goal: '목표 하나', items: [{ text: '일', state: 'doing' }] })

  expect(ran.text ?? JSON.stringify(ran.result)).toContain('목표 하나')
  expect(parse_board(files[FILE] ?? '')?.items[0]?.text).toBe('일')
})

test('the board keeps the folder the session started in', async ($, on) => {
  const files: Record<string, string> = {}
  stage(on, files)

  await $.session.start({ ...INTERACTIVE, cwd: '/home/t/proj' })
  await $.tool.call({ tool: TOOL, goal: '목표' })

  expect(parse_board(files[FILE] ?? '')?.cwd).toBe('/home/t/proj')
})

test('a resume elsewhere keeps the first folder', async ($, on) => {
  const files: Record<string, string> = { [FILE]: JSON.stringify({ ...SAMPLE, cwd: '/home/t/first' }) }
  stage(on, files)

  await $.session.start({ ...INTERACTIVE, cwd: '/home/t/second' })
  await $.tool.call({ tool: TOOL, items: [{ id: 3, state: 'doing' }] })

  expect(parse_board(files[FILE] ?? '')?.cwd).toBe('/home/t/first')
})

test('a board without a folder, from 0.1.0, gets one on its next save', async ($, on) => {
  const files: Record<string, string> = { [FILE]: JSON.stringify(SAMPLE) }
  stage(on, files)

  await $.session.start({ ...INTERACTIVE, cwd: '/home/t/proj' })
  await $.tool.call({ tool: TOOL })

  expect(parse_board(files[FILE] ?? '')?.cwd).toBe('/home/t/proj')
  expect(parse_board(files[FILE] ?? '')?.items).toEqual(SAMPLE.items)
})

test('the board file and folder are made private once per process', async ($, on) => {
  const files: Record<string, string> = {}
  const seen = stage(on, files)

  await $.session.start(INTERACTIVE)
  await $.tool.call({ tool: TOOL, goal: '목표' })
  await $.tool.call({ tool: TOOL, items: [{ text: '일' }] })

  expect(seen.runs).toEqual([['chmod', 'go-rwx', '/home/t/.claude/session-boards', FILE]])
})

test('a chmod that fails does not cost the save', async ($, on) => {
  const files: Record<string, string> = {}
  const seen = stage(on, files, { value: [] }, 1)

  await $.session.start(INTERACTIVE)
  const ran = await $.tool.call({ tool: TOOL, goal: '목표 하나' })

  expect(seen.runs.length).toBe(1)
  expect(ran.deny).toBeUndefined()
  expect(parse_board(files[FILE] ?? '')?.goal).toBe('목표 하나')
})

test('a bad update is refused and changes nothing', async ($, on) => {
  const files: Record<string, string> = {}
  stage(on, files)

  await $.session.start(INTERACTIVE)
  const ran = await $.tool.call({ tool: TOOL, items: [{ text: '일', state: 'done' }] })

  expect(ran.deny).toContain('evidence')
  expect(files[FILE]).toBeUndefined()
})

test('a subagent cannot write the board', async ($, on) => {
  const files: Record<string, string> = {}
  stage(on, files)

  await $.session.start(INTERACTIVE)
  const ran = await $.tool.call({ tool: TOOL, goal: '남의 목표', agentId: 'a1' })

  expect(ran.deny).toContain('main session')
  expect(files[FILE]).toBeUndefined()
})

test('working turns without a write count up and remind, and a write clears them', async ($, on) => {
  const files: Record<string, string> = {}
  const seen = stage(on, files)
  const turn = { answer: '', durationMs: 1, isAborted: false, turnId: 't', reason: 'answer' } as const

  await $.session.start(INTERACTIVE)
  await $.tool.call({ tool: TOOL, goal: '목표' })
  await $.turn.complete(turn)

  await $.tool.call({ tool: 'Edit', file_path: 'a', old_string: 'a', new_string: 'b' })
  await $.turn.complete(turn)
  await $.prompt.submit(prompt('다음'))
  expect(seen.contexts.at(-1)).toEqual([])

  await $.tool.call({ tool: 'Write', file_path: 'a', content: 'b' })
  await $.turn.complete(turn)
  await $.prompt.submit(prompt('다음'))
  expect(seen.contexts.at(-1)?.[0]).toContain('2턴째')

  await $.tool.call({ tool: TOOL })
  await $.turn.complete(turn)
  expect(parse_board(files[FILE] ?? '')?.staleTurns).toBe(0)
})

test('a turn that only read things does not count as stale', async ($, on) => {
  const files: Record<string, string> = {}
  stage(on, files)
  const turn = { answer: '', durationMs: 1, isAborted: false, turnId: 't', reason: 'answer' } as const

  await $.session.start(INTERACTIVE)
  await $.tool.call({ tool: TOOL, goal: '목표' })
  await $.turn.complete(turn)
  await $.tool.call({ tool: 'Read', file_path: 'a' })
  await $.turn.complete(turn)

  expect(parse_board(files[FILE] ?? '')?.staleTurns).toBe(0)
})

test('a resumed session gets its board back, and Claude reads it once', async ($, on) => {
  const seen = stage(on, { [FILE]: JSON.stringify(SAMPLE) })

  await $.session.start(INTERACTIVE)
  await $.prompt.submit(prompt('이어서'))
  await $.prompt.submit(prompt('또'))

  expect(seen.contexts[0]?.[0]).toContain('세션 현황 제안')
  expect(seen.contexts[1]).toEqual([])
})

test('a broken file starts an empty board', async ($, on) => {
  const seen = stage(on, { [FILE]: 'not json' })

  await $.session.start(INTERACTIVE)
  await $.prompt.submit(prompt('이어서'))

  expect(seen.contexts[0]).toEqual([])
})

test('/board goal and add edit the board and tell Claude', async ($, on) => {
  const files: Record<string, string> = {}
  stage(on, files)

  await $.session.start(INTERACTIVE)
  await $.command.run(command('goal 사용자가 정한 목표'))
  const added = await $.command.run(command('add 할 일 하나'))

  expect(added.text).toContain('사용자가 정한 목표')
  expect(added.context?.[0]).toContain('할 일 하나')
  expect(parse_board(files[FILE] ?? '')?.items[0]?.text).toBe('할 일 하나')
})

test('/board done marks an item, and a bad argument prints usage', async ($, on) => {
  const files: Record<string, string> = {}
  stage(on, files)

  await $.session.start(INTERACTIVE)
  await $.tool.call({ tool: TOOL, goal: '목표', items: [{ text: '일' }] })
  await $.command.run(command('done 1'))

  expect(parse_board(files[FILE] ?? '')?.items[0]?.state).toBe('done')
  expect((await $.command.run(command('done x'))).text).toContain('사용법')
  expect((await $.command.run(command('show'))).text).toContain('#1 일')
})

test('the band shows while the pane is off screen and yields while it is up', async ($, on) => {
  const panes = { value: [] as unknown[] }
  stage(on, { [FILE]: JSON.stringify(SAMPLE) }, panes)
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>engine</Text>
  })

  await $.session.start(INTERACTIVE)

  const closed = await $.ui.mount({ ...BAND, viewport: { columns: 100, rows: 40, isFullscreen: false } })
  expect((await closed.find({ type: 'Text' }))?.text).toContain('🎯 세션 현황 제안')
  await closed.unmount()

  panes.value = [SHOWN_PANE]

  const open = await $.ui.mount({ ...BAND, viewport: { columns: 200, rows: 40, isFullscreen: true } })
  expect((await open.find({ type: 'Text' }))?.text).toBe('engine')
  await open.unmount()
})

test('the pane opens by itself only where it would be a sidebar', async ($, on) => {
  const seen = stage(on)
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>engine</Text>
  })

  await $.session.start(INTERACTIVE)

  const main = await $.ui.mount({ ...BAND, viewport: { columns: 200, rows: 40, isFullscreen: false } })
  await main.unmount()
  expect(seen.opened).toBe(0)

  const full = await $.ui.mount({ ...BAND, viewport: { columns: 200, rows: 40, isFullscreen: true } })
  await full.unmount()
  expect(seen.opened).toBe(1)
})

test('an unasked pane seated above the prompt closes itself, an asked one stays', async ($, on) => {
  const seen = stage(on, { [FILE]: JSON.stringify(SAMPLE) })

  await $.session.start(INTERACTIVE)

  const unasked = await $.ui.mount(pane_mount('inline'))
  await unasked.unmount()
  expect(seen.closed).toBe(1)

  await $.command.run(command(''))

  const asked = await $.ui.mount(pane_mount('inline'))
  await asked.unmount()
  expect(seen.closed).toBe(1)
})

test('the pane draws the board', async ($, on) => {
  stage(on, { [FILE]: JSON.stringify(SAMPLE) })

  await $.session.start(INTERACTIVE)

  const ui = await $.ui.mount(pane_mount('dock'))
  expect((await ui.find({ type: 'Text', text: /승인 \[사용자\]/ }))?.text).toBe('#2 승인 [사용자]')
  await ui.unmount()
})
