# AGENTS — globo de IA

- Qué es
  - Globo flotante abajo a la derecha que responde preguntas con el agente elegido en Ajustes avanzados → Agentes de IA. No usa la barra de búsqueda: se abre solo por IPC.
  - La categoría de ajustes está oculta (`hidden: true` en `SettingsRegistry`) hasta desbloquearla: 7 pulsaciones sobre «OozeShell» en Acerca de, o `qs ipc call agent unlock`. `lock` la vuelve a ocultar. Ocultar es solo visual: el IPC y el globo siguen funcionando.
- Archivos
  - `Services/Agents/AgentsService.qml` → singleton: configuración, estado de claves/CLIs, conversación, `ask`, copia y apertura del globo.
  - `Services/Agents/AgentBubble.qml` → ventana overlay a pantalla completa transparente: clic fuera o Esc cierran; el globo tiene ✕, nuevo chat, copiar por respuesta y campo de mensaje.
  - `Core/Ipc/AgentIpc.qml` → target `agent`.
  - `Settings/pages/AgentsPage.qml` → agente activo, cuentas con API key, CLI/locales, ayuda de IPC y botón Ocultar.
  - `Tools/agent-secrets.sh` → almacén de claves. `Tools/agent-ask.sh` → consulta a cada proveedor y detección de CLIs.
- IPC (`qs ipc call agent …`)
  | función | efecto |
  |---|---|
  | `toggle` / `open` / `close` | abre o cierra el globo en el monitor enfocado |
  | `ask "texto"` | abre el globo y envía la pregunta |
  | `copy` | copia la última respuesta con `wl-copy` |
  | `newchat` | borra la conversación |
  | `unlock` / `lock` | muestra u oculta la categoría de ajustes |
- Agentes
  - API key: `anthropic`, `openai`, `gemini`, `openrouter`, `groq`. Sin facturación: `gemini` (AI Studio), `openrouter` con modelos `:free` o `openrouter/free`, y `groq` tienen nivel gratuito sin tarjeta.
  - CLI con su propio login: `claude-cli` (`claude -p`), `gemini-cli` (`gemini -p`), `codex-cli` (`codex exec`). El botón «Iniciar sesión» abre la terminal con el login del CLI; OozeShell no guarda ningún token de ellos.
  - Local: `ollama` en `127.0.0.1:11434`, sin cuenta.
- Claves y cifrado
  - Nunca van en `ui.toml`, `agents.toml` ni dentro de la carpeta del shell (que suele estar en un repo de dotfiles).
  - Con llavero del sistema activo (`secret-tool` + `org.freedesktop.secrets`) se guardan ahí. Si no, en `~/.local/share/oozeshell/agents/<proveedor>.enc`, cifradas con AES-256-CBC (PBKDF2, 300000 iteraciones) con una frase derivada de `/etc/machine-id` y el uid; carpeta 700 y archivo 600. Copiar el archivo a otro equipo no permite descifrarlo.
  - Limitación: cualquier proceso que corra como tu mismo usuario en este equipo puede pedirle la clave al script. La protección es contra copias de archivos, respaldos y repos, no contra malware local.
  - La clave viaja al script por variable de entorno y a `curl` por un descriptor interno (`--config`), nunca como argumento visible en `ps`.
- Apariencia
  - Ajustes avanzados → Agentes de IA → «Tamaño de la ventana» y «Tamaño de letra» (Mínimo, Compacto, Pequeño, Normal, Grande). Mínimo (valor por defecto) es una cápsula discreta con el título fijo «Chat» (no muestra el nombre del agente ni el modelo); Compacto es similar y algo más estrecha; Pequeño es el tamaño intermedio; Normal reproduce el globo original. Cada nivel de tamaño escala también el campo de mensaje.
- Estado
  - `~/.config/oozeshell/agents.toml` guarda solo datos no secretos: desbloqueo, agente, modelos, instrucción del sistema y niveles de tamaño y letra.
