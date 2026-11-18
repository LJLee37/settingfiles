# 관리 권한에 FIDO2 토큰 터치 요구 (pam-u2f)

작성: 2026-11-18, LJGaming 의 Claude Code(사용자 지시: "pam-u2f는 별도의 문서로 만들어서 다음에도 알 수 있게"). LJGaming 에 처음 적용한
날은 2026-11-18 이고, 명령과 결과의 원본은 `~/waydroid-setup-log.md` 의 "관리 권한에 FIDO2 터치 요구" 절과 `~/install-logs/root-20261118-pam-u2f-*` 입니다.

## 무엇을, 왜

- **무엇:** `sudo` 와 polkit(`pkexec`, 데스크톱의 관리자 비밀번호 창)이 **로그인 비밀번호 다음에 FIDO2 토큰(A 또는 B) 터치**를 요구합니다.
- **왜:** 로그인 비밀번호가 약해도, 토큰이 없으면 관리 권한을 얻지 못하게 하려는 것입니다. wheel 그룹은 그대로 둡니다.
- **그대로 두는 것:** 로그인 화면(GDM, plasma-login-manager), `su`, 콘솔 로그인은 바꾸지 않습니다. 토큰을 둘 다 잃으면 `su -` 와 **root 비밀번호**가 비상구입니다.
  root 비밀번호를 정해 두지 않은 기기에는 적용하지 않습니다.

## 준비물

- 패키지: `pam-u2f`(공식 저장소, LJGaming 은 1.4.0-3). `libfido2` 는 base 프로필에 있습니다.
- 토큰 두 개(A, B). 하나만 등록하면 그 토큰을 잃는 순간 root 비밀번호로만 들어갈 수 있습니다.
- 데스크톱에 앉은 사용자. 등록할 때 토큰을 터치해야 하고, 적용할 때 비밀번호 창이 데스크톱 화면에 뜹니다.

## 절차

1. **설치** (root): `pacman -S pam-u2f`.
2. **토큰 등록** (사용자, 터미널에서 토큰을 하나씩 꽂고 터치):
   ```bash
   pamu2fcfg -u ljlee -o pam://<기기이름> -i pam://<기기이름> > ~/u2f_mappings.new      # 토큰 A
   pamu2fcfg -n -o pam://<기기이름> -i pam://<기기이름> >> ~/u2f_mappings.new           # 토큰 B(같은 줄 뒤에 붙음)
   ```
   - `-o`(origin)와 `-i`(appid)는 기기마다 다르게 둡니다(LJGaming 은 `pam://LJGaming`). 다른 기기의 등록 정보로는 통과하지 못합니다.
   - 결과는 한 줄이어야 합니다: `ljlee:<자격 A>:<자격 B>`. 줄이 둘로 나뉘면 B 를 `-n` 없이 만든 것입니다.
3. **등록 정보를 root 소유로 둠** (root): `install -m644 -o root -g root ~/u2f_mappings.new /etc/u2f_mappings`.
   - **함정:** pam-u2f 의 기본 위치 `~/.config/Yubico/u2f_keys` 에 두면 안 됩니다. 사용자 홈의 파일이라, 약한 비밀번호로 로그인한 사람이 자기 토큰을
     등록해 바꿔칠 수 있습니다. 그래서 `authfile=/etc/u2f_mappings`(root 소유)를 씁니다.
4. **PAM 에 한 줄 더함** (root). 비밀번호 줄(`auth include system-auth`) **다음**에 둡니다.
   ```
   auth       required     pam_u2f.so authfile=/etc/u2f_mappings cue origin=pam://<기기이름> appid=pam://<기기이름>
   ```
   - `/etc/pam.d/sudo`: 원본을 `sudo.bak-<날짜>` 로 떠 두고 `auth include system-auth` 아래에 넣습니다.
   - `/etc/pam.d/polkit-1`: `/etc` 에는 없고 `/usr/lib/pam.d/polkit-1` 만 있습니다. 그 내용을 `/etc/pam.d/polkit-1` 로 복사해 같은 줄을 넣습니다.
     이 파일을 지우면 패키지 기본값(`/usr/lib/pam.d/polkit-1`)으로 돌아갑니다.
   - `cue` 는 "토큰을 터치하세요" 안내를 띄웁니다.
