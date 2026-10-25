#include "AnimationController.h"

#include <QtGlobal>

AnimationController::AnimationController(QObject *parent) : QObject(parent) {}

qreal AnimationController::scale() const {
    if (m_performance || m_mode == QLatin1String("off")) return 0.0;
    if (m_mode == QLatin1String("minimal")) return 0.4;
    return 1.0;
}

int AnimationController::duration(int milliseconds) const {
    return qRound(qMax(0, milliseconds) * scale());
}

void AnimationController::setMode(const QString &mode) {
    const QString next = (mode == QLatin1String("minimal") || mode == QLatin1String("off"))
        ? mode : QStringLiteral("normal");
    if (m_mode == next) return;
    const qreal before = scale();
    m_mode = next;
    emit modeChanged();
    if (!qFuzzyCompare(before + 1.0, scale() + 1.0)) emit scaleChanged();
}

void AnimationController::setPerformance(bool on) {
    if (m_performance == on) return;
    const qreal before = scale();
    m_performance = on;
    emit performanceChanged();
    if (!qFuzzyCompare(before + 1.0, scale() + 1.0)) emit scaleChanged();
}
