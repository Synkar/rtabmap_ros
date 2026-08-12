#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  run_docker.sh <model_path> <maps_dir> [log_dir] [map_id] [localization_mode]

Arguments:
  model_path          Host path to SuperPoint OpenVINO model (.xml or .onnx)
  maps_dir            Host directory for RTAB-Map databases (mounted at /data/maps)
  log_dir             Optional host log dir (default: /tmp/rtabmap_logs)
  map_id              Optional map id / db stem (default: map)
  localization_mode   Optional true|false (default: true)

Example:
  ./run_docker.sh ~/models/superpoint.xml ~/data/maps
  ./run_docker.sh ~/models/superpoint.xml ~/data/maps /tmp/rtabmap_logs map false
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 2 ]]; then
  usage >&2
  exit 1
fi

MODEL="$1"
MAPS_DIR="$2"
LOG_DIR="${3:-/tmp/rtabmap_logs}"
MAP_ID="${4:-map}"
LOCALIZATION_MODE="${5:-true}"

if [[ ! -f "$MODEL" ]]; then
  echo "error: model file not found: $MODEL" >&2
  exit 1
fi

if [[ ! -d "$MAPS_DIR" ]]; then
  echo "error: maps directory not found: $MAPS_DIR" >&2
  exit 1
fi

MODEL_EXT="${MODEL##*.}"
case "$MODEL_EXT" in
  xml|onnx) ;;
  *)
    echo "warning: unexpected model extension '.$MODEL_EXT' (expected .xml or .onnx)" >&2
    ;;
esac

CONTAINER_MODEL="/workspace/superpoint.${MODEL_EXT}"

mkdir -p "$LOG_DIR"

DOCKER_VOLUMES=(
  -v "$MODEL":"$CONTAINER_MODEL":ro
  -v "$MAPS_DIR":/data/maps
  -v "$LOG_DIR":/tmp/logs
  -v "$HOME/.ros":/tmp/.ros
)

# OpenVINO IR needs the sibling .bin next to the .xml inside the container
if [[ "$MODEL_EXT" == "xml" ]]; then
  MODEL_BIN="${MODEL%.xml}.bin"
  if [[ ! -f "$MODEL_BIN" ]]; then
    echo "error: OpenVINO IR requires companion weights: $MODEL_BIN" >&2
    exit 1
  fi
  DOCKER_VOLUMES+=(-v "$MODEL_BIN":/workspace/superpoint.bin:ro)
fi

DOCKER_TTY=(-i)
if [[ -t 0 ]]; then
  DOCKER_TTY=(-it)
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
EXAMPLES_SHARE="$REPO_ROOT/rtabmap_examples"

if [[ ! -f "$EXAMPLES_SHARE/launch/sdx_slam.launch" ]]; then
  echo "error: sdx_slam.launch not found at $EXAMPLES_SHARE/launch/sdx_slam.launch" >&2
  exit 1
fi

docker run "${DOCKER_TTY[@]}" --rm --network host \
  --user "$(id -u):$(id -g)" \
  --entrypoint /bin/bash \
  -e ROS_HOME=/tmp/.ros \
  -e ROS_LOG_DIR=/tmp/logs \
  -e RESOURCES_PATH=/data \
  -e MAP_ID="$MAP_ID" \
  -e SUPERPOINT_OPENVINO_MODEL="$CONTAINER_MODEL" \
  -e SUPERPOINT_OPENVINO_DEVICE=CPU \
  -e LOCALIZATION_MODE="$LOCALIZATION_MODE" \
  -v "$SCRIPT_DIR/ros_entrypoint.sh":/ros_entrypoint.sh:ro \
  -v "$EXAMPLES_SHARE":/mounted_rtabmap_examples:ro \
  "${DOCKER_VOLUMES[@]}" \
  rtabmap_ros:superpoint_openvino \
  /ros_entrypoint.sh bash -lc '
    set -euo pipefail
    # Source tree has CATKIN_IGNORE (excluded from image builds); stage a discoverable copy.
    mkdir -p /tmp/rtabmap_examples
    cp -a /mounted_rtabmap_examples/. /tmp/rtabmap_examples/
    rm -f /tmp/rtabmap_examples/CATKIN_IGNORE
    export ROS_PACKAGE_PATH=/tmp/rtabmap_examples:${ROS_PACKAGE_PATH}
    exec roslaunch rtabmap_examples sdx_slam.launch \
      output:=screen \
      localization_mode:="${LOCALIZATION_MODE}" \
      slam_manager:=slam_manager
  '
