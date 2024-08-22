#!/usr/bin/env bash

set -e

# Install dbus-x11 for dbus-launch from .deb file
dpkg -i /etc/os2borgerpc/*.deb

# Secure GRUB as GRUB should now be fully installed, unlike at the time the image is being created
/usr/share/os2borgerpc/bin/grub_set_password.py "$(pwgen -N 1 -s 12)"

# Detect the locale chosen under the installation and rename "Borger" if not Danish
# Locale file may or may not contain " around the value of LANG
LOCALE=$(grep LANG /etc/default/locale | cut --delimiter '=' --fields 2 | tr --delete '"' | cut --delimiter '_' --fields 1)
if [ "$LOCALE" = "sv" ]; then
    usermod --comment 'Medborgare' user
elif [ "$LOCALE" = "en" ]; then
    usermod --comment 'Citizen' user
fi

# Copy over superuser desktop shortcuts - they're activated by a .config/autostart script

USR="superuser"
DESKTOP_FILES_DIR="/usr/share/os2borgerpc/superuser-desktop"

export "$(grep LANG= /etc/default/locale | tr --delete '"')"
runuser -u $USR xdg-user-dirs-update
DESKTOP=$(runuser -u $USR xdg-user-dir DESKTOP)

mv $DESKTOP_FILES_DIR/*.desktop "$DESKTOP/"
chown --recursive superuser:superuser "$DESKTOP"
chmod --recursive u+x "$DESKTOP"

rm --recursive $DESKTOP_FILES_DIR

# Setup delayed start of unattended upgrades
TIME_TO_START=$(date -d 'now+2hours' +%FT%R)
mkdir --parents "/usr/local/lib/os2borgerpc"
UNATTENDED_UPGRADES_DELAY="/usr/local/lib/os2borgerpc/unattended_upgrades_delay.py"
UNATTENDED_UPGRADES_DELAY_SERVICE="/etc/systemd/system/os2borgerpc-unattended_upgrades_delay.service"
START_UNATTENDED_UPGRADES="/usr/local/lib/os2borgerpc/start_unattended_upgrades.sh"
cat <<EOF > $UNATTENDED_UPGRADES_DELAY
#!/usr/bin/env python3

import datetime
import time
import subprocess

TIME_TO_START = datetime.datetime.fromisoformat("$TIME_TO_START")

def main():
    while True:
        time.sleep(60)
        NOW = datetime.datetime.now()
        if NOW > TIME_TO_START:
            # Setup unattended upgrades
            subprocess.call("$START_UNATTENDED_UPGRADES")
            break

if __name__ == "__main__":
    main()
EOF

chmod 700 $UNATTENDED_UPGRADES_DELAY

cat <<EOF > $START_UNATTENDED_UPGRADES
#!/usr/bin/env bash

# setup unattended upgrades
"/etc/os2borgerpc/apt_periodic_control.sh" security

# disable the delay service
systemctl disable "$(basename $UNATTENDED_UPGRADES_DELAY_SERVICE)"

# delete the related files
rm --force $UNATTENDED_UPGRADES_DELAY $UNATTENDED_UPGRADES_DELAY_SERVICE $START_UNATTENDED_UPGRADES \
           /etc/os2borgerpc/apt_periodic_control.sh
EOF

chmod 700 $START_UNATTENDED_UPGRADES

cat <<EOF > $UNATTENDED_UPGRADES_DELAY_SERVICE
[Unit]
Description=OS2borgerPC delay unattended upgrades service

[Service]
Type=simple
ExecStart=$UNATTENDED_UPGRADES_DELAY

[Install]
WantedBy=multi-user.target
EOF

systemctl enable --now "$(basename $UNATTENDED_UPGRADES_DELAY_SERVICE)"

# We remove the following programs here, because they're not installed during install_dependencies.sh(?!) so we can't remove them there
apt-get remove --assume-yes --purge deja-dup kdeconnect remmina transmission-gtk

# Finally: Remove firstboot and its files
sed --in-place "/firstboot.sh/d" /etc/gdm3/Init/Default
rm "$0" /etc/os2borgerpc/*.deb /usr/share/os2borgerpc/bin/grub_set_password.py
