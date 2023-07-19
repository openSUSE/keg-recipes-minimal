#======================================
# Enable firewalld if installed
#--------------------------------------d
if [ -x /usr/sbin/firewalld ]; then
        systemctl enable firewalld.service
    # punch firewall to allow cockpit ws access
    firewall-offline-cmd --add-service cockpit
fi
~           
