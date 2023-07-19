#======================================
# Configure SelfInstall specifics
#--------------------------------------
echo '** Configure SelfInstall specifics...'
if [[ "$kiwi_profiles" == *"SelfInstall"* ]]; then
    cat > /etc/systemd/system/selfinstallreboot.service <<-EOF
    [Unit]
    Description=SelfInstall Image Reboot after Firstboot (to ensure ignition and such runs)
    After=systemd-machine-id-commit.service
    Before=jeos-firstboot.service
    
    [Service]
    Type=oneshot
    ExecStart=rm /etc/systemd/system/selfinstallreboot.service
    ExecStart=rm /etc/systemd/system/default.target.wants/selfinstallreboot.service
    ExecStart=systemctl --no-block reboot

    [Install]
    WantedBy=default.target
    EOF
    ln -s /etc/systemd/system/selfinstallreboot.service /etc/systemd/system/default.target.wants/selfinstallreboot.service
else
    echo 'WARNING: Could not find profile named with SelfInstall'
fi

