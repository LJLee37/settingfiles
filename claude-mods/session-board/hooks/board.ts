import type { Board, BoardUpdate, BoardView, Item, ItemState, ItemUpdate } from '../types'

// Pure board logic: no `$`, so the hooks module and the tests share it.

export const EMPTY_BOARD: Board = {
  version: 1,
  goal: '',
  doneWhen: '',
  items: [],
  nextId: 1,
  pastGoals: [],
  updatedAt: 0,
  staleTurns: 0,
}

export const EMPTY_VIEW: BoardView = { sessionId: '', board: EMPTY_BOARD }

const STATE_ORDER: readonly ItemState[] = ['doing', 'waiting', 'todo', 'done']

const STATE_LABEL: Record<ItemState, string> = {
  doing: '▶ 진행중',
  waiting: '⏸ 기다림',
  todo: '☐ 남음',
  done: '✓ 완료',
}

// Done items the pane lists before it folds the older ones.
const PANE_DONE_LIMIT = 5

export type { BoardUpdate, ItemUpdate }

export type PaneTone = 'head' | 'body' | 'dim' | 'warn'
export type PaneRow = { text: string; tone: PaneTone }

// The tool's input is loose JSON from the model, so every field is checked here.
export function apply_update(
  board: Board,
  input: BoardUpdate,
  now: number,
): { board: Board } | { error: string } {
  const goal = clean_text(input.goal)
  const doneWhen = clean_text(input.doneWhen)

  if (input.startNewGoal === true && goal === undefined) {
    return { error: 'startNewGoal needs goal, the text of the new goal.' }
  }

  let next: Board = { ...board, items: [...board.items], pastGoals: [...board.pastGoals] }

  if (input.startNewGoal === true) {
    next = retire_goal(next, now)
  }

  if (goal !== undefined) {
    next.goal = goal
  }

  if (doneWhen !== undefined) {
    next.doneWhen = doneWhen
  }

  for (const update of input.items ?? []) {
    const applied = apply_item(next, update)

    if ('error' in applied) {
      return applied
    }

    next = applied.board
  }

  for (const id of input.removeIds ?? []) {
    if (!next.items.some(item => item.id === id)) {
      return { error: `removeIds names #${id}, which is not on the board.` }
    }

    next.items = next.items.filter(item => item.id !== id)
  }

  return { board: { ...next, updatedAt: now, staleTurns: 0 } }
}

function retire_goal(board: Board, now: number): Board {
  if (board.goal === '') {
    return board
  }

  const past = {
    goal: board.goal,
    doneWhen: board.doneWhen,
    closedAt: now,
    done: board.items.filter(item => item.state === 'done'),
  }

  return {
    ...board,
    doneWhen: '',
    items: board.items.filter(item => item.state !== 'done'),
    pastGoals: [...board.pastGoals, past],
  }
}

function apply_item(board: Board, update: ItemUpdate): { board: Board } | { error: string } {
  if (update.state !== undefined && !STATE_ORDER.includes(update.state)) {
    return { error: `state must be one of ${STATE_ORDER.join(', ')}, not ${String(update.state)}.` }
  }

  const old = update.id === undefined ? undefined : board.items.find(item => item.id === update.id)

  if (update.id !== undefined && old === undefined) {
    return { error: `#${update.id} is not on the board; leave id out to add an item.` }
  }

  const text = clean_text(update.text) ?? old?.text

  if (text === undefined) {
    return { error: 'A new item needs text.' }
  }

  const state = update.state ?? old?.state ?? 'todo'
  const waitingOn = clean_text(update.waitingOn) ?? old?.waitingOn
  const evidence = clean_text(update.evidence) ?? old?.evidence

  if (state === 'waiting' && waitingOn === undefined) {
    return { error: `"${text}" is waiting, so it needs waitingOn: who it waits on.` }
  }

  if (state === 'done' && evidence === undefined) {
    return { error: `"${text}" is done, so it needs evidence: a commit, a test result, a path or an approval.` }
  }

  const item: Item = {
    id: old?.id ?? board.nextId,
    text,
    state,
    ...(state === 'waiting' ? { waitingOn } : {}),
    ...(evidence === undefined ? {} : { evidence }),
  }

  // An item that just finished moves to the end, so the list stays newest last.
  const justDone = state === 'done' && old?.state !== 'done'
  const rest = board.items.filter(one => one.id !== item.id)
  const items =
    old === undefined || justDone
      ? [...rest, item]
      : board.items.map(one => (one.id === item.id ? item : one))

  return {
    board: { ...board, items, nextId: old === undefined ? board.nextId + 1 : board.nextId },
  }
}

function clean_text(value: unknown): string | undefined {
  if (typeof value !== 'string') {
    return undefined
  }

  const text = value.trim()

  return text === '' ? undefined : text
}

