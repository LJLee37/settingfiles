import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register, ToolSpec } from 'claude-code'

import type { Board, BoardView, PaneMode } from '../types'
import {
  EMPTY_BOARD,
  EMPTY_VIEW,
  apply_update,
  format_band,
  format_text,
  is_empty,
  pane_rows,
  parse_board,
  type BoardUpdate,
} from './board'

const PANE = 'session-board'
const PANE_TITLE = '세션 보드'
// What the dock is asked for: room for a line of Korean without crowding the chat.
const PANE_COLUMNS = 42
const TOOL = 'mcp__session-board__update'
// Redraws "n분 전".
const TICK_MS = 60_000
// Tools that change something. A read-only Bash call does not count.
const WORK_TOOLS = new Set(['Edit', 'Write', 'NotebookEdit', 'Agent', 'Workflow'])
// Working turns without a write before Claude is reminded: an empty board is
// worth filling at once, a filled one may simply have nothing to change.
const REMIND_EMPTY_AFTER = 1
const REMIND_AFTER = 2

const USAGE = '사용법: /board | /board show | /board goal <내용> | /board add <내용> | /board done <번호>'

const TOOL_SPEC: ToolSpec = {
  name: 'update',
  isDeferred: false,
  description: [
    "Updates this session's board, the status the user keeps on screen beside the conversation:",
    'the goal, what is being done, what waits on someone, what remains, and what is done.',
    'Call it when non-trivial work starts (goal and doneWhen), when a plan is approved (one item per',
    'step), when an item changes state, and when the goal changes (startNewGoal). Skip it for a',
    'question answered in one turn. Fields left out stay as they are; an item with an id is merged',
    'into that item, an item without one is added. Write short text in the language the user works',
    'in. A waiting item needs waitingOn, a done item needs evidence (a commit hash, a test result, a',
    'path, or an approval). Call it with no fields to confirm that nothing changed.',
  ].join(' '),
  inputSchema: {
    type: 'object',
    additionalProperties: false,
    properties: {
      goal: { type: 'string', description: 'The current goal in one line.' },
      doneWhen: { type: 'string', description: 'What makes the goal finished, in one line.' },
      startNewGoal: {
        type: 'boolean',
        description:
          'Moves the current goal and its done items to past goals before setting goal. Leave it out to reword the goal.',
      },
      items: {
        type: 'array',
        items: {
          type: 'object',
          additionalProperties: false,
          properties: {
            id: { type: 'integer', description: 'The item to change; leave it out to add one.' },
            text: { type: 'string' },
            state: { type: 'string', enum: ['doing', 'waiting', 'todo', 'done'] },
            waitingOn: { type: 'string', description: 'Who it waits on, such as 사용자 or 컨트롤 노드.' },
            evidence: { type: 'string', description: 'What shows it is finished.' },
          },
        },
      },
      removeIds: {
        type: 'array',
        items: { type: 'integer' },
        description: 'Items that no longer apply. Finished work is marked done instead.',
      },
    },
  },
}

const viewAtom = atom({ plugin: 'session-board', key: 'view' } as const, EMPTY_VIEW, {
  shape: 'view-1',
})
const tickAtom = atom({ plugin: 'session-board', key: 'tickedAt' } as const, 0)
const modeAtom = atom({ plugin: 'session-board', key: 'paneMode' } as const, 'auto' as PaneMode)

// Every hook that wraps someone else's event ends in `.catch(next)`: a fault in
// the board replays what `next` settled to, so it never costs a tool or a prompt.

