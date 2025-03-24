#!/usr/bin/env sh

# Removing thunderbird during image building or in the post-install script does not work
# for some reason so we remove it here
snap remove thunderbird

rm --force /etc/os2borgerpc/post-session-scripts/first-logout.sh
