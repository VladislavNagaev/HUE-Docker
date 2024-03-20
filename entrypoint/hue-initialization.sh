#!/bin/bash

COMMAND="${1:-}"


if [ "${COMMAND}" == "hue" ]; then

    echo "Starting Hue ..."

    ${HUE_HOME}/build/env/bin/hue migrate
    ${HUE_HOME}/build/env/bin/supervisor

fi

if [ "${COMMAND}" == "wait" ]; then

    tail -f /dev/null

fi

exit $?
