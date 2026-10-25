#pragma once

#include <QHash>
#include <QString>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>
#include <QtQml/qqmlregistration.h>

#include "ActiveSource.h"

// MODULE — ProcessList: procesos en vivo (PID, usuario, CPU%, RAM) desde /proc.
// Cuesta CERO mientras nadie lo pida (ver ActiveSource).
class ProcessList : public ActiveSource {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QVariantList rows READ rows NOTIFY updated)
    Q_PROPERTY(int total READ total NOTIFY updated)
    Q_PROPERTY(int numCores READ numCores CONSTANT)
    Q_PROPERTY(qreal cpuTotal READ cpuTotal NOTIFY updated)
    Q_PROPERTY(qint64 memTotalMb READ memTotalMb NOTIFY updated)
    Q_PROPERTY(QString sortBy READ sortBy WRITE setSortBy NOTIFY sortByChanged)
    Q_PROPERTY(int limit READ limit WRITE setLimit NOTIFY limitChanged)
    Q_PROPERTY(int intervalMs READ intervalMs WRITE setIntervalMs NOTIFY intervalChanged)

public:
    explicit ProcessList(QObject *parent = nullptr);

    QVariantList rows() const { return m_rows; }
    int total() const { return m_total; }
    int numCores() const { return m_numCores; }
    qreal cpuTotal() const { return m_cpuTotal; }
    qint64 memTotalMb() const { return m_memTotalMb; }
    QString sortBy() const { return m_sortBy; }
    int limit() const { return m_limit; }
    int intervalMs() const { return m_intervalMs; }

    void setSortBy(const QString &key);
    void setLimit(int n);
    void setIntervalMs(int ms);

    Q_INVOKABLE bool kill(int pid, int sig = 15);

signals:
    void updated();
    void sortByChanged();
    void limitChanged();
    void intervalChanged();

protected:
    void onStart() override;
    void onStop() override;

private:
    void tick();
    void rebuild();
    void loadUsers();
    QString userName(unsigned uid);
    void sortRows(QVector<QVariantMap> &rows) const;

    QTimer m_timer;
    int m_intervalMs = 1500;
    int m_limit = 200;
    QString m_sortBy = QStringLiteral("cpu");

    QVariantList m_rows;
    QVector<QVariantMap> m_all;
    int m_total = 0;
    qreal m_cpuTotal = 0;
    qint64 m_memTotalMb = 0;

    qulonglong m_prevTotal = 0;
    bool m_havePrev = false;
    QHash<int, qulonglong> m_prevTicks;

    QHash<unsigned, QString> m_users;
    bool m_usersLoaded = false;
    int m_numCores = 1;
    qint64 m_pageKb = 4;
};
