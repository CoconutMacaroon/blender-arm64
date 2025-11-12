FROM nvcr.io/nvidia/cuda:13.0.1-devel-ubuntu24.04
RUN useradd --create-home --shell /bin/bash spark
COPY builder.sh /home/spark/
COPY NVIDIA-OptiX-SDK-9.0.0-linux64-aarch64 /home/spark/NVIDIA-OptiX-SDK-9.0.0-linux64-aarch64
RUN apt-get update && apt-get install -y libxinerama-dev libxcursor-dev libxi-dev libglfw3-dev libboost-iostreams-dev libblosc-dev libjack-dev libpulse-dev libpipewire-0.3-dev libsndfile-dev libavdevice-dev libswscale-dev libavfilter-dev libavcodec-dev libavformat-dev curl git git-lfs libxrandr-dev ninja-build libjpeg-dev libepoxy-dev libshaderc-dev libfreetype-dev libjemalloc-dev libpugixml-dev libtiff-dev libwebp-dev libpotrace-dev libopenal-dev libfftw3-dev libglew-dev libglut-dev liblcms2-dev libyaml-cpp-dev libexpat-dev libpystring-dev pybind11-dev libosd-dev libimath-dev librubberband-dev libopenexr-dev cmake pkg-config libxcb1-dev libx11-dev libxrandr-dev wayland-protocols
USER spark
RUN mkdir /home/spark/build
WORKDIR /home/spark/build
RUN curl -Lo "python.tar.xz" 'https://www.python.org/ftp/python/3.11.14/Python-3.11.14.tar.xz' &&\
    curl -Lo "ispc.tar.gz" 'https://github.com/ispc/ispc/releases/download/v1.28.2/ispc-v1.28.2-linux.aarch64.tar.gz' &&\
    curl -Lo "vulkansdk.tar.xz" 'https://sdk.lunarg.com/sdk/download/1.4.328.1/linux/vulkansdk-linux-x86_64-1.4.328.1.tar.xz'
RUN echo "2f7d50f6e41d61607022dfeb7741df3a python.tar.xz" | md5sum -c
RUN echo "c42267566b8c17a2a00668e168f56087b41e55cf1cea047dd0631cf512d011f7 ispc.tar.gz" | sha256sum -c
RUN echo "241e75b56c91c0d210ed07a7c638ec05a3e5b0e4c66ba9f0ba0f102d823ad6bf vulkansdk.tar.xz" | sha256sum -c
RUN tar xf python.tar.xz && tar xf ispc.tar.gz && tar xf vulkansdk.tar.xz
RUN git clone https://github.com/DLTcollab/sse2neon &&\
    git clone https://github.com/uxlfoundation/oneTBB &&\
    git clone https://github.com/AcademySoftwareFoundation/OpenImageIO &&\
    git clone https://projects.blender.org/blender/blender.git &&\
    git clone --recursive https://github.com/OpenImageDenoise/oidn.git &&\
    git clone https://github.com/RenderKit/embree &&\
    git clone https://github.com/AcademySoftwareFoundation/openvdb &&\
    git clone https://github.com/uclouvain/openjpeg.git &&\
    git clone https://github.com/AcademySoftwareFoundation/OpenColorIO.git &&\
    git clone https://github.com/zlib-ng/minizip-ng.git
WORKDIR /home/spark/build/Python-3.11.14
RUN ./configure --without-doc-strings && make -j18
USER root
RUN make altinstall
USER spark
RUN mkdir -v /home/spark/build/oneTBB/build
WORKDIR /home/spark/build/oneTBB/build
RUN cmake -DTBB_TEST=OFF .. && cmake --build .
USER root
RUN cmake --install .
USER spark
WORKDIR /home/spark/build/OpenImageIO
RUN cmake -B build -DOpenImageIO_BUILD_MISSING_DEPS=all -S . && cmake --build build --target install

# OpenImageDenoise
RUN mkdir -v /home/spark/build/oidn/build
WORKDIR /home/spark/build/oidn/build
RUN cmake -G Ninja -D ISPC_EXECUTABLE=/home/spark/build/ispc-v1.28.2-linux.aarch64/bin/ispc .. && ninja

# Vulkan
WORKDIR /home/spark/build/1.4.328.1
RUN ./vulkansdk --skip-installing-deps --maxjobs vulkan-loader shaderc vulkan-tools
USER root
RUN for dir in bin lib include share; do cp -rv /home/spark/build/1.4.328.1/aarch64/$dir /usr/$dir/; done
USER spark

# Embree
RUN mkdir -v /home/spark/build/embree/build
WORKDIR /home/spark/build/embree/build
RUN cmake .. && make -j18
USER root
RUN make install
USER spark

# OpenVDB
RUN mkdir -v /home/spark/build/openvdb/build
WORKDIR /home/spark/build/openvdb/build
RUN cmake -DOPENVDB_BUILD_NANOVDB=ON .. && make -j18
USER root
RUN make install
USER spark

# OpenJPEG
RUN mkdir -v /home/spark/build/openjpeg/build
WORKDIR /home/spark/build/openjpeg/build
RUN cmake .. -DCMAKE_BUILD_TYPE=Release && make -j18
USER root
RUN make install
USER spark

# OpenColorIO
RUN mkdir -v /home/spark/build/OpenColorIO/build
WORKDIR /home/spark/build/OpenColorIO/build
RUN cmake .. && make -j18
USER root
RUN make install
USER spark

WORKDIR /home/spark/build/blender
RUN make || true
RUN cmake -G 'Unix Makefiles' -DOPTIX_INCLUDE_DIR=/home/spark/NVIDIA-OptiX-SDK-9.0.0-linux64-aarch64/include \
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
-DWITH_NANOVDB=ON -DWITH_VULKAN_BACKEND=OFF -DWITH_CYCLES=ON \
-DOPENIMAGEDENOISE_LIBRARY=/home/spark/build/oidn/build/libOpenImageDenoise.so \
-DOPENIMAGEDENOISE_OPENIMAGEDENOISE_LIBRARY=/home/spark/build/oidn/build/libOpenImageDenoise.so \
-DOPENIMAGEDENOISE_COMMON_LIBRARY=/home/spark/build/oidn/build/libOpenImageDenoise.so \
-DOPENIMAGEDENOISE_INCLUDE_DIR=/home/spark/build/oidn/include \
-DSSE2NEON_INCLUDE_DIR=/home/spark/build/sse2neon \
-DOPENIMAGEIO_INCLUDE_DIR=/home/spark/build/OpenImageIO/dist/include \
-DOPENIMAGEIO_LIBRARY=/home/spark/build/OpenImageIO/dist/lib/libOpenImageIO.so \
-DOPENIMAGEIO_TOOL=/home/spark/build/blender/OpenImageIO/dist/bin/oiiotool \
-DOPENIMAGEIO_UTIL_LIBRARY=/home/spark/build/OpenImageIO/dist/lib/libOpenImageIO_Util.so \
-DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_VERBOSE_MAKEFILE=ON -DPYTHON_NUMPY_INCLUDE_DIRS=/usr/local/lib/python3.11/site-packages/numpy/_core/include \
-DOPENCOLORIO_INCLUDE_DIR=/usr/local/include -D \
../build_linux
COPY blender.patch /home/spark/build/blender/
RUN git apply blender.patch
RUN make -j19
USER root
RUN apt-get install -y x11-apps
