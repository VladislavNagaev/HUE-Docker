#!/bin/bash

# tail -f /dev/null

# "${@}"

COMMAND="${1:-}"

source /entrypoint/wait_for_it.sh

source /entrypoint/font-colors.sh
source /entrypoint/hue-configure.sh

source /entrypoint/hue-initialization.sh $COMMAND

