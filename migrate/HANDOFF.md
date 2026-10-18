# 인계: 컨트롤 카드(LJTF) 재설치 - main-server 에서 백업하고 다시 깔기

2026-10-16 컨트롤 노드 세션(settingfiles)이 썼습니다. 받는 쪽은 main-server 의 Claude 세션입니다.
비밀값은 없습니다. 이 폴더(`migrate/`)는 재설치가 끝나면 지웁니다.

## 1. 무엇을 왜

컨트롤 노드 LJTF 는 **SD 카드**(238.3G, USB 리더)이고 어느 컴퓨터에 꽂아도 내 환경으로 켜지게 쓰는 기기입니다.
지금은 f2fs 루트에 암호화가 없고, 다른 컴퓨터에서 안 켜질 수 있는 initramfs 입니다. 이것을
**ESP | vault | LUKS2 루트 -> btrfs 서브볼륨** 으로 다시 깝니다. 예비 카드가 없어 같은 카드에 다시 깝니다.
그래서 먼저 카드를 통째로 NAS 에 떠 두고(되돌릴 길), 그다음에 지웁니다.

사용자가 정한 것:
- 모든 LUKS 파티션은 **그 파티션만의 비밀번호, FIDO2 토큰 A, 토큰 B** 세 가지로 열립니다. 비밀번호는 파티션마다 다릅니다.
- vault(옛 sda2, LUKS2)에는 **마스터 SSH 키와 GPG 마스터 키**가 있습니다. 비트 그대로 새 카드로 옮깁니다.
- 백업: 카드 전체 이미지와 vault 이미지는 NAS, vault 와 보존 파일은 USB(SanDisk 14G)에도. USB 의 `driftline*` 폴더 둘은 지워도 됨.
- 보존 목록 밖(Steam, Tabletop Simulator, .factorio, aur, Claude 데스크탑 캐시, discord, 캐시)은 버립니다.
  Downloads 의 Windows ISO 는 NAS 로.

설치 스크립트는 settingfiles `arch` 브랜치에 있고, 컨트롤 노드에서 VM 으로 미리 돌려 봤습니다(카드와 같은
크기의 디스크에 install0 -> install1 -> 재실행 -> 프로필 -> 부팅, LUKS 비밀번호, snapper, USB 와 NVMe 로 부팅).
VM 에서 못 해 본 것은 FIDO2 등록뿐입니다(토큰이 필요).

## 2. 지킬 것

- **vault 는 main-server 에서 열지 않습니다.** 복사본 확인은 sha256 대조와 LUKS 헤더(`luksDump`)로만 합니다.
  토큰 등록(`luks-fido2.sh`)도 vault 의 키를 메모리에 올리므로 main-server 가 아니라 **카드로 부팅한 노트북에서** 합니다.
- **main-server 의 디스크를 건드리지 않습니다.** 카드는 PTUUID `c33836cb-9215-46a4-b97d-bead0e3c121a`, 크기
  255869321216 바이트로 찾습니다. install0/1 은 env 의 `DISK_BYTES` 와 크기가 다르면 멈추고, 마운트되거나 열린
  파티션이 있는 디스크는 지우지 않습니다.
- **`~/gitRepos/settingfiles` 의 브랜치를 바꾸지 마세요.** main-server 의 닷파일(`main-server` 브랜치)이고 `.zshrc`
  등이 그 안을 가리킵니다. `arch` 는 따로 받습니다(아래 3.1).
- 비밀번호, LUKS 비밀번호, 토큰 PIN 은 **사용자가 직접** 칩니다. 묻는 명령은 사용자가 tmux 같은 실제 터미널에서
  돌리고, 이 세션은 명령을 알려 주고 결과를 확인합니다.
- `~/handoffs/logs/` 의 예전 `--diff` 로그에 평문 토큰이 있었던 적이 있습니다. 백업은 공개되는 곳에 두지 않습니다
  (백업 폴더는 700, USB 는 실물).
- server-automation 에 서명을 기다리는 커밋 `cc7c111`(브랜치 `todo-1016`, TODO 와 docs/hermes)이 있을 수 있습니다.
  카드를 끄기 전에 push 되지 않았다면 백업의 `gitRepos/server-automation/.git` 안에 있습니다. 새 카드에서
  `.git/land-1016a.sh sign` 으로 이어 갑니다.

## 3. 순서

### 3.1 준비 (사용자)

