# Native AnimationController (siguiente etapa)

Este módulo C++ es el prototipo nativo equivalente al controlador QML usado ahora por `Theme`. No se importa todavía desde el shell: la configuración actual funciona sin compilar nada y guarda el modo en `~/.config/oozeshell/ui.json`.

## Compilar el módulo

Desde esta carpeta, con Qt 6.5+, CMake y Ninja instalados:

```sh
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

Para integrarlo de verdad, añade el módulo compilado a la ruta de importación QML que usa tu paquete de Quickshell y cambia las llamadas `Theme.animDuration(...)` por el controlador nativo. La ruta exacta depende de cómo esté instalado Quickshell (Nix `withModules`, paquete de distro o build local); no se fuerza una ruta de importación que podría romper la shell.


## Estado (optimización)

En pausa a propósito: hoy solo reemplaza `Theme.animDuration()` y no reduce VRAM ni CPU de forma medible. Ver `docs/OPTIMIZACION.md` §2 para la decisión y cuándo retomarlo.
