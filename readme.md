Install lib: 
git clone --depth=1 https://github.com/libsdl-org/SDL.git --branch=release-3.2.18 lib/SDL
cmake -S lib/SDL -B lib/build/SDL \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=lib/install/ \
    -DSDL_SHARED=OFF \
    -DSDL_STATIC=ON \
    -DSDL_VIDEO=ON \
    -DSDL_WAYLAND=ON \
    -DSDL_X11=OFF
cmake -C lib/build/SDL --build
cmake --build lib/build/SDL -j5
cmake --install lib/build/SDL

git clone --depth=1 https://github.com/libsdl-org/SDL_image.git --branch=release-3.2.4 lib/SDL_image
cmake -S lib/SDL_image -B lib/build/SDL_image \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=lib/install/ \
    -DSDL3_DIR=lib/install/ \
    -DBUILD_SHARED_LIBS=OFF
cmake -C lib/build/SDL_image --build
cmake --build lib/build/SDL_image -j5
cmake --install lib/build/SDL_image

git clone --depth=1 https://github.com/libsdl-org/SDL_ttf.git --branch=release-3.2.2 lib/SDL_ttf
cmake -S lib/SDL_ttf -B lib/build/SDL_ttf \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=lib/install/ \
    -DSDL3_DIR=lib/install/ \
    -DBUILD_SHARED_LIBS=OFF
cmake -C lib/build/SDL_ttf --build
cmake --build lib/build/SDL_ttf -j5
cmake --install lib/build/SDL_ttf


Ham init khoi tao opengl render.

ctx thong tin kich thuoc cua so.
su kien chuot

reset trang thai bien ctx, cap nhat cac thong tin toa do chuot, khung hinh vao ctx.

-> CTX  bien trang thai cua he thong truy cap global.

mu_end: cap nhat trang thai cuoi scroll
cap nhat doi tuong hover
thay doi thu tu lenh de dua container len tren cung

-> Cach tao thu tu hien thi bang ky thuat nhay lenh ve.

Tinh hash id cho doi tuong render dua tren stack render
ID nay duoc dung de dinh danh doi tuong focus.
Stack id duoc push, pop tinh id tiep.

Tuong tuu stack clip dung tron cac vung cat.

-> Bat dau voi hej thong imgui don gian vowis id theo stack, va container.

layout stack hien thi

lay container de gom ca thanh phan -> can lam ro container trong imgui

dinh nghia pool thuc hien get, update.

cac ham dau vao trang thai.

Man lenh ve draw box, draw text, draw icon, 

Khoi layout doi tuong

Xu ly phan ung chuot voi cac doi tuong

Cac doi tuong build in.

scroll doi tuong

cac doi tuong container, window, controller,


1. Bat dau khoi render co ban theo thiet ke cung.
-> rect, text, icon.
