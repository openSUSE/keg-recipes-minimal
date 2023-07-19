#======================================
# Configure Raspberry Pi specifics
#--------------------------------------
echo '** Configure RaspberryPi specifics...'
if [[ "$kiwi_profiles" == *"RaspberryPi"* ]]; then
    # Add necessary kernel modules to initrd (will disappear with bsc#1084272)
    echo 'add_drivers+=" bcm2835_dma dwc2 "' > /etc/dracut.conf.d/raspberrypi_modules.conf

    # Add necessary kernel modules to initrd (will disappear with boo#1162669)
    echo 'add_drivers+=" pcie-brcmstb "' >> /etc/dracut.conf.d/raspberrypi_modules.conf

    # Work around network issues
    cat > /etc/modprobe.d/50-rpi3.conf <<-EOF
        # Prevent too many page allocations (bsc#1012449)
        options smsc95xx turbo_mode=N
    EOF

    cat > /usr/lib/sysctl.d/50-rpi3.conf <<-EOF
        # Avoid running out of DMA pages for smsc95xx (bsc#1012449)
        vm.min_free_kbytes = 2048
    EOF
else
    echo 'WARNING: Could not find profile named with RaspberryPi'
fi


