#!/usr/bin/env bash

AUTOMATIC_REGISTRATION_CONFIG="/etc/os2borgerpc/automatic_registration_config"
ADMIN_URL_FILE="/etc/os2borgerpc/admin-url"
AUTOMATIC_REGISTRATION_SERVICE="/etc/systemd/system/os2borgerpc-automatic_registration.service"

# xargs is used to remove possible spaces around the values
SITE_UID=$(grep "site_uid" "$AUTOMATIC_REGISTRATION_CONFIG" | cut --delimiter ":" --fields 2 | xargs)
PC_NAME=$(grep "pc_name" "$AUTOMATIC_REGISTRATION_CONFIG" | cut --delimiter ":" --fields 2 | xargs)

if [ -z "$SITE_UID" ] || [ -z "$PC_NAME" ]; then
  # Automatic registration is not being used so we remove the related files
  systemctl disable "$(basename $AUTOMATIC_REGISTRATION_SERVICE)"
  rm --force "$0" $AUTOMATIC_REGISTRATION_CONFIG $AUTOMATIC_REGISTRATION_SERVICE
else
  # If the option is selected, attempt to read serial number for use as PC name
  if [ "$PC_NAME" = "serial_number" ]; then
    PC_NAME=$(dmidecode --type system | grep "Serial" | cut --delimiter ":" --fields 2 | xargs)
  fi
  # Make sure that the PC name is a valid hostname
  if ! [[ "$PC_NAME" =~ ^[0-9a-zA-Z][0-9a-zA-Z-]{1-40}$ ]]; then
    # The PC name used for automatic registration is not a valid hostname
    # so we cancel automatic registration and delete the related files
    systemctl disable "$(basename $AUTOMATIC_REGISTRATION_SERVICE)"
    rm --force "$0" $AUTOMATIC_REGISTRATION_CONFIG $AUTOMATIC_REGISTRATION_SERVICE
    exit 1
  fi
  # Set hostname
  NEW_HOSTNAME=$(echo "$PC_NAME" | tr '[:upper:]' '[:lower:]')
  set_os2borgerpc_config hostname "$NEW_HOSTNAME"
  # Get the admin-url
  ADMIN_URL=$(cat $ADMIN_URL_FILE)
  set_os2borgerpc_config admin_url "$ADMIN_URL"
  # Wait for an internet connection
  CONNECTION="False"
  while [ "$CONNECTION" = "False" ]; do
    if ping -c 1 google.com > /dev/null 2>&1; then
      CONNECTION="True"
    else
      sleep 30
    fi
  done
  # Get the mac-address
  set_os2borgerpc_config mac "$(ip addr | grep link/ether | awk 'FNR==1{print $2}')"
  # - set additional config values
  OS_NAME=$(lsb_release --id --short)
  set_os2borgerpc_config os_name "$OS_NAME"

  OS_RELEASE=$(lsb_release --release --short)
  set_os2borgerpc_config _os_release "$OS_RELEASE"

  # xargs is there to remove leading and trailing spaces
  PC_MODEL=$(dmidecode --type system | grep Product | cut --delimiter : --fields 2 | xargs)
  [ -z "$PC_MODEL" ] && PC_MODEL="Identification failed"
  PC_MODEL=${PC_MODEL:0:100}
  set_os2borgerpc_config pc_model "$PC_MODEL"

  PC_MANUFACTURER=$(dmidecode --type system | grep Manufacturer | cut --delimiter : --fields 2 | xargs)
  [ -z "$PC_MANUFACTURER" ] && PC_MANUFACTURER="Identification failed"
  PC_MANUFACTURER=${PC_MANUFACTURER:0:100}
  set_os2borgerpc_config pc_manufacturer "$PC_MANUFACTURER"

  CPUS_BASE_INFO="$(dmidecode --type processor | grep Version | cut --delimiter ':' --fields 2 | xargs)"
  CPUS_BASE_INFO=${CPUS_BASE_INFO:0:100}
  CPU_CORES="$(grep ^"core id" /proc/cpuinfo | sort -u | wc -l)"
  CPU_CORES=${CPU_CORES:0:100}
  CPUS="$CPUS_BASE_INFO - $CPU_CORES physical cores"
  [ -z "$CPUS" ] && CPUS="Identification failed"
  set_os2borgerpc_config pc_cpus "$CPUS"

  # This path does not exist on RPI5
  RAM="$(free --human | awk '/^Mem:/ {print $2}')"
  [ -z "$RAM" ] && RAM="Identification failed"
  RAM=${RAM:0:100}
  set_os2borgerpc_config pc_ram "$RAM"

  # Do the actual registration
  if ! os2borgerpc_register_in_admin "$PC_NAME" "$SITE_UID"; then
    # Automatic registration failed so we remove the related files
    systemctl disable "$(basename $AUTOMATIC_REGISTRATION_SERVICE)"
    rm --force "$0" $AUTOMATIC_REGISTRATION_CONFIG $AUTOMATIC_REGISTRATION_SERVICE
    exit 1
  fi

  # Only set system hostname if the registration is successful
  echo "$NEW_HOSTNAME" > /etc/hostname
  hostname "$NEW_HOSTNAME"
  sed --in-place /127.0.1.1/d /etc/hosts
  sed --in-place "2i 127.0.1.1	$NEW_HOSTNAME" /etc/hosts
  # Randomize cron job to avoid everybody hitting the server the same minute
  "/usr/local/bin/randomize_jobmanager.sh" 5 > /dev/null

  # Cleanup
  systemctl disable "$(basename $AUTOMATIC_REGISTRATION_SERVICE)"
  rm --force "$0" $AUTOMATIC_REGISTRATION_CONFIG $AUTOMATIC_REGISTRATION_SERVICE
fi
