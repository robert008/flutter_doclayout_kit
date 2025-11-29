cmake_minimum_required(VERSION 3.10)
project(doc_layout_kit)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Source files
set(SOURCES
    native_lib.cpp
    detect/doc_detector.cpp
    detect/config_manager.cpp
    detect/utils.cpp
)

# Header directories
set(INCLUDE_DIRS
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/detect/include
)

# Dependencies (user needs to set these paths)
# set(OPENCV_DIR "/path/to/opencv")
# set(ONNXRUNTIME_DIR "/path/to/onnxruntime")

# For Android NDK build
if(ANDROID)
    find_package(OpenCV REQUIRED)

    add_library(doc_layout_kit SHARED ${SOURCES})

    target_include_directories(doc_layout_kit PRIVATE
        ${INCLUDE_DIRS}
        ${ONNXRUNTIME_DIR}/include
    )

    target_link_libraries(doc_layout_kit
        ${OpenCV_LIBS}
        ${ONNXRUNTIME_DIR}/lib/${ANDROID_ABI}/libonnxruntime.so
        log
    )
endif()

# For iOS build
if(IOS)
    find_package(OpenCV REQUIRED)

    add_library(doc_layout_kit STATIC ${SOURCES})

    target_include_directories(doc_layout_kit PRIVATE
        ${INCLUDE_DIRS}
        ${ONNXRUNTIME_DIR}/include
    )

    target_link_libraries(doc_layout_kit
        ${OpenCV_LIBS}
    )
endif()

# For desktop build (testing)
if(NOT ANDROID AND NOT IOS)
    find_package(OpenCV REQUIRED)

    add_library(doc_layout_kit STATIC ${SOURCES})

    target_include_directories(doc_layout_kit PRIVATE
        ${INCLUDE_DIRS}
        ${OpenCV_INCLUDE_DIRS}
        ${ONNXRUNTIME_DIR}/include
    )

    target_link_libraries(doc_layout_kit
        ${OpenCV_LIBS}
    )
endif()
