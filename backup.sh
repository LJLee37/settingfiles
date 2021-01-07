curdate = $(date +%F%Z)
sudo tar -cvpzf backup-$curdate.tar.gz --exclude=/home/ljlee/backup*.tar.gz --one-file-system /
sudo tar -cvpzf backup-firmware-$curdate.tar.gz --exclude=/home/ljlee/backup*.tar.gz --one-file-system /boot/firmware
scp backup-$curdate.tar.gz 192.168.35.203:
scp backup-firmware-$curdate.tar.gz 192.168.35.203:
echo Backup complete!
