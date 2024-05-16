


if(APPLE)
    enable_language(OBJC)
    enable_language(OBJCXX)
endif()

message( "Project lib name '${PROJECT_LIB_NAME}'")
add_library(${PROJECT_LIB_NAME} SHARED
${PROJECT_ADDITIONAL_SOURCES}
src/idl_${TARGET_HOST}.cpp
)

if (PROJECT_BUILD_STATIC)
set(PROJECT_STATIC_LIB_NAME ${PROJECT_LIB_NAME}_s)
ADD_LIBRARY( ${PROJECT_STATIC_LIB_NAME} STATIC
${PROJECT_ADDITIONAL_SOURCES}
src/idl_${TARGET_HOST}.cpp
)

set_target_properties(${PROJECT_STATIC_LIB_NAME}
PROPERTIES
OUTPUT_NAME "${PROJECT_LIB_NAME}_hdll"
)

target_include_directories(${PROJECT_STATIC_LIB_NAME}
PRIVATE
${PROJECT_ADDITIONAL_INCLUDES}
${TARGET_INCLUDE_DIR}
${LOCAL_INC}
)
endif()


set_target_properties(${PROJECT_LIB_NAME}
PROPERTIES
PREFIX ""
OUTPUT_NAME ${PROJECT_LIB_NAME}
SUFFIX ${PROJECT_LIB_SUFFIX}
INTERPROCEDURAL_OPTIMIZATION TRUE
)

if(WIN32)
    set(CMAKE_MSVC_RUNTIME_LIBRARY  "MultiThreadedDLL")
    set_target_properties(${PROJECT_LIB_NAME} PROPERTIES MSVC_RUNTIME_LIBRARY "MultiThreadedDLL")
    get_property( LIB_MSVC_RT TARGET ${PROJECT_LIB_NAME} PROPERTY MSVC_RUNTIME_LIBRARY)
    message("Library ${PROJECT_LIB_NAME} us using ${LIB_MSVC_RT} runtime")
endif()



message( "Adding ${TARGET_INCLUDE_DIR} to include ")
target_include_directories(${PROJECT_LIB_NAME} 
PRIVATE
${PROJECT_ADDITIONAL_INCLUDES}
${TARGET_INCLUDE_DIR}
${LOCAL_INC}
)

link_directories(${PROJECT_LIB_NAME} BEFORE
${PROJECT_ADDITIONAL_LIB_DIRS}
${LOCAL_LIB}
)
message( "Adding ${PROJECT_ADDITIONAL_LIB_DIRS} to link directories ")

set(ALL_LIBS 
${TARGET_LIBS}
${PROJECT_ADDITIONAL_LIBS}
)

target_compile_definitions(${PROJECT_LIB_NAME} PUBLIC 
${PROJECT_ADDITIONAL_COMPILE_DEFINITIONS}
)

target_link_libraries(${PROJECT_LIB_NAME} ${ALL_LIBS})

set_property(TARGET ${PROJECT_LIB_NAME} PROPERTY CXX_STANDARD 20)

string(TOUPPER "IDL_${TARGET_HOST}" IDL_DEFINE)

SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -D${IDL_DEFINE} -g")
if (UNIX)
    # Some special flags are needed for GNU GCC compiler
    SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++20 -fPIC  -O3  -fpermissive")
    #not sure why the ${HL_LIB_DIR} is necessary given the above.
    SET(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} -shared  ")
endif (UNIX)

install(TARGETS ${PROJECT_LIB_NAME} ${PROJECT_STATIC_LIB_NAME})