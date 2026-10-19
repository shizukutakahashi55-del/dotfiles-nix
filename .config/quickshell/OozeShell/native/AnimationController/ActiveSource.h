#pragma once

#include <QObject>
#include <QSet>
#include <QString>

// ActiveSource — base de toda fuente de datos de widgets.
//
// Regla de oro: una fuente NO consume nada mientras nadie la pida.
//   setWanted("clock-1", true)   // un cliente la necesita  -> start()
//   setWanted("clock-1", false)  // ya no                    -> si era el último, stop()
//
// Misma idea que AudioLevels.setWanted() de QML, pero en C++. Las clases
// derivadas solo implementan onStart()/onStop(): abrir/cerrar timers, procesos,
// sockets, peticiones de red y liberar cachés. El registro de clientes y la
// idempotencia ya están resueltos aquí.
class ActiveSource : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool wanted READ wanted NOTIFY wantedChanged)

public:
    explicit ActiveSource(QObject *parent = nullptr) : QObject(parent) {}

    bool wanted() const { return !m_clients.isEmpty(); }

    // Idempotente: pedir dos veces lo mismo (o soltar algo no pedido) no hace nada.
    Q_INVOKABLE void setWanted(const QString &who, bool on) {
        const bool before = wanted();
        if (on) m_clients.insert(who);
        else    m_clients.remove(who);
        const bool after = wanted();
        if (before == after) return;
        if (after) onStart(); else onStop();
        emit wantedChanged();
    }

signals:
    void wantedChanged();

protected:
    virtual void onStart() = 0;   // primer cliente: arrancar
    virtual void onStop() = 0;    // último cliente se fue: parar y liberar TODO

private:
    QSet<QString> m_clients;
};
