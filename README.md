# Running Blender on ARM64 Linux with Vulkan

This guide explains how to compile Blender and the necessary dependencies from source to make it run on ARM64 Linux devices with Cycles and Vulkan, such as a RPi 5.

## Limitations

* No official support for ARM64 Linux
* Hardware capabilities of ARM64 devices is heavily variable
    * Vulkan support varies, and in some cases may fall back to llvmpipe
    * Slower ARM64 devices may take an extremely long time to compile
* The Ubuntu repos tend to have older versions of Blender. While this is understandable from a release and packaging standpoint, it's a problem for Vulkan
* Snap only supports AMD64, and [Backports](https://help.ubuntu.com/community/UbuntuBackports) aren't available. In the open source spirit, it's possible [to propose one and do the work](https://wiki.ubuntu.com/UbuntuBackports#Responsibilities_of_the_Backporter), but it would likely be a non-trivial amount of ongoing work, as it's not just Blender, but also the dependencies

## Building Blender from source

The best path I found was to build Blender from source. This should, roughly, work on Ubuntu 24.04 LTS or Ubuntu 25.04.

You need a few dependencies to build a _minimal_ build of Blender.

### Python 3.11

It's technically possible to force cmake to use a newer version of Python, but using 3.11 is easier.

```bash
$ cd /
$ wget 'https://www.python.org/ftp/python/3.11.13/Python-3.11.13.tar.xz' && tar xvf 'Python-3.11.13.tar.xz' && rm -v 'Python-3.11.13.tar.xz'
$ cd /Python-3.11.13
$ ./configure --without-doc-strings
$ make -s -j $(nproc) && make altinstall
```
For a performance boost at the expense of compile time, you can add `--with-optimizations --with-lto=full` to the `./configure`.

### OpenImageDenoise

This requires [ISPC](https://ispc.github.io/), so we also download that.

```bash
$ cd /
$ wget 'https://github.com/ispc/ispc/releases/download/v1.27.0/ispc-v1.27.0-linux.aarch64.tar.gz' && tar xvf 'ispc-v1.27.0-linux.aarch64.tar.gz' && rm -v 'ispc-v1.27.0-linux.aarch64.tar.gz' && git clone --recursive https://github.com/OpenImageDenoise/oidn.git
$ cd /oidn/build
$ cmake -G Ninja -D ISPC_EXECUTABLE=/ispc-v1.27.0-linux.aarch64/bin/ispc .. && ninja
```

### sse2neon

No need to compile this, just clone it.

```bash
$ git clone https://github.com/DLTcollab/sse2neon
```
### oneTBB
Don't forget to `purge --autoremove libtbb-dev` if you previously installed it!
```bash
$ cd /
$ git clone https://github.com/uxlfoundation/oneTBB
$ cd /oneTBB/build
$ cmake -DTBB_TEST=OFF .. && cmake --build . && cmake --install .
```

### OpenImageIO

```bash
$ cd /
$ git clone --depth 1 https://github.com/AcademySoftwareFoundation/OpenImageIO
$ cd /OpenImageIO
$ cmake -B build -DOpenImageIO_BUILD_MISSING_DEPS=all -S . && cmake --build build --target install
```

### Vulkan

This is the big thing here. Depending on what your distro ships, you might not need to build it yourself. For me, I needed to build it for 24.04 LTS but not 24.04. If you choose to build it, here's how. You should `purge --autoremove libvulkan-dev libshaderc-dev` first.

```docker
$ cd /
$ wget 'https://sdk.lunarg.com/sdk/download/1.4.321.1/linux/vulkansdk-linux-x86_64-1.4.321.1.tar.xz' &&\
    tar xvf 'vulkansdk-linux-x86_64-1.4.321.1.tar.xz'
$ cd /1.4.321.1
$ apt-get update && apt-get install -y sudo libxrandr-dev
$ ./vulkansdk --maxjobs vulkan-loader shaderc
$ cp -rv /1.4.321.1/aarch64/bin/* /usr/bin/ &&\
  cp -rv /1.4.321.1/aarch64/lib/* /usr/lib/ &&\
  cp -rv /1.4.321.1/aarch64/include/* /usr/include/ &&\
  cp -rv /1.4.321.1/aarch64/share/* /usr/share/
```

I only compiled `vulkan-loader` & `shaderc`, but you _could_ just do `./vulkansdk --maxjobs` to build it all, including some test Vulkan programs. If you're using Docker, consider adding `--skip-deps` to `./vulkansdk`.

### Blender itself

> [!IMPORTANT]
> You need to install Git LFS support _first_.

```bash
$ cd /
$ git clone --progress --depth 1 https://projects.blender.org/blender/blender.git
$ cd /blender
$ make ninja  # This will fail: it's only here for setup
$ cmake -G Ninja -DWITH_ALEMBIC=OFF -DWITH_BLENDER_THUMBNAILER=OFF -DWITH_BUILDINFO=OFF -DWITH_BULLET=OFF -DWITH_CODEC_FFMPEG=OFF -DWITH_CODEC_SNDFILE=OFF -DWITH_CYCLES_DEBUG=ON -DWITH_CYCLES_DEVICE_OPTIX=OFF -DWITH_CYCLES_OSL=OFF -DWITH_CYCLES_PATH_GUIDING=OFF -DWITH_DRACO=OFF -DWITH_FFTW3=OFF -DWITH_FREESTYLE=OFF -DWITH_GHOST_XDND=OFF -DWITH_GMP=OFF -DWITH_HARU=OFF -DWITH_HYDRA=OFF -DWITH_IK_ITASC=OFF -DWITH_IK_SOLVER=OFF -DWITH_IMAGE_CINEON=OFF -DWITH_IMAGE_OPENEXR=OFF -DWITH_IMAGE_OPENJPEG=OFF -DWITH_IMAGE_WEBP=OFF -DWITH_INPUT_IME=OFF -DWITH_INPUT_NDOF=OFF -DWITH_IO_GREASE_PENCIL=OFF -DWITH_JACK=OFF -DWITH_MANIFOLD=OFF -DWITH_MATERIALX=OFF -DWITH_MOD_FLUID=OFF -DWITH_MOD_OCEANSIM=OFF -DWITH_OPENAL=OFF -DOPENCOLORIO=OFF -DWITH_OPENVDB=OFF -DWITH_OPENVDB_BLOSC=OFF -DWITH_PIPEWIRE=OFF -DWITH_PULSEAUDIO=OFF -DWITH_PYTHON_INSTALL_NUMPY=OFF -DWITH_PYTHON_INSTALL_REQUESTS=OFF -DWITH_PYTHON_INSTALL_ZSTANDARD=OFF -DWITH_PYTHON_NUMPY=OFF -DWITH_PYTHON_SAFETY=ON -DWITH_QUADRIFLOW=OFF -DWITH_UI_TESTS_HEADLESS=OFF -DWITH_X11_XFIXES=OFF -DWITH_X11_XINPUT=OFF -DWITH_MOD_REMESH=OFF -DWITH_GHOST_X11=OFF -DWITH_GHOST_WAYLAND=OFF -DWITH_GHOST_WAYLAND_DYNLOAD=OFF -DWITH_GHOST_WAYLAND_LIBDECOR=OFF -DWITH_OPENCOLORIO=OFF -DWITH_XR_OPENXR=OFF -DWITH_USD=OFF -DWITH_CYCLES_DEVICE_CUDA=OFF -DWITH_CYCLES_DEVICE_HIP=OFF -DWITH_LZO=OFF -DWITH_LZMA=OFF -DWITH_NANOVDB=OFF -DWITH_VULKAN_BACKEND=ON -DWITH_CYCLES=ON -DOPENIMAGEDENOISE_LIBRARY=/oidn/build/libOpenImageDenoise.so -DOPENIMAGEDENOISE_OPENIMAGEDENOISE_LIBRARY=/oidn/build/libOpenImageDenoise.so -DOPENIMAGEDENOISE_COMMON_LIBRARY=/oidn/build/libOpenImageDenoise.so -DOPENIMAGEDENOISE_INCLUDE_DIR=/oidn/include -DSSE2NEON_INCLUDE_DIR=/sse2neon -DOPENIMAGEIO_INCLUDE_DIR=/OpenImageIO/dist/include -DOPENIMAGEIO_LIBRARY=/OpenImageIO/dist/lib/libOpenImageIO.so -DOPENIMAGEIO_TOOL=/OpenImageIO/dist/bin/oiiotool -DOPENIMAGEIO_UTIL_LIBRARY=/OpenImageIO/dist/lib/libOpenImageIO_Util.so -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_VERBOSE_MAKEFILE=ON ../build_linux
$ make ninja  # This time it should work
```

This uses `cmake` to make a Blender build with many features disabled. Of note:
* CUDA is disabled, turn that on if your ARM64 devices can make use of it
* It manually sets the path to a few libraries we build ourself (Python is excluded as we did `make altinstall`)
* It turns on Vulkan with Wayland support, but does *not* support X11
* Cycles is on
* It shuts off numpy. While numpy isn't inherently bad, fetching it requires `pip`, and I didn't take the time to get OpenSSL working, which `pip` needs (for `https://...`)

> [!TIP]
> If you don't mind a longer compile, feel free to remove the flags disabling many of those features. Nearly all of them should be easy to re-enable, possibly needing libraries that can simply be gotten via `apt`.

### Running it

To run it, just use this:
```bash
#!/usr/bin/env bash
LD_LIBRARY_PATH=/OpenImageIO/dist/lib:/oidn/build /build_linux/bin/blender
```

If it crashes when you run it, see [this](https://devtalk.blender.org/t/ubuntu-24-04-build-from-source-blender-crashes-at-startup/40853/10).
