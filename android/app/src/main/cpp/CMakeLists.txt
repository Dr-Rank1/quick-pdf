cmake_minimum_required(VERSION 3.4.1)

project(bbhelper LANGUAGES CXX)

# Local rebuild of the pdf_render_maintained plugin's libbbhelper.so so it is
# linked with 16 KB page-size alignment (Google Play requirement for apps
# targeting Android 15+). The upstream plugin still ships a 4 KB-aligned
# library, which Play rejects. Source is identical to the plugin's own
# android/c++/directBufferAndroid.cpp.
add_library(bbhelper SHARED directBufferAndroid.cpp)

target_compile_options(bbhelper PRIVATE -DBUILD_FOR_ANDROID)

target_link_options(bbhelper PRIVATE
    "-Wl,-z,max-page-size=16384"
    "-Wl,-z,common-page-size=16384"
)
