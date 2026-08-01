# Adapted from the raspi (Raspberry Pi OS) branch's backup.sh: ALARM
# mounts the boot partition at /boot directly, not /boot/firmware.
curdate=$(date +%F%Z)
sudo tar -cvpzf backup-$curdate.tar.gz --exclude=/home/ljlee/backup*.tar.gz --one-file-system /
sudo tar -cvpzf backup-boot-$curdate.tar.gz --exclude=/home/ljlee/backup*.tar.gz --one-file-system /boot
scp backup-$curdate.tar.gz 192.168.35.203:Downloads/
scp backup-boot-$curdate.tar.gz 192.168.35.203:Downloads/
echo Backup complete!
