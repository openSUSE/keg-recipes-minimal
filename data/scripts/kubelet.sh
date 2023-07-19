#======================================
# Enable kubelet if installed
#--------------------------------------
echo '** Enabling kubelet...'
if [ -e /usr/lib/systemd/system/kubelet.service ]; then
	suseInsertService kubelet
else
echo 'WARNING: kubelet not installed
fi