export function is_empty(board: Board): boolean {
  return board.goal === '' && board.items.length === 0
}

// Reads a saved board; anything else is null, and the board starts empty.
export function parse_board(text: string): Board | null {
  try {
    const parsed = JSON.parse(text) as Partial<Board> | null

    return parsed?.version === 1 && Array.isArray(parsed.items) && Array.isArray(parsed.pastGoals)
      ? ({ ...EMPTY_BOARD, ...parsed } as Board)
      : null
  } catch {
    return null
  }
}

export function format_age(ms: number): string {
  const minutes = Math.floor(Math.max(0, ms) / 60_000)

  if (minutes < 1) {
    return '방금'
  }

  if (minutes < 60) {
    return `${minutes}분 전`
  }

  const hours = Math.floor(minutes / 60)

  return hours < 24 ? `${hours}시간 전` : `${Math.floor(hours / 24)}일 전`
}

function format_freshness(board: Board, now: number): string {
  if (board.staleTurns > 0) {
    return `⚠ ${board.staleTurns}턴째 미갱신`
  }

  return board.updatedAt === 0 ? '아직 안 적음' : `${format_age(now - board.updatedAt)} 갱신`
}

function items_in(board: Board, state: ItemState): Item[] {
  return board.items.filter(item => item.state === state)
}

// The one line shown when the pane is not beside the transcript.
export function format_band(board: Board, now: number): string {
  const doing = items_in(board, 'doing')
  const first = doing[0]
  const parts = [`🎯 ${board.goal === '' ? '목표 미정' : board.goal}`]

  if (first !== undefined) {
    parts.push(`▶ ${first.text}${doing.length > 1 ? ` 외 ${doing.length - 1}` : ''}`)
  }

  parts.push(
    `⏸ ${items_in(board, 'waiting').length}`,
    `☐ ${items_in(board, 'todo').length}`,
    `✓ ${items_in(board, 'done').length}`,
    format_freshness(board, now),
  )

  return parts.join(' │ ')
}

function item_line(item: Item): string {
  return item.state === 'waiting'
    ? `#${item.id} ${item.text} [${item.waitingOn ?? '?'}]`
    : `#${item.id} ${item.text}`
}

// The pane's rows, in reading order: what is live first, what is finished last.
export function pane_rows(board: Board, now: number): PaneRow[] {
  const rows: PaneRow[] = []

  if (is_empty(board)) {
    rows.push({ text: '아직 목표가 없습니다.', tone: 'dim' })
  } else {
    rows.push({ text: '목표', tone: 'head' }, { text: board.goal || '미정', tone: 'body' })

    if (board.doneWhen !== '') {
      rows.push({ text: '완료 기준', tone: 'head' }, { text: board.doneWhen, tone: 'body' })
    }
  }

  if (!is_empty(board) || board.staleTurns > 0) {
    rows.push({ text: format_freshness(board, now), tone: board.staleTurns > 0 ? 'warn' : 'dim' })
  }

  for (const state of STATE_ORDER) {
    const items = items_in(board, state)

    if (items.length === 0) {
      continue
    }

    rows.push({ text: ' ', tone: 'body' }, { text: `${STATE_LABEL[state]} ${items.length}`, tone: 'head' })

    const shown = state === 'done' ? items.slice(-PANE_DONE_LIMIT) : items

    for (const item of shown) {
      rows.push({ text: item_line(item), tone: state === 'done' ? 'dim' : 'body' })
    }

    if (items.length > shown.length) {
      rows.push({ text: `외 ${items.length - shown.length}개`, tone: 'dim' })
    }
  }

  if (board.pastGoals.length > 0) {
    rows.push({ text: ' ', tone: 'body' }, { text: `지난 목표 ${board.pastGoals.length}개`, tone: 'dim' })
  }

  return rows
}

// The whole board as text: for the model, and for /board show on any surface.
export function format_text(board: Board, now: number): string {
  if (is_empty(board)) {
    return '세션 보드가 비어 있습니다.'
  }

  const lines = [`목표: ${board.goal || '미정'}`]

  if (board.doneWhen !== '') {
    lines.push(`완료 기준: ${board.doneWhen}`)
  }

  lines.push(format_freshness(board, now))

  for (const state of STATE_ORDER) {
    const items = items_in(board, state)

    if (items.length > 0) {
      lines.push(`${STATE_LABEL[state]}:`)

      for (const item of items) {
        lines.push(`  ${item_line(item)}${item.evidence === undefined ? '' : ` (근거: ${item.evidence})`}`)
      }
    }
  }

  for (const past of board.pastGoals) {
    lines.push(`지난 목표: ${past.goal} (완료 ${past.done.length}개)`)
  }

  return lines.join('\n')
}
