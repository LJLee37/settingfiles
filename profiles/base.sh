# base 프로필 설정. 새 기기는 install1.sh 가 base.txt 를 pacstrap 하고 install2.sh 가 서비스를 켭니다. 이미 깔린
# 기기에 base.txt 에 새로 더한 것을 채울 때(./install-profile.sh base) 그 서비스도 켭니다.
#
# kernel-modules-hook: pacman -Syu 가 커널을 올리면 돌고 있는 커널의 /usr/lib/modules/<판> 이 지워져 재부팅 전까지
# 새 모듈을 못 올립니다. 훅이 그 디렉터리를 떠 두었다가 되살리고, linux-modules-cleanup.service 가 다음 부팅에
# 쓰지 않는 판을 /usr/lib/modules/.old 로 옮깁니다(4주 뒤 지움).
post() {
  enable_unit linux-modules-cleanup.service
}

check() {
  if systemctl is-enabled -q linux-modules-cleanup.service 2>/dev/null; then ok linux-modules-cleanup.service
  else todo "linux-modules-cleanup.service 꺼짐"; fi
}