// Module state; a reload starts it over, which only delays one reminder.
let isLive = false
let didWork = false
let didUpdate = false
let needsReinject = false
let isOpening = false
// Where the session started, saved into its board so that `session-boards` can
// name the folder to resume it in.
let startCwd: string | undefined
// Board files already made private by this process.
const privatePaths = new Set<string>()

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    // Headless runs (the SDK, `claude -p`) get no tool, no command and no nudges.
    if (e.isInteractive) {
      isLive = true
      startCwd = e.cwd
      await $.command.register({
        name: 'board',
        description: "Open or edit this session's board",
        argumentHint: '[show | goal <text> | add <text> | done <id>]',
      })
      await $.tool.register(TOOL_SPEC)
      await tick($)
      $.clock.every(TICK_MS, () => void tick($))
    }

    return next(e)
  })

  // Counts work and hands the board back after a compaction or a resume, in the
  // middle of a turn too. The board's own tool is answered by the hook below.
  on('tool.call', async ($, e, next) => {
    if (!isLive || e.agentId !== undefined || e.tool === TOOL) {
      return next(e)
    }

    const ran = await next(e)

    if (WORK_TOOLS.has(e.tool) || (e.tool === 'Bash' && ran.isReadOnly !== true)) {
      didWork = true
    }

    if (needsReinject && ran.deny === undefined) {
      const reminder = await take_reinjection($)

      if (reminder !== undefined) {
        return { ...ran, context: [...(ran.context ?? []), reminder] }
      }
    }

    return ran
  }).catch(($, e, next) => next(e))

  on('tool.call', { tool: TOOL }, async ($, e) => {
    if (e.agentId !== undefined) {
      return { deny: 'Only the main session writes the board; report to it instead.' }
    }

    const board = await sync_session($)
    const now = await $.clock.now()
    const applied = apply_update(board, e as unknown as BoardUpdate, now)

    if ('error' in applied) {
      return { deny: applied.error }
    }

    didUpdate = true
    needsReinject = false
    await save_board($, applied.board)

    return { result: format_text(applied.board, now) }
  })

  on('turn.complete', async ($, e, next) => {
    if (isLive && e.agentId === undefined) {
      const isStale = didWork && !didUpdate
      didWork = false
      didUpdate = false

      if (isStale) {
        const board = await sync_session($)
        await save_board($, { ...board, staleTurns: board.staleTurns + 1 })
      }
    }

    return next(e)
  })

  on('prompt.submit', async ($, e, next) => {
    if (!isLive || e.isMeta === true || e.command !== undefined) {
      return next(e)
    }

    const board = await sync_session($)
    const reminder = (await take_reinjection($)) ?? stale_reminder(board)

    return reminder === undefined
      ? next(e)
      : next({ ...e, context: [...(e.context ?? []), reminder] })
  }).catch(($, e, next) => next(e))

  on('session.compact', async ($, e, next) => {
    const compacted = await next(e)

    if (isLive && e.agentId === undefined && e.trigger !== 'precompute' && compacted.messages !== undefined) {
      needsReinject = true
    }

    return compacted
  }).catch(($, e, next) => next(e))

  // A /clear or an in-process resume goes on under another session id with no
  // session.start, so the board is dropped here and loaded again by id.
  on('session.end', async ($, e, next) => {
    if (isLive && (e.reason === 'clear' || e.reason === 'resume')) {
      didWork = false
      didUpdate = false
      needsReinject = false
      await update($, viewAtom, () => EMPTY_VIEW)
      await update($, modeAtom, () => 'auto' as PaneMode)
    }

    return next(e)
  })

  on('command.run', { command: 'board' }, async ($, e) => {
    const [verb = '', ...rest] = e.args.trim().split(/\s+/)
    const text = rest.join(' ')

    if (verb === '') {
      await update($, modeAtom, () => 'asked' as PaneMode)
      const opened = await $.ui.open({ id: PANE, title: PANE_TITLE, columns: PANE_COLUMNS })
      $.ui.invalidate('ui.render')

      return opened.isPlaced
        ? { text: '세션 보드를 열었습니다.' }
        : { text: format_text(await sync_session($), await $.clock.now()) }
    }

    if (verb === 'show') {
      return { text: format_text(await sync_session($), await $.clock.now()) }
    }

    const change = person_change(verb, text)

    if (change === undefined) {
      return { text: USAGE }
    }

    const board = await sync_session($)
    const now = await $.clock.now()
    const applied = apply_update(board, change, now)

    if ('error' in applied) {
      return { text: applied.error }
    }

    // A person's edit says nothing about whether Claude kept the board current.
    await save_board($, { ...applied.board, staleTurns: board.staleTurns })

    const shown = format_text(applied.board, now)

    return { text: shown, context: [`사용자가 /board 로 세션 보드를 고쳤습니다.\n${shown}`] }
  })

  on('ui.close', { id: PANE }, async ($, e, next) => {
    const closed = await next(e)

    if (e.origin.kind === 'person') {
      await update($, modeAtom, () => 'closed' as PaneMode)
    }

    $.ui.invalidate('ui.render')

    return closed
  }).catch(($, e, next) => next(e))

  // Takes the band only while the pane is not on screen, and opens the pane where
  // it would be a sidebar. Width changes re-run this, so a terminal that widens
  // gets the pane back.
  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    if (!isLive || e.props.hasSurvey) {
      return next(e)
    }

    const pane = (await $.ui.panes()).find(one => one.id === PANE)
    const mode = await read($, modeAtom)

    if (pane === undefined && mode === 'auto' && e.viewport?.isFullscreen === true) {
      void open_unasked($)
    }

    if (pane?.isPlaced === true && pane.isShown) {
      return next(e)
    }

    const { board } = await read($, viewAtom)

    if (is_empty(board) && board.staleTurns === 0) {
      return next(e)
    }

    const { Text } = $.ui.resolve(e)
    const now = Math.max(await read($, tickAtom), board.updatedAt)

    return <Text wrap="truncate-end">{format_band(board, now)}</Text>
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    // Too narrow to dock: the person asked for the right side, so an unasked pane
    // gives way to the band instead of sitting above the prompt.
    if (e.props.placement === 'inline' && (await read($, modeAtom)) === 'auto') {
      void $.ui.close({ id: PANE })
    }

    const { board } = await read($, viewAtom)
    const now = Math.max(await read($, tickAtom), board.updatedAt)
    const { Box, Text } = $.ui.resolve(e)

    return (
      <Box flexDirection="column">
        {pane_rows(board, now).map(row => (
          <Text
            bold={row.tone === 'head'}
            dimColor={row.tone === 'dim'}
            color={row.tone === 'warn' ? 'warning' : undefined}
          >
            {row.text}
          </Text>
        ))}
      </Box>
    )
  })
}

