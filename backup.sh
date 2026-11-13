# Adapted from the raspi (Raspberry Pi OS) branch's backup.sh: ALARM
# mounts the boot partition at /boot directly, not /boot/firmware.
dest="${BACKUP_DEST:?set BACKUP_DEST=user@host:/path/ to the backup target (kept out of this public repo)}"
curdate=$(date +%F%Z)
sudo tar -cvpzf backup-$curdate.tar.gz --exclude=/home/ljlee/backup*.tar.gz --one-file-system /
sudo tar -cvpzf backup-boot-$curdate.tar.gz --exclude=/home/ljlee/backup*.tar.gz --one-file-system /boot
scp backup-$curdate.tar.gz "$dest"
scp backup-boot-$curdate.tar.gz "$dest"
echo Backup complete!
