cmake_minimum_required(VERSION 3.10)
project(native_analyzer)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Include 경로 설정 (Eigen, streamvbyte, Kiwi)
include_directories(
    Kiwi-main/include
    /opt/homebrew/include/eigen3
    /usr/local/include/eigen3
    /opt/homebrew/include
    /usr/local/include
)

# streamvbyte 라이브러리 찾기
find_library(STREAMVBYTE_LIB streamvbyte HINTS /opt/homebrew/lib /usr/local/lib)
if(NOT STREAMVBYTE_LIB)
    message(WARNING "streamvbyte not found. Run 'brew install streamvbyte'")
endif()

# 기본 소스 파일
file(GLOB BASE_SOURCES "Kiwi-main/src/*.cpp")

# [수정] 아키텍처별 구현체 설정 (오류 회피를 위해 모두 none.cpp 사용)
# 원래 ARM64는 neon.cpp를 써야 하지만, 템플릿 오류가 발생하므로 기본 구현체 사용
set(ARCH_SOURCES "Kiwi-main/src/archImpl/none.cpp")

message(STATUS "Using generic architecture implementation (none.cpp) to avoid SIMD errors.")

# 스레드 라이브러리
find_package(Threads REQUIRED)

# 라이브러리 생성
add_library(native_analyzer SHARED 
    native_analyzer.cpp 
    ${BASE_SOURCES} 
    ${ARCH_SOURCES}
)

target_link_libraries(native_analyzer 
    PRIVATE 
    Threads::Threads
    ${STREAMVBYTE_LIB}
)