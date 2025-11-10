#!/usr/bin/env bash
set -e

# Confirmation
read -p "Warning: this script may break your system. It manually installs \
files system-wide, which can create conflicts with important components of \
DGX OS. It also installs and removes packages using apt. Press Enter to \
continue or Ctrl + C to exit."
# NVIDIA OptiX SDK
if [ ! -f "$HOME/NVIDIA-OptiX-SDK-9.0.0-linux64-aarch64/include/optix.h" ]; then
    printf "NVIDIA OptiX SDK not found.\n\
Expected ~/NVIDIA-OptiX-SDK-9.0.0-linux64-aarch64/include/optix.h to exist.\n\
>> https://developer.nvidia.com/designworks/optix/download <<\n"
    exit 1
fi

set -x

sudo apt-get update
sudo apt-get install libxinerama-dev libxcursor-dev libxi-dev libglfw3-dev libboost-iostreams-dev libblosc-dev libjack-dev libpulse-dev libpipewire-0.3-dev libsndfile-dev libavdevice-dev libswscale-dev libavfilter-dev libavcodec-dev libavformat-dev curl git git-lfs libxrandr-dev ninja-build libjpeg-dev libepoxy-dev libshaderc-dev libfreetype-dev libjemalloc-dev libpugixml-dev libtiff-dev libwebp-dev libpotrace-dev libopenal-dev libfftw3-dev libglew-dev libglut-dev liblcms2-dev libyaml-cpp-dev libexpat-dev libpystring-dev pybind11-dev libosd-dev libimath-dev librubberband-dev libopenexr-dev
cd "$HOME"

# Download, verify, and extract Python, ISPC, and the Vulkan SDK
[ -f "python.tar.xz" ]    || curl -Lo "python.tar.xz" 'https://www.python.org/ftp/python/3.11.14/Python-3.11.14.tar.xz'
[ -f "ispc.tar.gz" ]      || curl -Lo "ispc.tar.gz" 'https://github.com/ispc/ispc/releases/download/v1.28.2/ispc-v1.28.2-linux.aarch64.tar.gz'
[ -f "vulkansdk.tar.xz" ] || curl -Lo "vulkansdk.tar.xz" 'https://sdk.lunarg.com/sdk/download/1.4.328.1/linux/vulkansdk-linux-x86_64-1.4.328.1.tar.xz'
echo "2f7d50f6e41d61607022dfeb7741df3a python.tar.xz" | md5sum -c
echo "c42267566b8c17a2a00668e168f56087b41e55cf1cea047dd0631cf512d011f7 ispc.tar.gz" | sha256sum -c
echo "241e75b56c91c0d210ed07a7c638ec05a3e5b0e4c66ba9f0ba0f102d823ad6bf vulkansdk.tar.xz" | sha256sum -c
tar xf python.tar.xz
tar xf ispc.tar.gz
tar xf vulkansdk.tar.xz

# Clone required repos
[ -d "sse2neon" ]    || git clone https://github.com/DLTcollab/sse2neon "$HOME/sse2neon"
[ -d "oneTBB" ]      || git clone https://github.com/uxlfoundation/oneTBB "$HOME/oneTBB"
[ -d "OpenImageIO" ] || git clone https://github.com/AcademySoftwareFoundation/OpenImageIO "$HOME/OpenImageIO"
[ -d "blender" ]     || git clone https://projects.blender.org/blender/blender.git "$HOME/blender"
[ -d "oidn" ]        || git clone --recursive https://github.com/OpenImageDenoise/oidn.git "$HOME/oidn"
[ -d "embree" ]      || git clone https://github.com/RenderKit/embree "$HOME/embree"
[ -d "openvdb" ]     || git clone https://github.com/AcademySoftwareFoundation/openvdb "$HOME"/openvdb
[ -d "openjpeg" ]    || git clone https://github.com/uclouvain/openjpeg.git "$HOME"/openjpeg
[ -d "OpenColorIO" ] || git clone https://github.com/AcademySoftwareFoundation/OpenColorIO.git "$HOME"/OpenColorIO
[ -d "minizip-ng" ]  || git clone https://github.com/zlib-ng/minizip-ng.git "$HOME"/minizip-ng

