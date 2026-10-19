#pragma once

#include <QByteArray>
#include <QObject>
#include <QProcess>
#include <QStringList>
#include <QTimer>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

// WmStream — transporte de event-streams del compositor (niri event-stream,
// mmsg watch) con parseo JSON en C++.
//
// QML conserva TODA la lógica de estado (NiriState.applyEvent, MangoIpc.*):
// esto solo encuadra líneas y las entrega ya parseadas. Sin JS por línea,
// sin SplitParser, sin try/catch de JSON en caliente.
//
//   WmStream {
//     command: ["niri", "msg", "--json", "event-stream"]
//     active: WM.wm === "niri"      // arranca/para el proceso
//   }
//   onParsed: (obj) => root.applyEvent(obj)
//
// Reinicio con backoff (máx. 5 seguidos, como NiriState): parar con
// active=false es limpio y resetea el contador. Líneas no-JSON se
// descartan en silencio (droppedLines).
class WmStream : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QStringList command READ command WRITE setCommand NOTIFY commandChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(int restarts READ restarts NOTIFY restartsChanged)
    Q_PROPERTY(int droppedLines READ droppedLines NOTIFY droppedLinesChanged)

public:
    explicit WmStream(QObject *parent = nullptr);
    ~WmStream() override;

    QStringList command() const { return m_command; }
    bool active() const { return m_active; }
    bool running() const { return m_proc.state() != QProcess::NotRunning; }
    int restarts() const { return m_restarts; }
    int droppedLines() const { return m_dropped; }

    void setCommand(const QStringList &cmd);
    void setActive(bool on);

signals:
    void parsed(const QVariantMap &obj);
    void commandChanged();
    void activeChanged();
    void runningChanged();
    void restartsChanged();
    void droppedLinesChanged();

private slots:
    void onReadyRead();
    void onFinished(int code, QProcess::ExitStatus status);
    void onRestartTimeout();

private:
    void start();
    void stop();
    void scheduleRestart();

    QProcess m_proc;
    QTimer m_restart;
    QByteArray m_buf;
    QStringList m_command;
    bool m_active = false;
    int m_restarts = 0;
    int m_dropped = 0;
    static const int kMaxRestarts = 5;
    static const int kMaxBuf = 1 << 20;
};
