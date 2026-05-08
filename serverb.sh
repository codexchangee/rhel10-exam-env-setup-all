#!/bin/bash
set -euo pipefail

current_hostname=$(hostname)
new_hostname="primary.net2.example.com"

if [ "$current_hostname" != "$new_hostname" ]; then
    hostnamectl set-hostname "$new_hostname"
    sed -i "s/$current_hostname/$new_hostname/g" /etc/hosts || true
fi

echo "root:password" | chpasswd

echo "Creating specified users..."

for username in bammbamm; do
    id "$username" &>/dev/null || useradd "$username"
    echo "$username:atenorth" | chpasswd
done

echo "Checking GUI installation..."

if ! rpm -qa | grep -q "gnome-session"; then
    dnf group install -y "Server with GUI" --nobest || true
fi

echo "Creating partition on /dev/sdb..."

if [ ! -b /dev/sdb1 ]; then
cat <<EOF | fdisk /dev/sdb
o
n
p
1

+200M
w
EOF
fi

partprobe || true
sleep 2

echo "Creating LVM..."

pvs | grep -q "/dev/sdb1" || pvcreate /dev/sdb1
vgs | grep -q "myvg" || vgcreate myvg /dev/sdb1
lvs | grep -q "home" || lvcreate -L 100M -n home myvg

blkid /dev/myvg/home | grep -q ext4 || mkfs.ext4 -F /dev/myvg/home

mkdir -p /home

mount | grep -q "/home" || mount /dev/myvg/home /home

grep -q "/dev/myvg/home" /etc/fstab || \
echo "/dev/myvg/home /home ext4 defaults 0 0" >> /etc/fstab

dnf reinstall -y kernel-core || true
dracut -f --regenerate-all || true
grub2-mkconfig -o /boot/grub2/grub.cfg || true

# Show GRUB menu for password reset practice
grub2-editenv - unset menu_auto_hide || true

sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=10/' /etc/default/grub || true
sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/' /etc/default/grub || true

# BIOS systems
if [ -f /boot/grub2/grub.cfg ]; then
    grub2-mkconfig -o /boot/grub2/grub.cfg
fi

# UEFI systems
if [ -f /boot/efi/EFI/redhat/grub.cfg ]; then
    grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg
fi

history -c || true

echo "serverb completed successfully"

# reboot
