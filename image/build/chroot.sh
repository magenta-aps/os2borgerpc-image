#!/bin/bash

 set -x

printf "\n\n%s\n\n" "===== RUNNING: $0 ====="

DIR=$1
COMMAND=$2 # Optional command
ARGS=( "${@:3}" ) # Additional optional arguments

if [ -z "$DIR" ] || [ ! -d "$DIR" ]; then
    echo "$DIR does not exist or is not a directory"
    exit 1
fi

# For debugging
echo "Command is: $COMMAND"
echo "Args for the command are: ${ARGS[*]}"

# Set up resolv.conf
sudo cp /etc/resolv.conf squashfs-root/run/systemd/resolve/stub-resolv.conf

echo "Chroot'ing into what will be the filesystem on the OS2BorgerPC"
if [ -z "$COMMAND" ]; then
    sudo chroot "$DIR"
else
    EXE=$(basename "$COMMAND")
    sudo cp "$COMMAND" "$DIR"
    sudo chmod +x $DIR/$EXE
    sudo chroot "$DIR" /"$EXE" "${ARGS[@]}"
fi
