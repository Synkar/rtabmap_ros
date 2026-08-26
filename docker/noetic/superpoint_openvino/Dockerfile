# Image built with OpenVINO SuperPoint support (CPU on Ubuntu 20.04 / ROS Noetic).
# Base: ubuntu:20.04. OpenVINO is installed from Intel apt (no NVIDIA runtime,
# no Torch/SuperGlue). OpenCV 4.5.5 comes from Synkar non-CUDA debs.
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
# Mount the model at runtime. OpenVINO IR (.xml plus its .bin) is preferred;
# compile_model also accepts a single .onnx.
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
#   -v /path/to/superpoint.xml:/workspace/superpoint.xml:ro \
#   -v /path/to/superpoint.bin:/workspace/superpoint.bin:ro \
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

FROM ubuntu:20.04

WORKDIR /workspace
ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-c"]

# apt-get update drops to the _apt user to verify InRelease signatures, and hands its
# config to apt-key through a hardcoded /tmp/apt.conf.XXXXXX. On this host _apt cannot
# write there, so every repository fails with "is not signed". Must precede any apt use.
RUN chmod 1777 /tmp && \
    printf 'APT::Sandbox::User "root";\n' > /etc/apt/apt.conf.d/10sandbox

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
      gnupg \
      lsb-release \
      ca-certificates \
      build-essential \
      libpdal-dev \
      libtbb-dev \
      libeigen3-dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ROS Noetic apt repository
RUN curl -fsSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc \
      | gpg --dearmor -o /usr/share/keyrings/ros-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" \
      > /etc/apt/sources.list.d/ros-latest.list

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
    rosdep init && \
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

# OpenVINO Runtime from Intel apt (CPU only; Ubuntu 20.04)
ARG OPENVINO_VERSION=2025.4.0
RUN wget -qO- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB \
      | gpg --dearmor -o /usr/share/keyrings/intel-openvino.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/intel-openvino.gpg] https://apt.repos.intel.com/openvino ubuntu20 main" \
      > /etc/apt/sources.list.d/intel-openvino.list && \
    apt-get update && \
    if apt-cache show "openvino-${OPENVINO_VERSION}" >/dev/null 2>&1; then \
      apt-get install -y --no-install-recommends "openvino-${OPENVINO_VERSION}"; \
    else \
      OPENVINO_PKG=$(apt-cache search --names-only '^openvino-2025\.' | awk '{print $1}' | sort -V | tail -n1) && \
      if [ -z "${OPENVINO_PKG}" ]; then OPENVINO_PKG=openvino; fi && \
      apt-get install -y --no-install-recommends "${OPENVINO_PKG}"; \
    fi && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# OpenCV from Synkar prebuilt debs (nonfree / xfeatures2d; no CUDA; no OpenCV from source).
# Install as parallel packages (do not replace ros-noetic libopencv 4.2 names) so ROS
# binaries keep their dependencies; force-overwrite files where paths overlap.
# All packages compiled in this image (rtabmap, cv_bridge, rtabmap_ros) use 4.5.5.
#
# OpenCV_DIR must be the real CMake dir (not a symlink): OpenCVConfig.cmake computes
# lib paths relative to it.
ENV OpenCV_DIR=/usr/lib/cmake/opencv4
ENV PYTHONPATH=/usr/lib/python3.8/site-packages
ARG OPENCV_VERSION=4.5.5
ARG OPENCV_RELEASE_TAG=${OPENCV_VERSION}-nocuda
RUN wget -q -P /tmp \
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
    dpkg -i --force-overwrite /tmp/OpenCV-${OPENCV_VERSION}-x86_64-dev-renamed.deb && \
    dpkg-deb -x /tmp/OpenCV-${OPENCV_VERSION}-x86_64-python.deb /tmp/OpenCV-${OPENCV_VERSION}-x86_64-python && \
    cd /tmp/OpenCV-${OPENCV_VERSION}-x86_64-python && \
    dpkg --control /tmp/OpenCV-${OPENCV_VERSION}-x86_64-python.deb && \
    sed -i 's/^Package:.*/Package: python3-opencv-synkar/' DEBIAN/control && \
    sed -i '/^Depends:/d' DEBIAN/control && \
    dpkg -b /tmp/OpenCV-${OPENCV_VERSION}-x86_64-python /tmp/OpenCV-${OPENCV_VERSION}-x86_64-python-renamed.deb && \
    dpkg -i --force-overwrite /tmp/OpenCV-${OPENCV_VERSION}-x86_64-python-renamed.deb && \
    ldconfig && \
    if ! grep -q "${OPENCV_VERSION}" "${OpenCV_DIR}/OpenCVConfig.cmake" 2>/dev/null; then \
      echo "Synkar OpenCV ${OPENCV_VERSION} not found at ${OpenCV_DIR}" >&2; \
      exit 1; \
    fi && \
    rm -rf /tmp/OpenCV-${OPENCV_VERSION}* && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# The debs above are force-installed with dpkg and their Depends stripped, so apt
