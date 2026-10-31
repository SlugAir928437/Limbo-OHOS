cmake_minimum_required(VERSION 3.5.0)
project(limbo)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# HarmonyOS Next 原生层：N-API 桥 + 进程内 QEMU（TCG）。
# QEMU / SDL 都以 .so 形式随应用打包，liblimbo 自己不做静态链接：
#   entry/libs/<abi>/libqemu-system-x86_64.so   （由 QEMU 仓库的 build-ohos.sh 产出）
#   entry/libs/<abi>/libSDL2.so                 （由 ohos_sdl2 工程产出）
include_directories(${CMAKE_CURRENT_SOURCE_DIR})

add_library(limbo SHARED
    limbo_vm.cpp
    napi_init.cpp)

target_link_libraries(limbo PUBLIC
    libace_napi.z.so
    libace_ndk.z.so
    libhilog_ndk.z.so
    dl
    pthread)
