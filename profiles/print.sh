# Printer and scanner setup: CUPS, .local name lookup, and the mDNS opening in the firewall.
nsswitch=/etc/nsswitch.conf
nftables_conf=/etc/nftables.conf

post() {
  enable_unit cups.socket
  enable_unit avahi-daemon.service
  # Printer URIs such as ipp://name.local need mDNS lookups (ArchWiki "Avahi").
  if grep -qE '^hosts:.*mdns' "$nsswitch"; then
    ok "$nsswitch mdns"
  else
    as_root sed -i -E '/^hosts:/s/[[:space:]](resolve|files)([[:space:]]|$)/ mdns_minimal [NOTFOUND=return] \1\2/' "$nsswitch"
    if grep -qE '^hosts:.*mdns' "$nsswitch"; then did "$nsswitch: mdns_minimal"; else todo "$nsswitch 의 hosts 줄에 mdns_minimal 을 손으로 넣으세요"; fi
  fi
  # The Arch default ruleset drops new inbound packets, and mDNS answers arrive as new UDP to port 5353.
  if [ ! -f "$nftables_conf" ] || grep -qF 'udp dport mdns accept' "$nftables_conf"; then
    ok "$nftables_conf mDNS"
  else
    as_root sed -i '/comment "allow icmp"$/a\    udp dport mdns accept comment "allow mDNS (printer and scanner discovery)"' "$nftables_conf"
    if ! grep -qF 'udp dport mdns accept' "$nftables_conf"; then
      todo "$nftables_conf 에 mDNS 규칙을 넣지 못했습니다(allow icmp 줄이 없음). 'udp dport mdns accept' 를 손으로 넣으세요"
    else
      # In a chroot nft would talk to the installing host's kernel, so only load on the running system.
      # Arch's nftables.service (1.1.7-3) is a oneshot without RemainAfterExit or ExecReload: it shows
      # inactive after boot and cannot reload, so load the file directly when the unit is enabled.
      if ! in_chroot && systemctl is-enabled -q nftables 2>/dev/null; then as_root nft -f "$nftables_conf"; fi
      did "$nftables_conf: mDNS(UDP 5353) 받음"
    fi
  fi
}

check() {
  local u
  for u in cups.socket avahi-daemon.service; do
    if systemctl is-enabled -q "$u" 2>/dev/null; then ok "$u"; else todo "$u 꺼져 있음"; fi
  done
  if grep -qE '^hosts:.*mdns' "$nsswitch"; then ok "$nsswitch mdns"; else todo "$nsswitch 에 mdns 없음"; fi
  if [ -f "$nftables_conf" ] && ! grep -qF 'udp dport mdns accept' "$nftables_conf"; then
    todo "$nftables_conf 에 mDNS 규칙 없음"
  else
    ok "$nftables_conf mDNS"
  fi
}
