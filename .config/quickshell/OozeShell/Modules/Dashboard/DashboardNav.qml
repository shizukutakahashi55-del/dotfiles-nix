// DashboardNav — movimiento por cuadrícula con el teclado, compartido por las secciones del dashboard

import QtQuick

QtObject {
    function isDir(key) {
        return key === Qt.Key_Left || key === Qt.Key_Right || key === Qt.Key_Up || key === Qt.Key_Down
            || key === Qt.Key_H || key === Qt.Key_L || key === Qt.Key_K || key === Qt.Key_J
    }

    function isAccept(key) {
        return key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Space
    }

    function move(sel, count, cols, key) {
        if (count <= 0) return -1
        const row = Math.floor(sel / cols)
        const col = sel % cols
        const last = Math.floor((count - 1) / cols)
        if (key === Qt.Key_Left || key === Qt.Key_H)
            return col > 0 ? sel - 1 : -1
        if (key === Qt.Key_Right || key === Qt.Key_L)
            return (col < cols - 1 && sel + 1 < count) ? sel + 1 : -1
        if (key === Qt.Key_Up || key === Qt.Key_K)
            return row > 0 ? sel - cols : -1
        if (key === Qt.Key_Down || key === Qt.Key_J) {
            if (row >= last) return -1
            return Math.min(count - 1, sel + cols)
        }
        return -1
    }
}
