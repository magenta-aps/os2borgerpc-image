#!/usr/bin/env sh

# Removing thunderbird during image building or in the post-install script does not work
# for some reason so we remove it here
snap remove thunderbird

# Due to weirdness in 24.04, the system logs initially use UTC rather than the
# chosen timezone, unless the computer had internet during the installation.
# We restart the rsyslog service to make it start using the chosen timezone
systemctl restart rsyslog.service

# Detect the locale chosen under the installation and rename "Borger" if not Danish
# Also reset Firefox language to english if the locale is not Danish or Swedish
# Locale file may or may not contain " around the value of LANG
LOCALE=$(grep LANG /etc/default/locale | cut --delimiter '=' --fields 2 | tr --delete '"' | cut --delimiter '_' --fields 1)
if [ "$LOCALE" != "da" ] && [ "$LOCALE" != "sv" ]; then
  FIREFOX_POLICY_FILE="/etc/firefox/policies/policies.json"
  sed --in-place "s/\"RequestedLocales\":.*/\"RequestedLocales\": \"$LOCALE\"," $FIREFOX_POLICY_FILE
fi
if [ "$LOCALE" = "en" ]; then
    usermod --comment 'Citizen' user
fi

# We want superuser to be hidden on the login screen after the first login
# The relevant file also does not exist until you've logged in as superuser
# at least once
ACCOUNT_SERVICE_SUPERUSER="/var/lib/AccountsService/users/superuser"
if [ -f $ACCOUNT_SERVICE_SUPERUSER ]; then
  sed --in-place "s/SystemAccount=false/SystemAccount=true/" $ACCOUNT_SERVICE_SUPERUSER
  systemctl disable first_logout.service
  rm --force /etc/os2borgerpc/post-session-scripts/first-logout.sh /etc/systemd/system/first_logout.service
fi
