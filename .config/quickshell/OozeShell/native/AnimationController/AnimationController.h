#pragma once

#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>

// Escala de animaciones de OozeShell: UNA fuente de verdad, también para items C++.
//
//   mode        "normal" | "minimal" | "off"   (espejo de Theme.uiAnimationMode)
//   performance true = modo Performance        (espejo de Theme.performanceMode)
//   scale       multiplicador efectivo: 1.0 normal · 0.4 minimal · 0 off/performance
//
// `scale` tiene su propia señal y SOLO se emite cuando el valor cambia: así los
// ~465 bindings `Theme.animDuration(...)` no se reevalúan por cambios que no
// les afectan (p. ej. activar Performance estando ya en "off").
class AnimationController final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QString mode READ mode WRITE setMode NOTIFY modeChanged)
    Q_PROPERTY(bool performance READ performance WRITE setPerformance NOTIFY performanceChanged)
    Q_PROPERTY(bool enabled READ enabled NOTIFY scaleChanged)
    Q_PROPERTY(qreal scale READ scale NOTIFY scaleChanged)

public:
    explicit AnimationController(QObject *parent = nullptr);

    QString mode() const { return m_mode; }
    bool performance() const { return m_performance; }
    bool enabled() const { return scale() > 0.0; }
    qreal scale() const;

    // Para usar desde C++ (items, nodos) sin pasar por QML.
    Q_INVOKABLE int duration(int milliseconds) const;

public slots:
    void setMode(const QString &mode);
    void setPerformance(bool on);

signals:
    void modeChanged();
    void performanceChanged();
    void scaleChanged();

private:
    QString m_mode = QStringLiteral("normal");
    bool m_performance = false;
};
