import "../TASKBAR"

// PillTaskbar — el taskbar existente (TASKBAR/Taskbar.qml), tal cual,
// forzado a "un solo ícono" (compact) para la Pill. Cero lógica propia:
// esto es solo una especialización con un valor fijo. El drop con la
// lista de ventanas sigue siendo TASKBAR/TaskbarMenu.qml — lo instancia
// Pill.qml (necesita mapear coordenadas de SU propia ventana).
Taskbar {
    compact: true
    // En la Pill no hay plegar/desplegar: siempre es un solo ícono, sin flechita
    showToggle: false
    maxItems: 8
}