# Python
if ! command -v python3.11 > /dev/null 2>&1; then
    cd Python-3.11.14
    ./configure --without-doc-strings
    make -j18
    sudo make altinstall
fi

# oneTBB
mkdir -pv "$HOME"/oneTBB/build
cd "$HOME"/oneTBB/build
cmake -DTBB_TEST=OFF ..
cmake --build .
sudo cmake --install .
cd "$HOME"/OpenImageIO
cmake -B build -DOpenImageIO_BUILD_MISSING_DEPS=all -S .
cmake --build build --target install

# OpenImageDenoise
cd "$HOME"
mkdir -pv oidn/build
cd oidn/build
cmake -G Ninja -D ISPC_EXECUTABLE="$HOME"/ispc-v1.28.2-linux.aarch64/bin/ispc ..
ninja

# Vulkan
cd "$HOME"/1.4.328.1
./vulkansdk --maxjobs vulkan-loader shaderc
for dir in bin lib include share; do
    sudo cp -rv "$HOME"/1.4.328.1/aarch64/$dir /usr/$dir/
done

# Embree
mkdir -pv "$HOME"/embree/build
cd "$HOME"/embree/build
cmake ..
make -j18
sudo make install

# OpenVDB
mkdir -pv "$HOME"/openvdb/build
cd "$HOME"/openvdb/build
cmake -DOPENVDB_BUILD_NANOVDB=ON ..
make -j18
sudo make install

# OpenJPEG
mkdir -pv "$HOME"/openjpeg/build
cd "$HOME"/openjpeg/build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j18
sudo make install

# OpenColorIO
mkdir -pv "$HOME"/OpenColorIO/build
cd "$HOME"/OpenColorIO/build
cmake ..
make -j18
sudo make install

