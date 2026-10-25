#pragma once

#include <QObject>
#include <QtQml/qqmlregistration.h>

class MemoryTrim final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit MemoryTrim(QObject *parent = nullptr) : QObject(parent) {}
    Q_INVOKABLE bool trim() const;
};
