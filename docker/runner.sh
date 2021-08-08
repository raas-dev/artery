#!/bin/sh

echo "--- runner.sh -----------------------------------------------------------"

# catch signals to exit with correct statuses
trap "echo -e '\nCaught ^C, exiting gracefully...' ; exit 0" INT TERM
trap "exit 0" EXIT

# start sshd if exists
if which sshd >/dev/null ;then
    echo "The host keys are added by App Service, you can ignore the warnings:"
    /usr/sbin/sshd &
fi

"$@"
