#pragma once

#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>

class AnimationController final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("AnimationController is provided as a singleton by the module")
    Q_PROPERTY(QString mode READ mode WRITE setMode NOTIFY modeChanged)
    Q_PROPERTY(bool enabled READ enabled NOTIFY modeChanged)

public:
    explicit AnimationController(QObject *parent = nullptr) : QObject(parent) {}

    QString mode() const { return m_mode; }
    bool enabled() const { return m_mode != QStringLiteral("off"); }

    Q_INVOKABLE int duration(int milliseconds) const {
        const int base = qMax(0, milliseconds);
        if (m_mode == QStringLiteral("off")) return 0;
        if (m_mode == QStringLiteral("minimal")) return qRound(base * 0.4);
        return base;
    }

public slots:
    void setMode(const QString &mode) {
        const QString next = (mode == "minimal" || mode == "off") ? mode : QStringLiteral("normal");
        if (m_mode == next) return;
        m_mode = next;
        emit modeChanged();
    }

signals:
    void modeChanged();

private:
    QString m_mode = QStringLiteral("normal");
};
