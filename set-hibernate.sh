sudo sed -i -e 's/filesystems fsck/filesystems resume fsck/' /etc/mkinitcpio.conf
sudo mkinitcpio -P
sudo sed -i -e 's/quiet/quiet resume=UUID=bc22c8a5-306c-4ad3-81c3-753aff6f562d/' /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg
