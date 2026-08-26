#!/bin/bash
# Shared environment for the Dockerfile build steps and the runtime entrypoint.
# Sourced from both, so it must never exec or exit.

# OpenVINO environment (Intel apt install on Ubuntu 20.04)
if [ -f /opt/intel/openvino/setupvars.sh ]; then
  # shellcheck disable=SC1091
  source /opt/intel/openvino/setupvars.sh
elif [ -f /opt/intel/openvino_2025/setupvars.sh ]; then
  # shellcheck disable=SC1091
  source /opt/intel/openvino_2025/setupvars.sh
elif [ -f /opt/intel/openvino_2024/setupvars.sh ]; then
  # shellcheck disable=SC1091
  source /opt/intel/openvino_2024/setupvars.sh
elif [ -f /usr/share/openvino/setupvars.sh ]; then
  # shellcheck disable=SC1091
  source /usr/share/openvino/setupvars.sh
elif ls /opt/intel/openvino_*/setupvars.sh >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  source "$(ls -1 /opt/intel/openvino_*/setupvars.sh | head -n1)"
fi

# setupvars.sh repoints OpenCV_DIR at Intel's OpenCV; everything here links Synkar 4.5.5.
export OpenCV_DIR=/usr/lib/cmake/opencv4
