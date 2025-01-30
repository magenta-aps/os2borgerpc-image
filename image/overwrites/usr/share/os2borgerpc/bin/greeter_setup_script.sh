#!/bin/sh

greeter_setup_scripts=$(find /etc/os2borgerpc/post-session-scripts -mindepth 1)
for file in $greeter_setup_scripts
do
  ./"$file" &
done
