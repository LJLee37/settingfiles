curdate=$(date +%F%Z)
sudo tar -cvpzf backup-$curdate.tar.gz --exclude=/home/ljlee/backup*.tar.gz --one-file-system /
sudo tar -cvpzf backup-firmware-$curdate.tar.gz --exclude=/home/ljlee/backup*.tar.gz --one-file-system /boot/firmware
scp backup-$curdate.tar.gz ljlee@server.ljlee37.com:/srv/netatalk/PersonalData/RpiBackups/
scp backup-firmware-$curdate.tar.gz ljlee@server.ljlee37.com:/srv/netatalk/PersonalData/RpiBackups/
echo Backup complete!
