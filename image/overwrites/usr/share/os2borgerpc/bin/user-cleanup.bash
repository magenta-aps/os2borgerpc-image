#!/bin/bash

# This script cleans up the users home directory.

# We need to set PATH to ensure that the script works correctly when run by gdm
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/snap/bin

USERNAME="user"

# Determine the name of the user desktop directory. This is done via xdg-user-dir,
# which checks the /home/user/.config/user-dirs.dirs file. To ensure this file exists,
# we run xdg-user-dirs-update, which generates it based on the environment variables
# LANG and LANGUAGE. These variables are empty on the login screen so we first export them
# based on the values stored in /etc/default/locale
export "$(grep LANG= /etc/default/locale | tr -d '"')"
runuser -u $USERNAME xdg-user-dirs-update
DESKTOP=$(runuser -u $USERNAME xdg-user-dir DESKTOP)

chattr -i "$DESKTOP"

# Kill all processes started by user
pkill -KILL -u user

# Find all files/directories owned by user in the world-writable directories
FILES_DIRS=$(find /tmp/ /var/tmp/ /var/crash/ /var/metrics/ /var/lock/ -user user)

rm --recursive --force /dev/shm/* /dev/shm/.??* /home/$USERNAME $FILES_DIRS
# Remove pending print jobs
PRINTERS=$(lpstat -p | grep printer | awk '{ print $2; }')

for PRINTER in $PRINTERS
do
    lprm -P $PRINTER -
done

# Restore user crontab
crontab -u user /etc/os2borgerpc/usercron

# Remove possible scheduled at commands
if [ -f /usr/bin/at ]; then
  atq | cut --fields 1 | xargs --no-run-if-empty atrm
fi

# Disable airplane mode unless they're using ethernet
if ! nmcli c show --active | grep --quiet "ethernet" && nmcli r wifi | grep --quiet "disabled"; then
  nmcli r all on
fi

# Restore $HOME
rsync -vaz /home/.skjult/ /home/$USERNAME/
chown -R $USERNAME:$USERNAME /home/$USERNAME
/usr/share/os2borgerpc/bin/gio-fix-desktop-file-permissions.sh

# Make the desktop read only to user
chown -R root:$USERNAME "$DESKTOP"
chattr +i "$DESKTOP"
# The exact cause is unclear, but xdg-user-dir will rarely fail in such
# a way that DESKTOP=/home/user. The lines below prevent this error
# from causing login issues.
chattr -i /home/user/
chown $USERNAME:$USERNAME /home/$USERNAME
chown -R $USERNAME:$USERNAME /home/$USERNAME/.config /home/$USERNAME/.local
