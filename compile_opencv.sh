#!/bin/bash

# List of packages to check
packages="build-essential cmake git python3-dev python3-pip python3-numpy python3-venv
ffmpeg libavcodec-dev libavformat-dev libswscale-dev libxvidcore-dev libx264-dev libx265-dev libmp3lame-dev libopus-dev libvorbis-dev
libdc1394-25 libdc1394-dev libxine2-dev libv4l-dev v4l-utils libgtk-3-dev"

update_package_index=0
# Loop through each package and check if it is installed
for pkg in $packages; do
    if dpkg -s "$pkg" 1> /dev/null; then
        echo "$pkg is already installed"
    else
        if [ $update_package_index -eq 0 ]; then
            sudo apt update
            update_package_index=1 #the script will update the package index once
        fi
        echo "$pkg is not installed"
        sudo apt install $pkg -y
    fi
done

OPENCV_VERSION="4.10.0"
OPENCV_SOURCE_DIR="__opencv__/opencv_$OPENCV_VERSION"
OPENCV_CONTRIB_SOURCE_DIR="__opencv__/opencv_contrib_$OPENCV_VERSION"

OPENCV_INSTALL_DIR="/usr/local"

if [ ! -d "$OPENCV_SOURCE_DIR" ]; then
    git clone https://github.com/opencv/opencv.git $OPENCV_SOURCE_DIR
    git -C $OPENCV_SOURCE_DIR checkout $OPENCV_VERSION
    git -C $OPENCV_SOURCE_DIR branch
fi

if [ ! -d "$OPENCV_CONTRIB_SOURCE_DIR" ]; then
    git clone https://github.com/opencv/opencv_contrib.git $OPENCV_CONTRIB_SOURCE_DIR
    git -C $OPENCV_CONTRIB_SOURCE_DIR checkout $OPENCV_VERSION
    git -C $OPENCV_CONTRIB_SOURCE_DIR branch
fi

echo ""

read -p "Do you want to enable Python3 integration? (Y for enable, N for disable): " python_integration_enabled

if [[ "$python_integration_enabled" == "Y" ]] || [[ "$python_integration_enabled" == "y" ]]; then
    
    echo 
    echo "To use your custom Python3 installation, enter its version in the format \"Major.Minor\""
    echo "(Leave empty to use the pre-installed/default Python3 on your Linux system)"
    echo
    read -p "Preferred Python3 version: " VERSION_STRING_PYTHON3
    echo

    if [ -z "$VERSION_STRING_PYTHON3" ]; then
        VERSION_STRING_PYTHON3=3
    fi

    if pip"$VERSION_STRING_PYTHON3" show numpy &>/dev/null; then
        echo "numpy is installed."
    else
        echo "numpy is not installed."
        pip"$VERSION_STRING_PYTHON3" install numpy
    fi

    PREFERRED_PYTHON=python$VERSION_STRING_PYTHON3

    COMPILE_OPENCV_FOR_PYTHON=ON
    EXECUTABLE_PYTHON3=$($PREFERRED_PYTHON -c "import sys; print(sys.executable)")
    LIBRARY_PYTHON3=$($PREFERRED_PYTHON -c "import sysconfig; import sys; print(sysconfig.get_config_var('LIBDIR')+'/libpython3'+'.'+str(sys.version_info.minor)+'.so')")
    LIBS_VERSION_STRING_PYTHON3=$($PREFERRED_PYTHON -c "import platform; print(platform.python_version())")
    INCLUDE_DIR_PYTHON3=$($PREFERRED_PYTHON -c "import sysconfig; print(sysconfig.get_path('include'))")
    PACKAGES_PATH_PYTHON3=$($PREFERRED_PYTHON -c "import sysconfig; print(sysconfig.get_path('purelib'))")
    NUMPY_INCLUDE_DIR_PYTHON3=$($PREFERRED_PYTHON -c "import numpy; print(numpy.get_include())")
    NUMPY_VERSION_PYTHON3=$($PREFERRED_PYTHON -c "import numpy; print(numpy.version.version)")

    BUILD_TYPE="Release"