function person_change(verb: string, text: string): BoardUpdate | undefined {
  if (text === '') {
    return undefined
  }

  if (verb === 'goal') {
    return { goal: text }
  }

  if (verb === 'add') {
    return { items: [{ text }] }
  }

  const id = Number(text)

  return verb === 'done' && Number.isInteger(id)
    ? { items: [{ id, state: 'done', evidence: '사용자가 완료로 표시' }] }
    : undefined
}

function stale_reminder(board: Board): string | undefined {
  const limit = is_empty(board) ? REMIND_EMPTY_AFTER : REMIND_AFTER

  return board.staleTurns < limit
    ? undefined
    : `세션 보드가 ${board.staleTurns}턴째 갱신되지 않았습니다. 진행 상태가 바뀌었으면 ${TOOL} 로 갱신하고, 바뀐 것이 없으면 인자 없이 호출해 확인하세요. 한 턴에 끝나는 질문이면 무시해도 됩니다.`
}

// The board as Claude last knew it, once, after a compaction or a resume.
async function take_reinjection($: EngineInterface): Promise<string | undefined> {
  if (!needsReinject) {
    return undefined
  }

  needsReinject = false
  const board = await sync_session($)

  return is_empty(board)
    ? undefined
    : `세션 보드의 현재 상태입니다(대화가 요약되거나 재개되어 다시 알립니다).\n${format_text(board, await $.clock.now())}`
}

async function open_unasked($: EngineInterface) {
  if (isOpening) {
    return
  }

  isOpening = true

  try {
    await $.ui.open({ id: PANE, title: PANE_TITLE, columns: PANE_COLUMNS })
    $.ui.invalidate('ui.render')
  } finally {
    isOpening = false
  }
}

async function tick($: EngineInterface) {
  await sync_session($)
  const now = await $.clock.now()
  await update($, tickAtom, () => now)
}

// Brings the view to the current session: a new process, a /clear or a resume.
async function sync_session($: EngineInterface): Promise<Board> {
  const sessionId = await $.session.id()
  const view: BoardView = await read($, viewAtom)

  if (view.sessionId === sessionId) {
    return view.board
  }

  const board = await load_board($, sessionId)
  await update($, viewAtom, () => ({ sessionId, board }))
  needsReinject = !is_empty(board)

  return board
}

async function save_board($: EngineInterface, board: Board) {
  const sessionId = await $.session.id()
  // The first folder stays: a resume has to start from it anyway.
  const saved = board.cwd === undefined && startCwd !== undefined ? { ...board, cwd: startCwd } : board
  await update($, viewAtom, () => ({ sessionId, board: saved }))
  const path = await board_path($, sessionId)

  if (path !== undefined) {
    await $.fs.write(path, `${JSON.stringify(saved, null, 2)}\n`)
    await make_private($, path)
  }
}

// `$.fs.write` takes no mode and a new file comes out 644, while a rewrite keeps
// the mode it finds. So once per path and process: that also tightens a board
// and folder an older version left readable. A failure costs no save.
async function make_private($: EngineInterface, path: string) {
  if (privatePaths.has(path)) {
    return
  }

  privatePaths.add(path)

  try {
    const ran = await $.process.run(['chmod', 'go-rwx', path.slice(0, path.lastIndexOf('/')), path])

    if (ran.exitCode !== 0) {
      $.ui.log(`session-board: chmod ${path} exited ${ran.exitCode}: ${ran.stderr.trim()}`, { to: 'debug' })
    }
  } catch (error) {
    $.ui.log(`session-board: chmod ${path} failed: ${String(error)}`, { to: 'debug' })
  }
}

async function load_board($: EngineInterface, sessionId: string): Promise<Board> {
  const path = await board_path($, sessionId)

  if (path === undefined || !(await $.fs.exists(path))) {
    return EMPTY_BOARD
  }

  const board = parse_board(await $.fs.read(path))

  if (board === null) {
    $.ui.log(`session-board: ${path} is not a board; starting empty`, { to: 'debug' })
  }

  return board ?? EMPTY_BOARD
}

async function board_path($: EngineInterface, sessionId: string): Promise<string | undefined> {
  const home = await $.env.get('HOME')

  return home === undefined ? undefined : `${home}/.claude/session-boards/${sessionId}.json`
}
