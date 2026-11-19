# portable 프로필 설정(2026-11-19). TF 카드나 USB 처럼 느리고 쓰기 수명이 짧은 저장장치에서 도는 기기용입니다.
# - KDE 의 파일 색인기 Baloo 를 끕니다. Plasma 첫 로그인에 홈 전체의 내용을 색인하며 색인 파일에 계속 써서, LJTF(USB 리더의
#   TF 카드)에서는 카드에 초당 약 4 MiB 를 쉬지 않고 쓰는 동안 앱과 메뉴가 굼떴습니다. 이미 만든 색인
#   (~/.local/share/baloo)은 지우지 않습니다(사용자 결정). 파일 이름 검색은 Dolphin 에서 색인 없이도 됩니다.
#   다시 켜려면 balooctl6 enable.
# - 사용자 설정이라 root(설치 중 chroot)에서는 건너뜁니다.
baloo_off() { [ "$(kreadconfig6 --file baloofilerc --group 'Basic Settings' --key 'Indexing-Enabled' 2>/dev/null)" = false ]; }
post() {
  command -v balooctl6 >/dev/null || { ok "Baloo 없음(Plasma 를 깔지 않음)"; return 0; }
  if [ "$(id -u)" -eq 0 ]; then todo "Baloo 끄기는 첫 부팅 뒤 사용자로 다시 돌릴 때 함"; return 0; fi
  if baloo_off; then ok "Baloo 꺼짐"; else
    balooctl6 disable >/dev/null
    did "Baloo 끔(이미 만든 색인은 그대로 둠)"
  fi
}
check() {
  command -v balooctl6 >/dev/null || { ok "Baloo 없음(Plasma 를 깔지 않음)"; return 0; }
  if [ "$(id -u)" -eq 0 ]; then todo "Baloo 는 사용자로 돌려 확인함"; return 0; fi
  if baloo_off; then ok "Baloo 꺼짐"; else todo "Baloo 켜져 있음(느린 저장장치에 색인을 씀)"; fi
}
