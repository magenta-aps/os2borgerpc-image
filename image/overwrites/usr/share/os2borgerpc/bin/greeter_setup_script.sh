#!/bin/sh
if [ -n "$(users)" ]; then
  exit 0
fi
greeter_setup_scripts=$(find /etc/os2borgerpc/greeter-setup-scripts -mindepth 1)
for file in $greeter_setup_scripts
do
  ./"$file" &
done
