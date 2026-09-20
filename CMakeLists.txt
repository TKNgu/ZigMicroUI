cmake_minimum_required(VERSION 3.14)

if(POLICY CMP0135)
    cmake_policy(SET CMP0135 NEW)
endif()

project(TheGame_Dependencies NONE) 

set(INSTALL_PREFIX "${CMAKE_CURRENT_SOURCE_DIR}/lib/local/")

include(ExternalProject)

function(build_git_lib name repo tag depends)
    ExternalProject_Add(${name}
        GIT_REPOSITORY ${repo}
        GIT_TAG ${tag}
        GIT_SHALLOW TRUE
        DEPENDS ${depends}
        CMAKE_ARGS
            -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX}
            -DCMAKE_PREFIX_PATH=${INSTALL_PREFIX}
            -DCMAKE_BUILD_TYPE=Release
            -DCMAKE_INSTALL_LIBDIR=${CMAKE_INSTALL_LIBDIR}
            # ---------------------------------------------------------
            ${ARGN}
    )
endfunction()

function(build_tar_lib name url depends)
    ExternalProject_Add(${name}
        URL ${url}
        DOWNLOAD_EXTRACT_TIMESTAMP TRUE
        DEPENDS ${depends}
        CMAKE_ARGS
            -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX}
            -DCMAKE_PREFIX_PATH=${INSTALL_PREFIX}
            -DCMAKE_BUILD_TYPE=Release
            -DCMAKE_INSTALL_LIBDIR=${CMAKE_INSTALL_LIBDIR}
            # ---------------------------------------------------------
            ${ARGN}
    )
endfunction()

# --- Libraries ---
# wayland-devel libxkbcommon-devel MesaLib-devel pkg-config

# 1. bzip2 & zlib
build_git_lib(libbzip2 https://gitlab.com/bzip2/bzip2 master "" 
    -DBUILD_SHARED_LIBS=OFF)

build_git_lib(libzlib https://github.com/madler/zlib.git v1.3.2 "")

# 2. libpng 
build_tar_lib(libpng "https://sourceforge.net/projects/libpng/files/libpng16/1.6.58/libpng-1.6.58.tar.xz" "libzlib")

# 3. brotli
build_git_lib(libbrotli https://github.com/google/brotli.git v1.2.0 "")

# 4. freetype 
build_tar_lib(freetype "https://download.savannah.gnu.org/releases/freetype/freetype-2.14.3.tar.xz" "libpng;libzlib;libbzip2;libbrotli")

# 5. SDL3
build_git_lib(libSDL https://github.com/libsdl-org/SDL.git release-3.2.18 "" 
    -DSDL_SHARED=OFF -DSDL_STATIC=ON -DSDL_VIDEO=ON -DSDL_WAYLAND=ON -DSDL_X11=OFF)

# 6. SDL_image
build_git_lib(libSDL_image https://github.com/libsdl-org/SDL_image.git release-3.2.4 "libSDL" 
    -DBUILD_SHARED_LIBS=OFF)

# 7. harfbuzz 
build_git_lib(libharfbuzz https://github.com/harfbuzz/harfbuzz.git 14.1.0 "freetype" 
    -DBUILD_SHARED_LIBS=OFF -DHB_HAVE_FREETYPE=ON)

# 8. plutovg
build_git_lib(libplutovg https://github.com/sammycage/plutovg.git v1.3.2 "" 
    -DBUILD_SHARED_LIBS=OFF)

# 9. SDL_ttf
build_git_lib(libSDL_ttf https://github.com/libsdl-org/SDL_ttf.git release-3.2.2 "libSDL;freetype;libharfbuzz" 
    -DBUILD_SHARED_LIBS=OFF)
