set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)

set(CUSTOM_LIB_PATH /cross-chroot)
set(CMAKE_INSTALL_PREFIX '${CUSTOM_LIB_PATH}' CACHE PATH "Custom library path for arm" FORCE)

set(TOOLCHAIN toolchain_here)
set(CMAKE_C_COMPILER ${TOOLCHAIN}gcc)
set(CMAKE_CXX_COMPILER ${TOOLCHAIN}g++)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
