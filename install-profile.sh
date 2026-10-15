#!/bin/bash
# 용도별 프로필을 깝니다. 프로필은 profiles/<이름>.txt(패키지, "aur:이름" 은 AUR)와
# profiles/<이름>.sh(설정, 있을 때만)입니다. 다시 돌리면 빠진 것만 채웁니다.
#
#   ./install-profile.sh gnome steam        설치(보통 사용자로: sudo 를 부르고 AUR 까지)
#   ./install-profile.sh --check gnome      아무것도 바꾸지 않고 빠진 것만 보여 줌
#   ./install-profile.sh --list             프로필 목록
#
# root 로 돌면(예: 설치 중 chroot) AUR 패키지는 건너뜁니다. 첫 부팅 뒤 사용자로 다시 돌리면 채워집니다.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
. ./install-lib.sh

CHECK=0
case "${1:-}" in
  --check) CHECK=1; shift ;;
  --list)
    for f in profiles/*.txt profiles/*.sh; do basename "${f%.*}"; done | sort -u | while read -r p; do
      printf '%-10s %s\n' "$p" "$(sed -n '1s/^# *//p' "profiles/$p.txt" 2>/dev/null || sed -n '1s/^# *//p' "profiles/$p.sh")"
    done
    exit 0 ;;
  ""|-h|--help) sed -n 2,10p "$0"; exit 64 ;;
esac
[ $# -ge 1 ] || { sed -n 2,10p "$0"; exit 64; }

ok() { printf '   됨    %s\n' "$*"; }
todo() { printf '   필요  %s\n' "$*"; }
did() { printf '   바꿈  %s\n' "$*"; }
if [ "$(id -u)" -eq 0 ]; then as_root() { "$@"; }; else as_root() { sudo "$@"; }; fi
in_chroot() { systemd-detect-virt -q --chroot; }

# 프로필 .sh 에서 쓰는 도우미
enable_unit() {  # 켜져 있으면 둠. chroot 안에서는 --now 없이(다음 부팅부터)
  if systemctl is-enabled -q "$1" 2>/dev/null; then ok "$1"; return 0; fi
  if in_chroot; then as_root systemctl enable -q "$1"; else as_root systemctl enable -q --now "$1"; fi
  did "$1 켬"
}
enable_multilib() {  # 패키지는 뒤의 pacman -Syu 가 받음
  if grep -q '^\[multilib\]' /etc/pacman.conf; then ok multilib; return 0; fi
  as_root sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
  did "multilib 켬(/etc/pacman.conf)"
}

run_hook() {  # run_hook <프로필> <pre|post|check>
  [ -f "profiles/$1.sh" ] || return 0
  # shellcheck disable=SC1090
  ( . "profiles/$1.sh"; if declare -F "$2" >/dev/null; then "$2"; fi )
}

repo=() aur=()
for p in "$@"; do
  [ -f "profiles/$p.txt" ] || [ -f "profiles/$p.sh" ] || die "그런 프로필이 없음: $p (--list 로 확인)"
  [ -f "profiles/$p.txt" ] || continue
  for n in $(read_list "profiles/$p.txt"); do
    case $n in aur:*) aur+=("${n#aur:}") ;; *) repo+=("$n") ;; esac
  done
done

missing=""
[ ${#repo[@]} -eq 0 ] || missing=$(pacman -T "${repo[@]}" | awk '!seen[$0]++' | tr '\n' ' ' || true)
aur_missing=()
for a in "${aur[@]}"; do pacman -Q "$a" >/dev/null 2>&1 || aur_missing+=("$a"); done

if [ "$CHECK" -eq 1 ]; then
  say "프로필: $*"
  if [ -z "${missing// }" ]; then ok "pacman 패키지 ${#repo[@]}개"; else todo "pacman: $missing"; fi
  for a in "${aur[@]}"; do
    if pacman -Q "$a" >/dev/null 2>&1; then ok "$a (AUR)"; else todo "$a (AUR)"; fi
  done
  for p in "$@"; do run_hook "$p" check; done
  exit 0
fi

say "프로필: $*"
for p in "$@"; do run_hook "$p" pre; done
if [ -n "${missing// }" ]; then
  # 동기화와 업그레이드를 같이 합니다(-Syu). -Sy 만 하고 깔면 반쯤 업그레이드된 시스템이 됩니다.
  # shellcheck disable=SC2086
  as_root pacman -Syu --needed --noconfirm $missing
  did "pacman: $missing"
else
  ok "pacman 패키지 ${#repo[@]}개"
fi

if [ ${#aur_missing[@]} -gt 0 ]; then
  if [ "$(id -u)" -eq 0 ]; then
    todo "AUR 는 root 로 빌드할 수 없어 건너뜀: ${aur_missing[*]} (첫 부팅 뒤 사용자로 다시 돌리세요)"
  else
    for a in "${aur_missing[@]}"; do
      dir="$HOME/aur/$a"
      [ -d "$dir/.git" ] || git clone -q "https://aur.archlinux.org/$a.git" "$dir"
      (cd "$dir" && makepkg -si --needed --noconfirm)
      did "$a (AUR)"
    done
  fi
fi

for p in "$@"; do run_hook "$p" post; done
