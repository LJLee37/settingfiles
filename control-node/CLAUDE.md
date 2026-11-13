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

## 세션 보드

`session-board` mod 가 세션의 목표, 진행중, 기다림, 남음, 완료를 대화 옆 pane 에 보여 줍니다. pane 이 화면에
없으면 프롬프트 위 한 줄로 보여 줍니다. 내용은 Claude 가 `mcp__session-board__update` 로 적습니다.

- 사소하지 않은 작업은 시작할 때 목표와 완료 기준을 적고, 계획이 승인되면 항목으로 풉니다.
- 항목 상태가 바뀌면 바로 갱신합니다. 완료에는 근거(커밋 해시, 테스트 결과, 경로)를 붙입니다.
- 기다리는 항목에는 누구를 기다리는지(사용자, 노드의 세션) 적습니다.
- 목표가 바뀌면 덮어쓰지 않고 새 목표(`startNewGoal`)로 올립니다.
- 보드는 세션 동안의 현황판입니다. 세션 뒤에도 남길 것은 원래 자리(장부, 인계 문서, llm-wiki)에 따로 적습니다.
- 이 도구가 없는 세션(비대화형 실행, mod 가 설치되지 않은 때)에서는 이 절을 건너뜁니다.
- 터미널이 144칸보다 좁으면 pane 이 저절로 열리지 않습니다. 사용자에게 `/board` 를 한 번 입력하면 열린다고
  알립니다.
- 같은 절이 노드의 CLAUDE.md(`server-automation` 의 `roles/agentic_coding/templates/CLAUDE.md.j2`)에도 있습니다.
  고칠 때 둘을 맞춥니다.

## Arch 위키는 오프라인 사본을 먼저 봅니다

이 기기와 Arch 노드(main-server, raspi)에는 Arch 위키 사본(`arch-wiki-docs`, `arch-wiki-lite`)이 있습니다.
wiki.archlinux.org 는 봇 차단(Anubis)으로 WebFetch 를 거절하므로(2026-11-13), Arch 위키가 필요하면 사본부터 봅니다.

- 찾기: `wiki_width=100 wiki-search <낱말>`. `wiki_width` 를 주면 dialog 메뉴를 띄우지 않고 목록만 찍습니다.
  한국어 문서는 `wiki_lang=ko` 를 함께 줍니다.
- 읽기: 바로 앞 검색의 번호로 `wiki-search <번호>`(텍스트), 또는
  `w3m -dump /usr/share/doc/arch-wiki/html/en/<제목>.html`(제목의 빈칸은 `_`).
- 답할 때 사본의 판(`pacman -Q arch-wiki-docs`, 매달 새 판)을 함께 말합니다. 그 뒤에 바뀌었을 수 있는 내용(패키지
  판, 하드웨어 지원)이 결론을 좌우하면 사용자에게 온라인 위키 확인을 부탁합니다.
- 사람에게 보여 줄 때는 `wiki-search-html <낱말>` 로 엽니다. 이 기기는 GNOME 이라 `xdg-open`(웹 브라우저)으로,
  노드는 화면이 없어 `w3m` 으로 열립니다.
- 같은 절이 노드의 CLAUDE.md(`server-automation` 의 `roles/agentic_coding/templates/CLAUDE.md.j2`)에도 있습니다.
  고칠 때 둘을 맞춥니다.