5. **잠기지 않게 안전장치를 먼저 켬** (root, 4와 같은 스크립트 맨 앞):
   ```bash
   systemd-run --on-active=15min --unit=pam-u2f-rollback \
     /bin/sh -c 'cp -a /etc/pam.d/sudo.bak-<날짜> /etc/pam.d/sudo; rm -f /etc/pam.d/polkit-1'
   ```
   15분 안에 시험이 통과하지 않으면 저절로 되돌아갑니다.
6. **시험하고 안전장치 끄기** (데스크톱에서): `pkexec systemctl stop pam-u2f-rollback.timer`. 비밀번호 창에 비밀번호를 넣고 이어서 토큰을
   터치해 통과하면, 그 명령이 되돌리기 타이머를 끕니다(LJGaming: 2026-11-18 14:02, 통과).
7. **더 시험할 것:** 토큰을 뺀 채 `sudo -k; sudo true` 는 비밀번호가 맞아도 실패해야 하고, 토큰을 꽂으면 비밀번호 + 터치로 통과해야 합니다.

## 쓸 때 알아 둘 것

- **토큰이 없으면 비밀번호가 틀린 것처럼 보입니다.** pam_u2f 가 실패해도 화면에는 "비밀번호가 틀렸다"고만 나옵니다. pkexec 나 sudo 를 쓰기 전에
  토큰부터 꽂습니다(Claude Code 는 pkexec 를 돌리기 전에 사용자에게 꽂아 달라고 말함).
- **root 작업은 한 스크립트로 묶습니다.** 비밀번호와 터치를 한 번에 끝내기 위해서입니다. 스크립트가 중간에 실패해 다시 돌리면 터치가 한 번 더 듭니다.
- **Claude Code 의 `! sudo` 로는 비밀번호를 넣을 수 없어** `pkexec /usr/bin/bash <스크립트>` 로 돌립니다(데스크톱의 비밀번호 창).
- **SSH 의 FIDO2 키(sk 키)와는 별개입니다.** 같은 토큰을 쓰지만, ssh 는 토큰 안의 자기 자격으로 PIN 과 터치를 묻고 이 PAM 설정과 상관이 없습니다.

## 토큰을 바꾸거나 더할 때

- 새 토큰을 꽂고 `pamu2fcfg -n -o pam://<기기이름> -i pam://<기기이름>` 의 출력(`:` 로 시작)을 `/etc/u2f_mappings` 의 그 줄 끝에 붙입니다(root).
- 잃은 토큰은 그 줄에서 해당 자격(`:` 사이 한 덩어리)을 지웁니다. 어느 것이 어느 토큰인지 모르면 남은 토큰들로 줄을 새로 만듭니다.

## 되돌리기

- `/etc/pam.d/sudo` 를 `sudo.bak-<날짜>` 로 되돌리고 `/etc/pam.d/polkit-1` 을 지웁니다. 패키지(`pam-u2f`)와 `/etc/u2f_mappings` 는 남겨도 영향이 없습니다.
- 토큰을 모두 잃어 sudo 도 pkexec 도 안 되면: `su -`(root 비밀번호)로 위를 합니다. root 비밀번호도 모르면 설치 USB 로 부팅해 `arch-chroot` 에서 합니다.

## LJGaming 의 현재 상태 (2026-11-18)

| 항목 | 값 |
| --- | --- |
| 패키지 | pam-u2f 1.4.0-3 (snapper 35, 36) |
| 등록 정보 | `/etc/u2f_mappings` root 0644, ljlee 한 줄, 토큰 A, B 두 자격(es256, +presence) |
| origin / appid | `pam://LJGaming` |
| 바꾼 파일 | `/etc/pam.d/sudo`(백업 `sudo.bak-20261118`), `/etc/pam.d/polkit-1`(새 파일) |
| 그대로 | GDM, plasma-login-manager 로그인, `su`, 콘솔 로그인 |
| 스크립트와 로그 | `~/install-logs/root-20261118-pam-u2f-install.sh`, `root-20261118-pam-u2f-enable.sh`(와 `.log`) |
