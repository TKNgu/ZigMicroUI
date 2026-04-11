Install lib: 

git clone --depth=1 https://gitlab.com/bzip2/bzip2 lib/bzip2/
cmake -S lib/bzip2/ -B lib/build/bzip2/ \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=lib/install/ \
    -DBUILD_SHARED_LIBS=OFF
cmake --build lib/build/bzip2/
cmake --install lib/build/bzip2/

git clone --depth=1 https://github.com/madler/zlib.git lib/zlib/
cmake -S lib/zlib/ -B lib/build/zlib/ \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=lib/install/ \
    -DBUILD_SHARED_LIBS=OFF
cmake --build lib/build/zlib/
cmake --install lib/build/zlib/

Download libpng https://libpng.sourceforge.io/index.html
cmake -S lib/libpng/ -B lib/build/libpng/ \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=lib/install/ \
    -DBUILD_SHARED_LIBS=OFF
cmake --build lib/build/libpng/
cmake --install lib/build/libpng/

git clone --depth=1 https://github.com/google/brotli.git --branch=v1.2.0 lib/brotli/
cmake -S lib/brotli/ -B lib/build/brotli/ \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=lib/install/ \
    -DBUILD_SHARED_LIBS=OFF
cmake --build lib/build/brotli/
cmake --install lib/build/brotli/

Download lib freetype from https://download.savannah.gnu.org/releases/freetype/
cmake -S lib/freetype-2.14.3/ -B lib/build/freetype/ \
    -DCMAKE_INSTALL_PREFIX=lib/install/ \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_PREFIX_PATH=lib/install/
cmake --build lib/build/freetype/
cmake --install lib/build/freetype/

git clone --depth=1 https://github.com/libsdl-org/SDL.git --branch=release-3.2.18 lib/SDL
cmake -S lib/SDL -B lib/build/SDL \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=lib/install/ \
    -DSDL_SHARED=OFF \
    -DSDL_STATIC=ON \
    -DSDL_VIDEO=ON \
    -DSDL_WAYLAND=ON \
    -DSDL_X11=OFF
cmake --build lib/build/SDL -j5
cmake --install lib/build/SDL

git clone --depth=1 https://github.com/libsdl-org/SDL_image.git --branch=release-3.2.4 lib/SDL_image
cmake -S lib/SDL_image -B lib/build/SDL_image \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=lib/install/ \
    -DSDL3_DIR=lib/install/ \
    -DBUILD_SHARED_LIBS=OFF
cmake --build lib/build/SDL_image -j5
cmake --install lib/build/SDL_image

git clone --depth=1 https://github.com/harfbuzz/harfbuzz.git --branch=14.1.0 lib/harfbuzz
cmake -S lib/harfbuzz -B lib/build/harfbuzz \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=lib/install/ \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_PREFIX_PATH=lib/install/ \
    -DHB_HAVE_FREETYPE=ON
cmake --build lib/build/harfbuzz -j5
cmake --install lib/build/harfbuzz

git clone --depth=1 https://github.com/sammycage/plutovg.git --branch=v1.3.2 lib/plutovg
cmake -S lib/plutovg -B lib/build/plutovg \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=lib/install/ \
    -DBUILD_SHARED_LIBS=OFF
cmake --build lib/build/plutovg -j5
cmake --install lib/build/plutovg

<!-- git clone --depth=1 https://github.com/sammycage/plutosvg.git --branch=v0.0.7 lib/plutosvg -->
<!-- cmake -S lib/plutosvg -B lib/build/plutosvg \ -->
<!--     -DCMAKE_BUILD_TYPE=Release \ -->
<!--     -DCMAKE_INSTALL_PREFIX=lib/install/ \ -->
<!--     -DBUILD_SHARED_LIBS=OFF -->
<!-- cmake --build lib/build/plutosvg -j5 -->
<!-- cmake --install lib/build/plutosvg -->

git clone --depth=1 https://github.com/libsdl-org/SDL_ttf.git --branch=release-3.2.2 lib/SDL_ttf
cmake -S lib/SDL_ttf -B lib/build/SDL_ttf \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=lib/install/ \
    -DSDL3_DIR=lib/install/ \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_PREFIX_PATH=lib/install
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



mu_begin_window_ex:
    -> Lay id moi cho doi tuong cua so hien tai. Giu nguy giua cac frame
    -> Lay container tu pool. Giu nguyen giua cac frame.
    -> Kiem tra trang thai cua container dang mo, dong, an hien.


1. Bat dau khoi render co ban theo thiet ke cung.
-> rect, text, icon.

2. ID duoc sinh theo hash stack, dam bao giong nhau sau moi lan ve.

static void hash(mu_Id *hash, const void *data, int size) {
  const unsigned char *p = data;
  while (size--) {
    *hash = (*hash ^ *p++) * 16777619;
  }
}

mu_Id mu_get_id(mu_Context *ctx, const void *data, int size) {
  int idx = ctx->id_stack.idx;
  mu_Id res = (idx > 0) ? ctx->id_stack.items[idx - 1] : HASH_INITIAL;
  hash(&res, data, size);
  ctx->last_id = res;
  return res;
}

3. Container la doi tuong luu thong tin giua cac fram vi tri cuon, dong mo ->
    thong tin runtime.
Cac container duoc luu trong 1 poll giua cac frame duoc truy van thong qua id
Chuoi lenh ve -> toi uu khong sinh lai.
Kich thuoc, kich thuoc vung ben trong,
Content -> cho cuon
Vi tri cuon truoc do
Zindex
trang thai dong mo.

4. id_stack -> dung de sinh id theo hash

5. Ctainer stack -> runtime build moi moi khung
6. Root list -> danh sach cac cua so de so sanh zindex -> thu tu ve truoc sau 
7. push_jump -> dau chuoi lenh ve.
Sau khi co thu tu ve thuc hien nhay den cac vi tri ve -> mot dang render engin.
8. Kiem tra vi tri chuot de thuc hien cac thao tac input
9. Stack clip