# never learns that cv2 and opencv_sfm need libglog. Supply those libs and let -f
# repair the dpkg state before anything links against OpenCV.
RUN apt-get update && \
    apt-get install -y -f --no-install-recommends \
      libgflags2.2 \
      libunwind8 \
      libgoogle-glog0v5 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

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

# Shared OpenVINO/OpenCV environment, sourced by the build steps below and by the
# entrypoint. Sourcing /ros_entrypoint.sh from a RUN would not work: with no CMD args
# it execs bash, which silently drops the rest of the command.
COPY ./docker/noetic/superpoint_openvino/build_env.sh /etc/synkar/build_env.sh

# Build/install Synkar RTAB-Map library with SuperPoint OpenVINO backend.
# Link against Synkar OpenCV 4.5.5 (not Intel/OpenVINO OpenCV); rebuild cv_bridge
# against the same OpenCV below so ROS image nodes do not mix 4.2 and 4.5.5.
RUN git clone --depth 1 -b feature/openvino-superpoint-noetic \
      https://github.com/Synkar/rtabmap.git rtabmap && \
    source /opt/ros/noetic/setup.bash && \
    source /etc/synkar/build_env.sh && \
    OPENVINO_CONFIG=$(find /usr /opt/intel -name OpenVINOConfig.cmake 2>/dev/null | head -n1) && \
    if [ -z "${OPENVINO_CONFIG}" ]; then \
      echo "OpenVINOConfig.cmake not found" >&2; \
      exit 1; \
    fi && \
    mkdir -p rtabmap/build && \
    cd rtabmap/build && \
    cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX=/opt/ros/noetic \
          -DWITH_OPENVINO=ON \
          -DWITH_TORCH=OFF \
          -DWITH_PYTHON=OFF \
          -DOpenVINO_DIR="$(dirname "${OPENVINO_CONFIG}")" \
          -DOpenCV_DIR="${OpenCV_DIR}" \
          .. && \
    make -j"$(nproc)" && \
    make install && \
    cd /workspace && \
    rm -rf rtabmap && \
    ldconfig

# Rebuild cv_bridge / image_geometry against Synkar OpenCV 4.5.5 (avoids 4.2 mix at runtime)
RUN source /opt/ros/noetic/setup.bash && \
    mkdir -p /tmp/vision_ws/src && \
    git clone --depth 1 -b noetic https://github.com/ros-perception/vision_opencv.git /tmp/vision_ws/src/vision_opencv && \
    cd /tmp/vision_ws && \
    catkin init && \
    catkin config --install --install-space /opt/ros/noetic --whitelist cv_bridge image_geometry && \
    catkin build --cmake-args \
      -DCMAKE_BUILD_TYPE=Release \
      -DPYTHON_EXECUTABLE=/usr/bin/python3 \
      -DOpenCV_DIR="${OpenCV_DIR}" && \
    cd /workspace && \
    rm -rf /tmp/vision_ws && \
    ldconfig

# Catkin workspace for rtabmap_ros
RUN source /opt/ros/noetic/setup.bash && \
    mkdir -p catkin_ws/src && \
    cd catkin_ws && \
    catkin init && \
    catkin config --install --install-space /opt/ros/noetic

COPY . catkin_ws/src/rtabmap_ros

RUN source /opt/ros/noetic/setup.bash && \
    source /etc/synkar/build_env.sh && \
    cd catkin_ws && \
    apt-get update && \
    rosdep update --include-eol-distros || rosdep update && \
    rosdep install --from-paths src --ignore-src -y --rosdistro noetic || true && \
    apt-get remove -y 'ros-noetic-rtabmap*' || true && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    catkin build --cmake-args \
      -DPYTHON_EXECUTABLE=/usr/bin/python3 \
      -DRTABMAP_SYNC_MULTI_RGBD=ON \
      -DOpenCV_DIR="${OpenCV_DIR}" && \
    cd /workspace && \
    rm -rf catkin_ws

# Last so that editing the entrypoint does not invalidate any build layer.
COPY ./docker/noetic/superpoint_openvino/ros_entrypoint.sh /ros_entrypoint.sh
RUN chmod +x /ros_entrypoint.sh
ENTRYPOINT [ "/ros_entrypoint.sh" ]