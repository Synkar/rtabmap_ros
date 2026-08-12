# Image built with OpenVINO SuperPoint support (CPU on Ubuntu 20.04 / ROS Noetic).
# Base: official openvino/ubuntu20_dev (no NVIDIA runtime, no Torch/SuperGlue).
#
# Phase 1: OpenVINO inference on CPU only (matches Noetic / Focal).
# NPU/GPU validation needs Ubuntu 22.04+ OpenVINO containers — not covered here.
#
# Create image:
#
#   cd rtabmap_ros
#   docker build -t rtabmap_ros:superpoint_openvino \
#     -f docker/noetic/superpoint_openvino/Dockerfile .
#
# Example usage (SuperPoint OpenVINO + brute-force matching, no SuperGlue).
# Mount an ONNX or OpenVINO IR (.xml/.bin) model at runtime:
#
# [Camera]
# docker run -it --rm --network host --privileged rtabmap_ros:superpoint_openvino \
#   roslaunch realsense2_camera rs_camera.launch enable_infra1:=true enable_infra2:=true \
#   unite_imu_method:=linear_interpolation enable_gyro:=true enable_accel:=true enable_sync:=true
#
# [IMU filter]
# docker run -it --rm --network host rtabmap_ros:superpoint_openvino \
#   rosrun imu_filter_madgwick imu_filter_node _use_mag:=false _publish_tf:=false \
#   _world_frame:="enu" /imu/data_raw:=/camera/imu /imu/data:=/rtabmap/imu
#
# [VSLAM]  (no --runtime=nvidia)
# docker run -it --rm --user $UID -e ROS_HOME=/tmp/.ros --network host \
#   -v ~/.ros:/tmp/.ros \
#   -v /path/to/superpoint.onnx:/workspace/superpoint.onnx:ro \
#   rtabmap_ros:superpoint_openvino \
#   roslaunch rtabmap_launch rtabmap.launch rtabmap_viz:=false \
#   database_path:=/tmp/.ros/rtabmap.db \
#   rtabmap_args:="--delete_db_on_start \
#     --Kp/DetectorStrategy 99 \
#     --SuperPoint/OpenVINOModelPath /workspace/superpoint.xml \
#     --SuperPoint/OpenVINODevice CPU \
#     --Vis/CorNNType 1 \
#     --Reg/RepeatOnce false \
#     --Vis/CorGuessWinSize 0" \
#   # OpenVINO IR (.xml/.bin) preferred; ONNX also accepted by compile_model
#   odom_args:="--Vis/CorNNType 1 --Reg/RepeatOnce true --Vis/CorGuessWinSize 40" \
#   left_image_topic:=/camera/infra1/image_rect_raw \
#   right_image_topic:=/camera/infra2/image_rect_raw \
#   left_camera_info_topic:=/camera/infra1/camera_info \
#   right_camera_info_topic:=/camera/infra2/camera_info \
#   stereo:=true wait_imu_to_init:=true imu_topic:=/rtabmap/imu
#
# [Visualization - optional]
# XAUTH=/tmp/.docker.xauth
# touch $XAUTH
# xauth nlist $DISPLAY | sed -e 's/^..../ffff/' | xauth -f $XAUTH nmerge -
# docker run -it --rm --privileged -e DISPLAY=$DISPLAY -e QT_X11_NO_MITSHM=1 \
#   -e XAUTHORITY=$XAUTH --network host -v $XAUTH:$XAUTH -v /tmp/.X11-unix:/tmp/.X11-unix \
#   rtabmap_ros:superpoint_openvino /bin/bash -c \
#   "export ROS_NAMESPACE=rtabmap && rosrun rtabmap_viz rtabmap_viz \
#     _subscribe_odom_info:=true left/image_rect:=/camera/infra1/image_rect_raw \
#     right/image_rect:=/camera/infra2/image_rect_raw \
#     left/camera_info:=/camera/infra1/camera_info \
#     right/camera_info:=/camera/infra2/camera_info _subscribe_stereo:=true"
#

FROM openvino/ubuntu20_dev:2024.6.0

USER root
WORKDIR /workspace
ENV DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=noetic

