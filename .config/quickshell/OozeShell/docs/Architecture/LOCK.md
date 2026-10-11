# LOCK — pantalla de bloqueo Wayland con autenticación PAM

- Qué es: bloqueo de sesión vía `WlrSessionLock` con campo de contraseña que autentica contra PAM (`config: "login"`). Al bloquear cierra todos los popups y limpia fondos temporales.
- Archivos:
  - `LOCK/LockScreen.qml` → `WlrSessionLock`, lógica `lock()`/`locked`, `Pam` (`Quickshell.Services.Pam`), captura de teclado
  - `LOCK/LockField.qml` → campo de contraseña (puntos, estado `checking`)
  - `LOCK/LockChip.qml` → chip/etiqueta decorativa
  - `LOCK/qmldir` → registro del módulo
- IPC (`shell.qml`, target `lock`):

  | Función | Efecto |
  |---|---|
  | `lock` | cierra popups y bloquea (`lockScreen.lock()`) |
  | `locked` | devuelve `bool` con el estado de bloqueo |

  ```sh
  quickshell ipc -p .../shell.qml call -- lock lock
  quickshell ipc -p .../shell.qml call -- lock locked
  ```
- Estado y datos: sin singleton ni JSON. `locked` refleja `sessionLock.locked` (`LockScreen.qml:20`); `password` vive solo en memoria y se vacía tras responder a PAM. Fondos temporales `~/.cache/oozeshell/lock-bg-*` (se borran al bloquear, `LockScreen.qml:107-133`).
- Dependencias: `../COMMON`, `../LANG`, `Quickshell.Wayland` (`WlrSessionLock`), `Quickshell.Services.Pam`, `Quickshell.Io`.
- Notas: si PAM está ocupado (`pam.active`) se aborta antes de reintentar; usa animación `Theme.animDuration`, no bucles continuos.
