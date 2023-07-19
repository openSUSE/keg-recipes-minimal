# Enable NetworkManager services if installed
if rpm -q --whatprovides NetworkManager >/dev/null; then
        systemctl enable NetworkManager
        systemctl enable ModemManager
fi