# Use bash for RUN steps that source setup scripts
RUN rm -f /bin/sh && ln -s /bin/bash /bin/sh

# Build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
      libsqlite3-dev \
      git \
      cmake \
      libyaml-cpp-dev \
      software-properties-common \
      pkg-config \
      wget \
      curl \
      gnupg2 \
      lsb-release \
      ca-certificates \
      build-essential \
      libpdal-dev \
      libtbb-dev \
      libeigen3-dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ROS Noetic apt repository
RUN echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" \
      > /etc/apt/sources.list.d/ros-latest.list && \
    curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | apt-key add -

# ROS Noetic packages (deb install — do not build ROS from source)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ros-noetic-ros-base \
      python3-catkin-tools \
      python3-rosdep \
      python3-osrf-pycommon \
      ros-noetic-rtabmap-ros \
      ros-noetic-pybind11-catkin \
      ros-noetic-image-transport-plugins \
      ros-noetic-stereo-image-proc && \
    apt-get remove -y ros-noetic-rtabmap || true && \
    (rosdep init || true) && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# GTSAM
RUN add-apt-repository ppa:borglab/gtsam-release-4.0 && \
    apt-get update && \
    apt-get install -y --no-install-recommends libgtsam-dev libgtsam-unstable-dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# MRPT
RUN add-apt-repository ppa:joseluisblancoc/mrpt-stable -y && \
    apt-get update && \
    apt-get install -y --no-install-recommends libmrpt-poses-dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# OpenCV from Synkar prebuilt debs (nonfree / xfeatures2d; no OpenCV from source).