# Blender
cd "$HOME"/blender
#set +e
#make
#set -e
cmake -G 'Unix Makefiles' -DOPTIX_INCLUDE_DIR="$HOME"/NVIDIA-OptiX-SDK-9.0.0-linux64-aarch64/include \
-DWITH_CYCLES_CUDA_BINARIES=ON -DWITH_ALEMBIC=OFF -DWITH_MOD_FLUID=ON \
-DWITH_BLENDER_THUMBNAILER=ON -DWITH_BUILDINFO=OFF -DWITH_BULLET=ON \
-DWITH_CODEC_FFMPEG=ON -DWITH_CODEC_SNDFILE=ON -DWITH_CYCLES_DEBUG=ON \
-DWITH_CYCLES_DEVICE_OPTIX=ON -DWITH_CYCLES_OSL=OFF -DWITH_CYCLES_PATH_GUIDING=OFF -DWITH_DRACO=ON \
-DWITH_FFTW3=ON -DWITH_FREESTYLE=ON -DWITH_GHOST_XDND=OFF -DWITH_GMP=OFF -DWITH_HARU=OFF -DWITH_HYDRA=OFF -DWITH_IK_ITASC=ON -DWITH_IK_SOLVER=ON \
-DWITH_IMAGE_CINEON=ON -DWITH_IMAGE_OPENEXR=ON \
-DWITH_IMAGE_OPENJPEG=ON -DWITH_IMAGE_WEBP=ON -DWITH_INPUT_IME=OFF -DWITH_INPUT_NDOF=OFF -DWITH_IO_GREASE_PENCIL=ON \
-DWITH_JACK=ON -DWITH_MANIFOLD=OFF -DWITH_MATERIALX=OFF \
-DWITH_OPENAL=ON -DWITH_OPENVDB=ON -DOPENVDB_LIBRARY=/usr/local/lib/libopenvdb.so \
-DOPENVDB_INCLUDE_DIR=/usr/local/include/openvdb -DWITH_OPENVDB_BLOSC=ON -DWITH_PIPEWIRE=OFF -DWITH_PULSEAUDIO=ON \
-DWITH_PYTHON_INSTALL_NUMPY=OFF -DWITH_PYTHON_INSTALL_REQUESTS=OFF -DWITH_PYTHON_INSTALL_ZSTANDARD=OFF \
-DWITH_PYTHON_NUMPY=OFF -DWITH_PYTHON_SAFETY=ON -DWITH_QUADRIFLOW=OFF -DWITH_UI_TESTS_HEADLESS=OFF \
-DWITH_X11_XFIXES=OFF -DWITH_X11_XINPUT=OFF -DWITH_MOD_REMESH=ON \
-DWITH_GHOST_X11=ON -DWITH_GHOST_WAYLAND=OFF -DWITH_GHOST_WAYLAND_DYNLOAD=OFF -DWITH_OPENCOLORIO=ON \
-DWITH_XR_OPENXR=OFF -DWITH_USD=OFF -DWITH_CYCLES_DEVICE_CUDA=ON -DWITH_CYCLES_DEVICE_HIP=OFF \
-DWITH_NANOVDB=ON -DWITH_VULKAN_BACKEND=ON -DWITH_CYCLES=ON \
-DOPENIMAGEDENOISE_LIBRARY="$HOME"/oidn/build/libOpenImageDenoise.so \
-DOPENIMAGEDENOISE_OPENIMAGEDENOISE_LIBRARY="$HOME"/oidn/build/libOpenImageDenoise.so \
-DOPENIMAGEDENOISE_COMMON_LIBRARY="$HOME"/oidn/build/libOpenImageDenoise.so \
-DOPENIMAGEDENOISE_INCLUDE_DIR="$HOME"/oidn/include \
-DSSE2NEON_INCLUDE_DIR="$HOME"/sse2neon \
-DOPENIMAGEIO_INCLUDE_DIR="$HOME"/OpenImageIO/dist/include \
-DOPENIMAGEIO_LIBRARY="$HOME"/OpenImageIO/dist/lib/libOpenImageIO.so \
-DOPENIMAGEIO_TOOL="$HOME"/blender/OpenImageIO/dist/bin/oiiotool \
-DOPENIMAGEIO_UTIL_LIBRARY="$HOME"/OpenImageIO/dist/lib/libOpenImageIO_Util.so \
-DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_VERBOSE_MAKEFILE=ON -DPYTHON_NUMPY_INCLUDE_DIRS=/usr/local/lib/python3.11/site-packages/numpy/_core/include \
-DOPENCOLORIO_INCLUDE_DIR=x.so \
../build_linux

# Blender launcher
cat > "$HOME"/launchBlender <<EOL
#!/usr/bin/env bash
export LD_LIBRARY_PATH=/usr/local/lib:/home/cocomac/embree/build:/home/cocomac/oidn/build:/home/cocomac/OpenImageIO/dist/lib
$HOME/build_linux/bin/blender
EOL
chmod +x "$HOME"/launchBlender

cat > "$HOME"/blender/spark.patch <<EOL
diff --git a/intern/cycles/util/math_float3.h b/intern/cycles/util/math_float3.h
index ce517c6d764..6bf6762879a 100644
--- a/intern/cycles/util/math_float3.h
+++ b/intern/cycles/util/math_float3.h
@@ -651,7 +651,7 @@ ccl_device_inline auto isequal_mask(const float3 a, const float3 b)
 #if defined(__KERNEL_METAL__)
   return a == b;
 #elif defined __KERNEL_NEON__
-  return int3(vreinterpretq_m128i_s32(vceqq_f32(a.m128, b.m128)));
+  return int3(vreinterpretq_m128i_s32(vreinterpretq_s32_u32(vceqq_f32(a.m128, b.m128))));
 #elif defined(__KERNEL_SSE__)
   return int3(_mm_castps_si128(_mm_cmpeq_ps(a.m128, b.m128)));
 #else
EOL
git apply spark.patch

## Missing from builder.sh: alembic OpenColorIO openssl openvdb
