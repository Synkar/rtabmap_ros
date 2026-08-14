#!/bin/bash
set -e

# Preserve CMD args: OpenVINO setupvars.sh (and some ROS hooks) can clobber $@.
_CMD_ARGS=("$@")

# OpenVINO environment + Synkar OpenCV dir
# shellcheck disable=SC1091
source /etc/synkar/build_env.sh

# setup ros environment
# shellcheck disable=SC1091
source "/opt/ros/noetic/setup.bash"

if [ ${#_CMD_ARGS[@]} -eq 0 ]; then
  exec bash
fi
exec "${_CMD_ARGS[@]}"
