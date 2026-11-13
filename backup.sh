dest="${BACKUP_DEST:?set BACKUP_DEST=user@host:/path/ to the backup target (kept out of this public repo)}"
curdate=$(date +%F%Z)
sudo tar -cvpzf backup-$curdate.tar.gz --exclude=/home/ljlee/backup*.tar.gz --one-file-system /
sudo tar -cvpzf backup-firmware-$curdate.tar.gz --exclude=/home/ljlee/backup*.tar.gz --one-file-system /boot/firmware
scp backup-$curdate.tar.gz "$dest"
scp backup-firmware-$curdate.tar.gz "$dest"
echo Backup complete!
