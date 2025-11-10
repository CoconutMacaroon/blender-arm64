# Running Blender on ARM64 Linux with Vulkan

This guide explains how to compile Blender and the necessary dependencies from source to make it run on ARM64 Linux devices with Cycles and Vulkan, such as a RPi 5.

## Rationale

While Blender does exist in the Ubuntu repos, it's an older version of Blender. Snap only supports AMD64, and [Backports](https://help.ubuntu.com/community/UbuntuBackports) aren't currently available.

## Current status

I've tested this on DGX OS 7. Depending on which options are selected, I've gotten up to 98% of Blender's tests to pass and Vulkan seems to work in Blender.

As a real-world test on a GB10 system, [the Classroom demo](https://www.blender.org/download/demo-files/#cycles) works with either CUDA or OptiX selected as the Cycles render device. OptiX denoising also works.

![Screenshot of Blender 5.1.0 Alpha running with OptiX enabled on a GB10 system](classroom.png)
<sup>[Classroom](https://www.blender.org/download/demo-files/#cycles) by Christophe Seux. is licensed under CC0</sup>

## Building Blender from source

> [!CAUTION]
> As this process manually installs system files and packages, **it may break your installation of DGX OS** and/or create conflicts with certain packages.

Clone this repo, `cd` into it, and run `bash ./builder.sh`.

* The first time you run it, you'll be prompted to download the NVIDIA OptiX SDK. After downloading the OptiX SDK installer, you should move it from `~/Downloads` to `~/` and let it install into `NVIDIA-OptiX-SDK-9.0.0-linux64-aarch64`.
* After building Blender the first time you'll probably want to comment-out `git apply spark.patch` along with these lines:
  ```bash
  set +e
  make
  set -e
  ```
* Certain features, such as NumPy, OpenColorIO, and OpenSSL may not work out of the box, but should be possible.

If it crashes when you run it, see [this](https://devtalk.blender.org/t/ubuntu-24-04-build-from-source-blender-crashes-at-startup/40853/10).