# Install as parallel packages (do not replace ros-noetic libopencv 4.2 names) so ROS
# binaries keep their dependencies; force-overwrite files where paths overlap.
# Pattern adapted from delivery_core Dockerfile.
ARG OPENCV_VERSION=4.5.5
ARG OPENCV_RELEASE_TAG=4.5.5-ffmpeg
RUN set -e && \
    wget -q -P /tmp \
      "https://github.com/Synkar/opencv/releases/download/${OPENCV_RELEASE_TAG}/OpenCV-${OPENCV_VERSION}-x86_64-dev.deb" && \
    wget -q -P /tmp \
      "https://github.com/Synkar/opencv/releases/download/${OPENCV_RELEASE_TAG}/OpenCV-${OPENCV_VERSION}-x86_64-libs.deb" && \
    wget -q -P /tmp \
      "https://github.com/Synkar/opencv/releases/download/${OPENCV_RELEASE_TAG}/OpenCV-${OPENCV_VERSION}-x86_64-python.deb" && \
    dpkg-deb -x /tmp/OpenCV-${OPENCV_VERSION}-x86_64-dev.deb /tmp/OpenCV-${OPENCV_VERSION}-x86_64 && \
    cd /tmp/OpenCV-${OPENCV_VERSION}-x86_64 && \
    dpkg --control /tmp/OpenCV-${OPENCV_VERSION}-x86_64-dev.deb && \
    sed -i 's/^Package:.*/Package: libopencv-dev-synkar/' DEBIAN/control && \
    sed -i '/^Depends:/d' DEBIAN/control && \
    dpkg -b /tmp/OpenCV-${OPENCV_VERSION}-x86_64 /tmp/OpenCV-${OPENCV_VERSION}-x86_64-dev-renamed.deb && \
    dpkg -i --force-overwrite /tmp/OpenCV-${OPENCV_VERSION}-x86_64-libs.deb || true && \
    dpkg -i --force-overwrite /tmp/OpenCV-${OPENCV_VERSION}-x86_64-dev-renamed.deb || true && \
    dpkg-deb -x /tmp/OpenCV-${OPENCV_VERSION}-x86_64-python.deb /tmp/OpenCV-${OPENCV_VERSION}-x86_64-python && \
    cd /tmp/OpenCV-${OPENCV_VERSION}-x86_64-python && \
    dpkg --control /tmp/OpenCV-${OPENCV_VERSION}-x86_64-python.deb && \
    sed -i 's/^Package:.*/Package: python3-opencv-synkar/' DEBIAN/control && \
    sed -i '/^Depends:/d' DEBIAN/control && \
    dpkg -b /tmp/OpenCV-${OPENCV_VERSION}-x86_64-python /tmp/OpenCV-${OPENCV_VERSION}-x86_64-python-renamed.deb && \
    dpkg -i --force-overwrite /tmp/OpenCV-${OPENCV_VERSION}-x86_64-python-renamed.deb || true && \
    ldconfig && \
    rm -rf /tmp/OpenCV-${OPENCV_VERSION}* /tmp/*.deb && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ENV PYTHONPATH="${PYTHONPATH}:/usr/lib/python3.8/site-packages"

# OpenGV
RUN git clone https://github.com/laurentkneip/opengv.git && \
    cd opengv && \
    git checkout 91f4b19c73450833a40e463ad3648aae80b3a7f3 && \
    wget -q https://gist.githubusercontent.com/matlabbe/a412cf7c4627253874f81a00745a7fbb/raw/accc3acf465d1ffd0304a46b17741f62d4d354ef/opengv_disable_march_native.patch && \
    git apply opengv_disable_march_native.patch && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release .. && \
    make -j"$(nproc)" && \
    make install && \
    cd /workspace && \
    rm -rf opengv

# ROS entrypoint (OpenVINO setupvars + Noetic)
COPY ./docker/noetic/superpoint_openvino/ros_entrypoint.sh /ros_entrypoint.sh
RUN chmod +x /ros_entrypoint.sh
ENTRYPOINT [ "/ros_entrypoint.sh" ]

# Build/install Synkar RTAB-Map library with SuperPoint OpenVINO backend
# (Source OpenVINO + ROS setup directly; do not source the entrypoint — it ends with exec.)
RUN git clone --depth 1 -b feature/openvino-superpoint-noetic \
      https://github.com/Synkar/rtabmap.git rtabmap && \
    source /opt/ros/noetic/setup.bash && \
    if [ -f /opt/intel/openvino/setupvars.sh ]; then source /opt/intel/openvino/setupvars.sh; \
    elif [ -f /opt/intel/openvino_2024/setupvars.sh ]; then source /opt/intel/openvino_2024/setupvars.sh; \
    elif ls /opt/intel/openvino_*/setupvars.sh >/dev/null 2>&1; then source "$(ls -1 /opt/intel/openvino_*/setupvars.sh | head -n1)"; fi && \
    mkdir -p rtabmap/build && \
    cd rtabmap/build && \
    cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX=/opt/ros/noetic \
          -DWITH_OPENVINO=ON \
          -DWITH_TORCH=OFF \
          -DWITH_PYTHON=OFF \
          .. && \
    make -j"$(nproc)" && \
    make install && \
    cd /workspace && \
    rm -rf rtabmap && \
    ldconfig

# Catkin workspace for rtabmap_ros
RUN source /opt/ros/noetic/setup.bash && \
    mkdir -p catkin_ws/src && \
    cd catkin_ws && \
    catkin init && \
    catkin config --install --install-space /opt/ros/noetic

COPY . catkin_ws/src/rtabmap_ros

RUN source /opt/ros/noetic/setup.bash && \
    if [ -f /opt/intel/openvino/setupvars.sh ]; then source /opt/intel/openvino/setupvars.sh; \
    elif [ -f /opt/intel/openvino_2024/setupvars.sh ]; then source /opt/intel/openvino_2024/setupvars.sh; \
    elif ls /opt/intel/openvino_*/setupvars.sh >/dev/null 2>&1; then source "$(ls -1 /opt/intel/openvino_*/setupvars.sh | head -n1)"; fi && \
    cd catkin_ws && \
    apt-get update && \
    rosdep update --include-eol-distros || rosdep update && \
    rosdep install --from-paths src --ignore-src -y --rosdistro noetic || true && \
    apt-get remove -y 'ros-noetic-rtabmap*' || true && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    catkin build --cmake-args \
      -DPYTHON_EXECUTABLE=/usr/bin/python3 \
      -DRTABMAP_SYNC_MULTI_RGBD=ON && \
    cd /workspace && \
    rm -rf catkin_ws