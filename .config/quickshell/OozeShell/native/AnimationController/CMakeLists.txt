cmake_minimum_required(VERSION 3.21)
project(OozeShellNative LANGUAGES CXX)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml)
qt_standard_project_setup(REQUIRES 6.5)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Salida con la estructura que QML espera:  <build>/qml/OozeShell/Native/{qmldir,*.so,...}
set(OOZE_QML_OUT ${CMAKE_BINARY_DIR}/qml/OozeShell/Native)

# PLUGIN_TARGET == target  →  una sola .so (backing + plugin), sin rutas rpath raras.
qt_add_qml_module(oozeshell_native
    URI OozeShell.Native
    VERSION 1.0
    PLUGIN_TARGET oozeshell_native
    OUTPUT_DIRECTORY ${OOZE_QML_OUT}
    SOURCES
        AnimationController.h
        AnimationController.cpp
        # ── Widgets: fuentes de datos (ver WIDGETS/ y docs/WIDGETS.md) ──
        ActiveSource.h
        SystemStats.h
        SystemStats.cpp
        # ── Sistema: métricas y procesos para la app System Monitor ──
        SystemMonitor.h
        SystemMonitor.cpp
        ProcessList.h
        ProcessList.cpp
        # ── Fuentes: reconoce/registra las que el tema necesita ──
        FontProbe.h
        FontProbe.cpp
        WmStream.h
        WmStream.cpp
        MemoryTrim.h
        MemoryTrim.cpp
)

set_target_properties(oozeshell_native PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${OOZE_QML_OUT}
)
target_link_libraries(oozeshell_native PRIVATE Qt6::Core Qt6::Gui Qt6::Qml)
