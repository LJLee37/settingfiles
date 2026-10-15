# 남의 네트워크(카페, 고치러 간 집)에서 쓸 때. 패키지는 base 에 있고 설정만 합니다.
# sshd 는 켜지 않습니다. 누가 켜더라도 비밀번호 로그인은 받지 않게 해 둡니다.
sshd_dropin=/etc/ssh/sshd_config.d/10-settingfiles.conf

post() {
  enable_unit nftables   # Arch 기본 규칙: 들어오는 연결은 이미 맺은 것, lo, ICMP 만(ssh 포트는 sshd 가 꺼져 있어 닫힘)
  if [ -f "$sshd_dropin" ]; then
    ok "$sshd_dropin"
  else
    printf '# settingfiles profiles/outside.sh\nPasswordAuthentication no\nKbdInteractiveAuthentication no\n' \
      | as_root install -Dm644 /dev/stdin "$sshd_dropin"
    did "$sshd_dropin"
  fi
}

check() {
  if systemctl is-enabled -q nftables 2>/dev/null; then ok nftables; else todo "nftables 꺼져 있음"; fi
  if [ -f "$sshd_dropin" ]; then ok "$sshd_dropin"; else todo "$sshd_dropin 없음"; fi
  if systemctl is-enabled -q sshd 2>/dev/null; then todo "sshd 가 켜져 있음(의도한 것인지 확인)"; else ok "sshd 꺼져 있음"; fi
}