elif [[ "$python_integration_enabled" == "N" ]] || [[ "$python_integration_enabled" == "n" ]]; then
    
    COMPILE_OPENCV_FOR_PYTHON=OFF

    read -p "Choose build type (1 for Release, 2 for Debug): " build_choice
    if [ "$build_choice" -eq 1 ]; then
        BUILD_TYPE="Release"
    elif [ "$build_choice" -eq 2 ]; then
        BUILD_TYPE="Debug"
    else
        echo "Invalid build type choice. Please enter 1 or 2."
        exit 1
    fi

else
    echo "Invalid choice. Please enter Y/y or N/n."
    exit 1
fi

echo
echo "Selected build type: $BUILD_TYPE"
echo

BUILD_DIR="./__build_dir__/$BUILD_TYPE"

if [ -d "$BUILD_DIR" ]; then
    sudo rm -rf "$BUILD_DIR/CMakeCache.txt" "$BUILD_DIR/CMakeCache.txt" # for a clean installation
fi

cmake \
    -D CMAKE_CXX_STANDARD=17 \
    -D CMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -D CMAKE_INSTALL_PREFIX="$OPENCV_INSTALL_DIR" \
    -D OPENCV_EXTRA_MODULES_PATH="$OPENCV_CONTRIB_SOURCE_DIR/modules" \
	-D BUILD_opencv_world=ON \
    -D WITH_OPENCL=ON \
    -D WITH_CUDA=ON \
    -D WITH_CUDNN=ON \
    -D WITH_GTK=ON \
	-D WITH_OPENMP=ON \
    -D BUILD_opencv_python3="$COMPILE_OPENCV_FOR_PYTHON" \
    -D PYTHON3_VERSION_STRING="$VERSION_STRING_PYTHON3" \
    -D OPENCV_PYTHON3_VERSION="$VERSION_STRING_PYTHON3" \
    -D PYTHON3_EXECUTABLE="$EXECUTABLE_PYTHON3" \
    -D PYTHON3_LIBRARIES="$LIBRARY_PYTHON3" \
    -D PYTHON3_INCLUDE_DIR="$INCLUDE_DIR_PYTHON3" \
    -D PYTHON3_PACKAGES_PATH="$PACKAGES_PATH_PYTHON3" \
    -D PYTHON3_NUMPY_INCLUDE_DIRS="$NUMPY_INCLUDE_DIR_PYTHON3" \
    -D PYTHON3LIBS_VERSION_STRING="$LIBS_VERSION_STRING_PYTHON3" \
    -D PYTHON3_NUMPY_VERSION="$NUMPY_VERSION_PYTHON3" \
    -D INSTALL_PYTHON_EXAMPLES=OFF \
    -D INSTALL_C_EXAMPLES=OFF \
    -D BUILD_EXAMPLES=OFF \
    -D BUILD_TESTS=OFF \
    -D BUILD_DOCS=OFF \
    -D BUILD_PERF_TESTS=OFF \
    -S "$OPENCV_SOURCE_DIR" \
    -B "$BUILD_DIR"

echo 
echo "Executable Python: $EXECUTABLE_PYTHON3"
echo "Library Directory: $LIBRARY_PYTHON3"
echo "Python Version(Major.Minor.Patch): $LIBS_VERSION_STRING_PYTHON3"
echo "Include Directory: $INCLUDE_DIR_PYTHON3"
echo "Packages Path: $PACKAGES_PATH_PYTHON3"
echo "NumPy Include Directory: $NUMPY_INCLUDE_DIR_PYTHON3"
echo "NumPy Version: $NUMPY_VERSION_PYTHON3"
echo

echo
echo "Press any key to start compilation..."
echo
read -n 1 -s

NUM_THREADS=$(($(nproc) - 2))

if [ "$NUM_THREADS" -le 0 ]; then
    NUM_THREADS=1
fi

cmake --build "$BUILD_DIR" --config "$BUILD_TYPE" -j"$NUM_THREADS"

cd "$BUILD_DIR"

sudo make install

# end of file
