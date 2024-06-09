# CrossArm

Just another crosscompiling tool for arm/aarch64 GNU/Linux.

The aim of this project was to make crosscompiling as simple as possible.

The docker image is using **Ubuntu 20.04** for better **GLIBC** support.

### Toolchains 
- Arm 13.2 Release 1
- Aarch64 10.3 (2021.07)

# Installing
You can easily install CrossArm using the build script

_**You must run the install script as root**_

`./install.sh` (Default architecture is **arm**)

For list of arguments use the help argument

`./install.sh -h`


The script builds a docker ubuntu image with the selected architecture toolchain.

Script for running the crosscompiling environment is installed in `/usr/bin`.\
The name of the script is `crossarm-{architecture}` eg. `crossarm-arm`, `crossarm-aarch64`.

# Uninstall
To uninstall use `./install.sh -u`. (Keeps the chroot directory `/opt/crossarm-{architecture}`)\
For complete uninstall use `./install.sh -u -p`

# Usage
To open current directory in the crosscompile environment just run the `crossarm-{architecture}` script.\
If you want to open a different directory in the environment run `crossarm-{architecture} /path/to/dir`.

The whole toolchain `/toolchain` is added in the `PATH` variable for more convenient usage.

To not lose the installed libraries, a folder `/cross-chroot` has been added, the folder is shared with the host in `/opt/crossarm-{architecture}`.\
Therefore whenever you want to install a library and preserve it, use prefix `/cross-chroot`.

# Examples
*I will be using __aarch64__ for these examples*.

## Building simple C/C++ program

File `main.c`
```c
#include <stdio.h>

int main() {
    printf("Hello arm\n");
    return 0;
}
```

Enter the environent `crossarm-aarch64`\
Now you can build it using `aarch64-none-linux-gnu-gcc main.c -o main`\
And viola 
```shell
❯ file main
main: ELF 64-bit LSB executable, ARM aarch64, version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux-aarch64.so.1, for GNU/Linux 3.7.0, with debug_info, not stripped
```

## Building using CMake
For CMake nothing much changes. You just need to add the toolchain into your **CMakeFile** which is located in `/opt/toolchain.cmake`

```cmake
set(CMAKE_TOOLCHAIN_FILE /opt/toolchain.cmake)
```

## TODO
- [x] ~Run the commands using oneliner without entering the docker~
