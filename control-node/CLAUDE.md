# CLAUDE.md - 컨트롤 노드

> 이 파일(`~/.claude/CLAUDE.md`)은 settingfiles 의 `install-control-node.sh` 가 `control-node/CLAUDE.md` 에서
> 깝니다. 직접 고치면 다음 실행 때 "다름"으로 나오니, 고칠 것이 있으면 settingfiles 에서 고칩니다.

## 작업에서 알게 된 것은 llm-wiki 에 쌓습니다

`~/gitRepos/llm-wiki`(private, `LJLee37/llm-wiki`)는 Karpathy LLM Wiki 패턴으로 만든 사용자의 개인 위키입니다.
주제는 `obsidian`, `blue-archive`, `personal-knwldge-mngment`, `server` 이고, 규칙(스키마)은 그 저장소의
`CLAUDE.md` 입니다. 장부는 할 일, worklog 는 한 일의 공개 기록, llm-wiki 는 알게 된 것의 비공개 정리입니다.

- **언제**: 작업 도중이라도 위 주제에 맞는 지식이 생기면 그때 후보로 말씀드립니다(조사 결과, 비교, 사건의
  원인과 해결, 결정의 근거, 공식 문서). 작업을 마무리하거나 worklog 를 쓸 때도 빠진 것이 없는지 봅니다.
- **어떻게**: 후보(넣을 자료, 주제, 한 줄 이유)를 먼저 보여 드리고 **사용자가 고른 것만** Ingest 합니다.
  절차는 그 저장소 `CLAUDE.md` 를 따릅니다(자료 하나씩, 요약과 바꿀 페이지 목록을 승인받은 뒤 편집, 커밋,
  push). 이 저장소의 커밋은 서명하지 않으며, 승인 1회로 push 까지 하는 것도 그 저장소 규칙입니다.
- **raw 로 넣는 것**: 외부 문서(URL), 저장소 문서(커밋 해시와 어느 기기의 clone 인지 함께), 세션이 만든 산출물
  파일(조사 보고, 인계 문서). 세션 대화와 Claude 가 쓴 요약은 raw 가 아닙니다(사용자 결정, 2026-10-28).
- **clone 이 여럿입니다**: 이 기기의 clone 말고도 main-server 의 clone(그곳 Claude Code 세션과 헤르메스가 씀)이
  같은 원격에 push 합니다. 시작하기 전에 `git pull --rebase` 로 받고 `git status` 가 깨끗한지 봅니다. 이 기기의
  다른 세션이 남긴 변경이 있으면 건드리지 말고 사용자에게 알립니다. 커밋에는 내가 쓰거나 고친 파일만 `git add`
  합니다.
- 민감 정보는 그 저장소 `CLAUDE.md` 의 목록을 따릅니다. 이 기기에는 vault 평문, `host_vars`, 핸들 파일, 인증서가
  있으니 특히 조심합니다. `server` 주제의 위키는 지도이고, 서버 설정의 기준은 이 기기의 `server-automation`
  clone(정본)과 실제 시스템입니다.
- 같은 절이 노드의 CLAUDE.md(`server-automation` 의 `roles/agentic_coding/templates/CLAUDE.md.j2`)에도 있습니다.
  고칠 때 둘을 맞춥니다.
