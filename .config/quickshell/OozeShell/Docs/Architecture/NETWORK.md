# NETWORK + BLUETOOTH — menús de red Wi-Fi y Bluetooth del panel

- Qué es
  - Dos módulos paralelos con el mismo patrón: singleton `*Backend.qml` con el estado + menú `*Menu.qml` (PanelWindow `open`/`targetScreen`). `shell.qml` solo alterna `networkOpen`/`bluetoothOpen` vía `togglePopup`.
  - Ninguno persiste configuración propia; todo el estado es en vivo (NetworkManager vía `nmcli`, BlueZ vía `Quickshell.Bluetooth`).
- Archivos
  - `Services/Network/NetworkBackend.qml` → singleton: escaneo/conexión Wi-Fi vía `nmcli`, props `activeSsid/activeSignal/networks/savedNames/scanning/connectingSsid/errorText`.
  - `Services/Network/NetworkMenu.qml` → tarjeta del menú (lista de SSID, expansión con contraseña, `activate(net)`/`submitPassword(net)`).
  - `Services/Network/qmldir` → declara `singleton NetworkBackend`.
  - `Services/Bluetooth/BluetoothBackend.qml` → singleton: adaptador `Bluetooth.defaultAdapter`, `available/enabled/scanning/devices`, `activate(d)`/`forget(d)`/`setEnabled(on)`.
  - `Services/Bluetooth/BluetoothMenu.qml` → tarjeta del menú (lista de dispositivos, `busy`/`statusText` por fila).
  - `Services/Bluetooth/qmldir` → declara `singleton BluetoothBackend`.
- IPC (Core/Ipc/NetworkIpc.qml, target `network`; Core/Ipc/BluetoothIpc.qml, target `bluetooth`):
  | target | función | efecto |
  |---|---|---|
  | `network` | `toggle` | abre/cierra el menú de red |
  | `bluetooth` | `toggle` | abre/cierra el menú de Bluetooth |

  ```bash
  quickshell ipc -p .../shell.qml call -- network toggle
  quickshell ipc -p .../shell.qml call -- bluetooth toggle
  ```
- Estado y datos
  - Sin `pragma Singleton` salvo los dos backends; sin JSON en `~/.config/oozeshell` ni caché en `~/.cache` propios del módulo.
  - `NetworkBackend` lanza `Process` con `nmcli -t` (`device`, `radio WIFI`, lista `IN-USE,SSID,SIGNAL,SECURITY`, `connection show`); `connectTo(ssid,password)` / `disconnectWifi()` / `forget(ssid)` / `setWifi(on)` (`NetworkBackend.qml:262-310`).
  - `menuWatch`/`panelWatch` en `NetworkBackend` (`watching`) y `panelWatch` en `BluetoothBackend` activan el sondeo solo mientras hay UI visible.
- Dependencias
  - `Services/Network/NetworkBackend.qml` importa `Services/Lang` (etiquetas traducidas); el menú usa `Theme` (`COMMON`, tamaños) y `NetworkBackend`.
  - `Services/Bluetooth/BluetoothBackend.qml` importa `Quickshell.Bluetooth` + `Services/Lang`; requiere BlueZ + DBus, si no hay adaptador `available` es `false`.
- Notas
  - El `toggle` de IPC no enciende/apaga la radio, solo abre el menú; el on/off de Wi-Fi/Bluetooth se hace dentro del menú.
  - `NetworkMenu` guarda `expandedSsid`/`pw` solo en memoria y los limpia en `onConnectSucceeded`.
