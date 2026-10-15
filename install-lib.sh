# install0-disks.sh, install1.sh, install2.sh, luks-fido2.sh 가 source 하는 공통 함수. 직접 실행하지 않습니다.
#
# VM 시험용: UNATTENDED_PASSWORD 가 있으면 LUKS, 사용자, root 비밀번호를 묻지 않고 그 값을 쓰고,
# ASSUME_YES=1 이면 디스크를 지울 때의 확인 질문을 건너뜁니다. 실제 기기에서는 쓰지 마세요.

die() { printf '\n멈춤: %s\n' "$*" >&2; exit 1; }
say() { printf '\n==> %s\n' "$*"; }
is_yes() { [ "${1:-no}" = yes ]; }
need_root() { [ "$(id -u)" -eq 0 ] || die "root 로 돌리세요"; }

# btrfs 서브볼륨과 마운트 위치. 스냅숏(@)을 되돌려도 /home, 로그, 패키지 캐시는 그대로 남게 나눕니다.
SUBVOLS=("@:/" "@home:/home" "@snapshots:/.snapshots" "@var_log:/var/log" "@pkg:/var/cache/pacman/pkg")

load_env() {  # load_env <hosts/기기.env>
  [ -r "$1" ] || die "env 파일이 없음: $1"
  set -a
  # shellcheck disable=SC1090
  . "$1"
  set +a
  : "${HOST_NAME:?env 에 HOST_NAME 이 없음}" "${USERNAME:?}" "${PART_PREFIX:?}"
  : "${TIMEZONE:=Asia/Seoul}" "${LANG_DEFAULT:=en_US.UTF-8}" "${ESP_MIB:=1024}"
  : "${MNT_OPTS:=noatime,compress=zstd}" "${PORTABLE:=no}" "${LUKS:=no}" "${VAULT:=no}"
  : "${LOCALES:=en_US.UTF-8 UTF-8}"
  MAPPER="${PART_PREFIX}-root"            # 설치하는 동안 여는 이름(설치된 시스템 안에서는 root)
  TARGET="/mnt/install-${PART_PREFIX}"   # 설치 대상 마운트 위치(돌고 있는 기기의 /mnt 와 겹치지 않게)
}

disk_path() {  # disk_path <디스크> : 실제 경로로 풀고, 통디스크인지 확인
  local d
  d=$(readlink -f "$1")
  [ -b "$d" ] && [ "$(lsblk -dno TYPE "$d")" = disk ] || die "디스크가 아님: $1"
  printf '%s\n' "$d"
}

check_disk_size() {  # check_disk_size <디스크> : env 의 DISK_BYTES 와 정확히 같아야 함
  local size
  size=$(lsblk -bdno SIZE "$1")
  [ -z "${DISK_BYTES:-}" ] || [ "$size" = "$DISK_BYTES" ] \
    || die "$1 의 크기 $size 바이트가 env 의 DISK_BYTES($DISK_BYTES) 와 다릅니다. 다른 디스크입니다."
}

part_by_label() {  # part_by_label <디스크> <partlabel> : 그 디스크 안의 파티션만 찾음
  lsblk -lnpo NAME,PARTLABEL "$1" | awk -v l="$2" '$2 == l { print $1 }'
}

confirm() {  # confirm <쳐야 할 글자>
  [ "${ASSUME_YES:-0}" = 1 ] && return 0
  local ans
  read -rp "   계속하려면 '$1' 을 그대로 치세요: " ans
  [ "$ans" = "$1" ] || die "취소함"
}

luks_format() {  # luks_format <파티션> <라벨>
  if [ -n "${UNATTENDED_PASSWORD:-}" ]; then
    printf '%s' "$UNATTENDED_PASSWORD" | cryptsetup luksFormat -q --type luks2 --label "$2" --key-file - "$1"
  else
    echo "   이 파티션만의 비밀번호를 정합니다(두 번 묻습니다). 다른 LUKS 파티션과 다르게 하세요."
    cryptsetup luksFormat -q --type luks2 --label "$2" --verify-passphrase "$1"
  fi
}

luks_open() {  # luks_open <파티션> <이름>
  [ -e "/dev/mapper/$2" ] && return 0
  if [ -n "${UNATTENDED_PASSWORD:-}" ]; then
    printf '%s' "$UNATTENDED_PASSWORD" | cryptsetup open --key-file - "$1" "$2"
  else
    cryptsetup open "$1" "$2"
  fi
}

read_list() {  # read_list <목록 파일> : 주석과 빈 줄을 뺀 이름들
  sed -e 's/#.*//' -e 's/[[:space:]]\+$//' "$1" | awk 'NF { print $1 }'
}
