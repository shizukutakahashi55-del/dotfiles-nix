cmake_minimum_required(VERSION 3.21)
project(OozeShellAnimationController LANGUAGES CXX)
find_package(Qt6 6.5 REQUIRED COMPONENTS Core Qml)
qt_standard_project_setup(REQUIRES 6.5)
qt_add_qml_module(oozeshell-animation-controller
    URI OozeShell.Native
    VERSION 1.0
    SOURCES AnimationController.h
)
target_link_libraries(oozeshell-animation-controller PRIVATE Qt6::Core Qt6::Qml)
target_compile_features(oozeshell-animation-controller PRIVATE cxx_std_17)
