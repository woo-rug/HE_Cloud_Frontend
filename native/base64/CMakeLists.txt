cmake_minimum_required(VERSION 3.12)
project(seal_wrapper)

set(CMAKE_CXX_STANDARD 17)

find_package(SEAL 4.1 REQUIRED)

add_library(seal_wrapper SHARED base64.cpp seal_wrapper.cpp)

target_link_libraries(seal_wrapper SEAL::seal)