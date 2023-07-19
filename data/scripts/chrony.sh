#=====================================
# Enable chrony if installed
#-------------------------------------
echo '** Enabling chronyd...'
if [ -f /etc/chrony.conf ]; then
    systemctl enable chronyd
else
echo '** chrony not installed...'
fi
