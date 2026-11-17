export type ItemState = 'doing' | 'waiting' | 'todo' | 'done'

export type Item = {
  id: number
  text: string
  state: ItemState
  // Who the item waits on; only on a waiting item.
  waitingOn?: string
  // What shows the item is finished; required on a done item.
  evidence?: string
}

export type PastGoal = {
  goal: string
  doneWhen: string
  closedAt: number
  done: Item[]
}

export type Board = {
  version: 1
  goal: string
  doneWhen: string
  items: Item[]
  nextId: number
  pastGoals: PastGoal[]
  // 0 until the first write.
  updatedAt: number
  // Turns that did work without touching the board, since the last write.
  staleTurns: number
  // The folder the session started in, kept from the first save on, so a shell
  // command can say where to resume it after a reboot. Absent before 0.2.0.
  cwd?: string
}

// The input of the mod's tool; loose JSON from the model until apply_update checks it.
export type ItemUpdate = {
  id?: number
  text?: string
  state?: ItemState
  waitingOn?: string
  evidence?: string
}

export type BoardUpdate = {
  goal?: string
  doneWhen?: string
  startNewGoal?: boolean
  items?: readonly ItemUpdate[]
  removeIds?: readonly number[]
}

// The board on screen and the session it belongs to; '' before one is loaded.
export type BoardView = { sessionId: string; board: Board }

// auto: open beside the transcript, never above the prompt.
// asked: the person ran /board, so it stays wherever the surface seats it.
// closed: the person closed it by hand, so it stays closed this session.
export type PaneMode = 'auto' | 'asked' | 'closed'

declare module 'claude-code' {
  // The generated tool types list what was connected at the last save, so a
  // fresh checkout would not know this mod's own tool without this line.
  interface McpToolInputs {
    'mcp__session-board__update': BoardUpdate
  }

  interface PluginState {
    'session-board': {
      view: Shaped<BoardView>
      tickedAt: number
      paneMode: PaneMode
    }
  }
}
