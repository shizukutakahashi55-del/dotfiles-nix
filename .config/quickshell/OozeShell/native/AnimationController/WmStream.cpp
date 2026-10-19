#include "WmStream.h"

#include <QJsonDocument>
#include <QJsonObject>

WmStream::WmStream(QObject *parent) : QObject(parent) {
    m_restart.setSingleShot(true);
    m_restart.setInterval(1500);
    connect(&m_proc, &QProcess::readyReadStandardOutput, this, &WmStream::onReadyRead);
    connect(&m_proc, &QProcess::finished, this, &WmStream::onFinished);
    connect(&m_restart, &QTimer::timeout, this, &WmStream::onRestartTimeout);
}

WmStream::~WmStream() {
    m_active = false;
    m_restart.stop();
    disconnect(&m_proc, nullptr, this, nullptr);
    if (m_proc.state() != QProcess::NotRunning) {
        m_proc.terminate();
        if (!m_proc.waitForFinished(500)) m_proc.kill();
    }
}

void WmStream::setCommand(const QStringList &cmd) {
    if (m_command == cmd) return;
    m_command = cmd;
    if (m_active) { stop(); start(); }
    emit commandChanged();
}

void WmStream::setActive(bool on) {
    if (m_active == on) return;
    m_active = on;
    if (on) { m_restarts = 0; emit restartsChanged(); start(); }
    else { m_restart.stop(); stop(); }
    emit activeChanged();
}

void WmStream::start() {
    if (m_command.isEmpty() || running()) return;
    m_buf.clear();
    m_proc.start(m_command.constFirst(), m_command.mid(1));
    emit runningChanged();
}

void WmStream::stop() {
    m_restart.stop();
    if (running()) {
        m_proc.kill();
        m_proc.waitForFinished(500);
        emit runningChanged();
    }
    m_buf.clear();
}

void WmStream::scheduleRestart() {
    if (!m_active || m_restarts >= kMaxRestarts) return;
    m_restarts++;
    emit restartsChanged();
    m_restart.start();
}

void WmStream::onReadyRead() {
    m_buf += m_proc.readAllStandardOutput();
    if (m_buf.size() > kMaxBuf) {
        const int cut = m_buf.indexOf('\n');
        m_buf = (cut >= 0) ? m_buf.mid(cut + 1) : m_buf.right(kMaxBuf / 2);
    }
    int nl = -1;
    while ((nl = m_buf.indexOf('\n')) >= 0) {
        const QByteArray line = m_buf.left(nl).trimmed();
        m_buf = m_buf.mid(nl + 1);
        if (line.isEmpty()) continue;
        QJsonParseError err;
        const QJsonDocument doc = QJsonDocument::fromJson(line, &err);
        if (err.error != QJsonParseError::NoError || !doc.isObject()) {
            m_dropped++;
            emit droppedLinesChanged();
            continue;
        }
        emit parsed(doc.object().toVariantMap());
    }
}

void WmStream::onFinished(int, QProcess::ExitStatus) {
    emit runningChanged();
    if (m_active) scheduleRestart();
}

void WmStream::onRestartTimeout() {
    if (m_active && !running()) start();
}
