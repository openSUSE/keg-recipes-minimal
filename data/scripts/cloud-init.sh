#======================================
# Enable cloud-init if installed
#--------------------------------------
echo '** Enabling cloud-init...'
if [ -e /etc/cloud/cloud.cfg ]; then
    systemctl mask systemd-firstboot.service
    
    systemctl enable cloud-init-local
    systemctl enable cloud-init
    systemctl enable cloud-config
    systemctl enable cloud-final
fi
