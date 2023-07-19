#======================================
# Enable jeos-firstboot
#--------------------------------------
echo '** Enabling jeos-firstboot...'
mkdir -p /var/lib/YaST2
touch /var/lib/YaST2/reconfig_system

systemctl mask systemd-firstboot.service
systemctl enable jeos-firstboot.service
