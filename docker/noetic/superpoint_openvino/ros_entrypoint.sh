#!/bin/bash
set -e

# Preserve CMD args: OpenVINO setupvars.sh (and some ROS hooks) can clobber $@.
_CMD_ARGS=("$@")

# OpenVINO environment (official openvino/ubuntu20_* images)
if [ -f /opt/intel/openvino/setupvars.sh ]; then
  # shellcheck disable=SC1091
  source /opt/intel/openvino/setupvars.sh
elif [ -f /opt/intel/openvino_2024/setupvars.sh ]; then
  # shellcheck disable=SC1091
  source /opt/intel/openvino_2024/setupvars.sh
elif ls /opt/intel/openvino_*/setupvars.sh >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  source "$(ls -1 /opt/intel/openvino_*/setupvars.sh | head -n1)"
fi

# setup ros environment
# shellcheck disable=SC1091
source "/opt/ros/noetic/setup.bash"

if [ ${#_CMD_ARGS[@]} -eq 0 ]; then
  exec bash
fi
exec "${_CMD_ARGS[@]}"