1. 노트북(카드)을 끄고, 카드(USB 리더째)와 USB(SanDisk 14G)를 main-server 에 꽂습니다.
2. main-server 에서:
   ```bash
   git clone -b arch https://github.com/LJLee37/settingfiles.git ~/ljtf-rebuild
   cd ~/ljtf-rebuild
   lsblk -o NAME,SIZE,TRAN,PTUUID,FSTYPE,UUID     # 카드: PTUUID c33836cb-..., USB: UUID 490cd184-...
   ls -l /dev/disk/by-id/ | grep -v part          # 카드의 by-id 경로를 적어 둠(아래 <CARD>)
   ```

### 3.2 백업 (사용자가 돌리고, 이 세션이 확인) - 1~2 시간

```bash
sudo ./migrate/backup-old-card.sh /srv/server-migration/ljtf-card-2026-10-16   # 위치는 /srv 정리 방침에 맞게
```
카드 전체 이미지(+ 압축본을 풀어 sha256 대조), vault 이미지(+ 대조, 헤더만), 보존 파일 tar 두 개, Windows ISO,
USB 사본(+ 대조)을 만듭니다. 하나라도 어긋나면 멈춥니다. **끝까지 "끝" 이 나와야 3.3 으로 갑니다.**
Windows ISO 는 백업 폴더에 들어가니, NAS 에 ISO 를 두는 자리가 있으면 그리로 옮기세요.

### 3.3 설치 (사용자) - 여기서부터 옛 카드가 지워집니다

```bash
B=/srv/server-migration/ljtf-card-2026-10-16
sudo ./install0-disks.sh hosts/ljtf.env /dev/disk/by-id/<CARD> $B/vault.img
#   크기(238.3G)를 그대로 치고, 새 루트 LUKS 비밀번호를 두 번 칩니다(vault 와 다른 것)
sudo ./install1.sh hosts/ljtf.env /dev/disk/by-id/<CARD>
#   pacstrap 뒤 ljlee 와 root 비밀번호를 묻습니다. ljlee 는 옛 로그인 비밀번호와 같게 하면 키링이 그대로 열립니다
sudo arch-chroot /mnt/install-ljtf /home/ljlee/gitRepos/settingfiles/install-profile.sh \
     portable nvidia outside rescue snapshots gnome steam apps
#   AUR(claude-desktop)은 root 라 건너뜀. 첫 부팅 뒤 채웁니다
```

### 3.4 파일 되살리기 (사용자)

```bash
T=/mnt/install-ljtf
sudo arch-chroot $T id -u ljlee                  # 1000 이어야 함(옛 카드와 같음)
zstd -dc $B/files.tar.zst  | sudo tar --numeric-owner --xattrs --acls -C $T/home/ljlee -xf -
zstd -dc $B/system.tar.zst | sudo tar --numeric-owner --xattrs --acls -C $T -xf -
sudo umount -R $T && sudo cryptsetup close ljtf-root
```

### 3.5 첫 부팅 (사용자, 노트북)

카드를 노트북에 꽂고 켭니다(GRUB 5 초, LUKS 비밀번호, GDM). ljlee 로:
```bash
cd ~/gitRepos/settingfiles
./set.sh                                   # zsh, oh-my-zsh, p10k 와 글꼴, 닷파일 심링크, nvm
git pull --ff-only                         # print 프로필(프린터, 스캐너)과 설치 스크립트 수정을 받음
./install-profile.sh portable nvidia outside rescue snapshots gnome steam apps print   # AUR claude-desktop, brlaser
./install-control-node.sh                  # claude-code, 서명, 인증서, github.com 블록, gh 로그인 안내
sudo ./luks-fido2.sh                       # 루트와 vault 에 토큰 A, B 등록 후 토큰마다 열어 보기
sudo mkinitcpio -P                         # 기본 이미지를 이 노트북에 맞춤(선택)
```
그다음 `claude` 를 켜면 되살린 `~/.claude` 에서 이 작업의 기억을 이어받습니다.

## 4. 잘못되면

- 3.3 전: 카드는 그대로입니다. 고쳐서 다시 하면 됩니다.
- 3.3 뒤 어디서든: 옛 카드를 그대로 되돌릴 수 있습니다.
  ```bash
  zstd -dc $B/card.img.zst | sudo dd of=/dev/disk/by-id/<CARD> bs=4M conv=fsync status=progress
  ```
- install0 을 다시 돌리려면 먼저 `sudo umount -R /mnt/install-ljtf; sudo cryptsetup close ljtf-root`.

## 5. 끝난 뒤

- 새 카드로 며칠 써 보고 문제가 없으면 `card.img.zst` 와 `files.tar.zst` 는 지웁니다(옛 카드는 암호화가 없어
  그 안의 비밀값이 평문입니다). `vault.img` 는 암호화돼 있으니 마스터 키의 예비 사본으로 남겨도 됩니다.
- settingfiles 에서 `migrate/` 를 지우는 커밋.
