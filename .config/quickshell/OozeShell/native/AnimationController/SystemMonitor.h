#pragma once

#include <QProcess>
#include <QString>
#include <QTimer>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

#include "ActiveSource.h"

// MODULE — SystemMonitor: CPU/RAM/swap/GPU/temps/red/discos en vivo.
// Fuentes: /proc/stat, /proc/meminfo, /proc/loadavg, /proc/net/dev,
//          /sys/class/hwmon, /sys/class/drm, nvidia-smi (si existe), QStorageInfo.
// Cuesta CERO mientras nadie lo pida (ver ActiveSource).
class SystemMonitor final : public ActiveSource {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(qreal cpu READ cpu NOTIFY updated)
    Q_PROPERTY(QVariantList perCore READ perCore NOTIFY updated)
    Q_PROPERTY(qreal ram READ ram NOTIFY updated)
    Q_PROPERTY(qreal swap READ swap NOTIFY updated)
    Q_PROPERTY(qint64 ramUsedMb READ ramUsedMb NOTIFY updated)
    Q_PROPERTY(qint64 ramTotalMb READ ramTotalMb NOTIFY updated)
    Q_PROPERTY(qint64 swapUsedMb READ swapUsedMb NOTIFY updated)
    Q_PROPERTY(qint64 swapTotalMb READ swapTotalMb NOTIFY updated)
    Q_PROPERTY(qreal load1 READ load1 NOTIFY updated)
    Q_PROPERTY(qreal load5 READ load5 NOTIFY updated)
    Q_PROPERTY(qreal load15 READ load15 NOTIFY updated)
    Q_PROPERTY(qreal cpuTemp READ cpuTemp NOTIFY updated)
    Q_PROPERTY(qreal cpuFreqMhz READ cpuFreqMhz NOTIFY updated)
    Q_PROPERTY(qreal gpu READ gpu NOTIFY updated)
    Q_PROPERTY(bool gpuAvailable READ gpuAvailable NOTIFY updated)
    Q_PROPERTY(QString gpuName READ gpuName NOTIFY updated)
    Q_PROPERTY(qreal gpuTemp READ gpuTemp NOTIFY updated)
    Q_PROPERTY(qint64 gpuVramUsedMb READ gpuVramUsedMb NOTIFY updated)
    Q_PROPERTY(qint64 gpuVramTotalMb READ gpuVramTotalMb NOTIFY updated)
    Q_PROPERTY(qreal netRx READ netRx NOTIFY updated)
    Q_PROPERTY(qreal netTx READ netTx NOTIFY updated)
    Q_PROPERTY(QString netIface READ netIface NOTIFY updated)
    Q_PROPERTY(QVariantList disks READ disks NOTIFY updated)
    Q_PROPERTY(QVariantMap diskRates READ diskRates NOTIFY updated)
    Q_PROPERTY(QVariantList cpuHistory READ cpuHistory NOTIFY updated)
    Q_PROPERTY(QVariantList ramHistory READ ramHistory NOTIFY updated)
    Q_PROPERTY(QVariantList gpuHistory READ gpuHistory NOTIFY updated)
    Q_PROPERTY(QVariantList netRxHistory READ netRxHistory NOTIFY updated)
    Q_PROPERTY(QVariantList netTxHistory READ netTxHistory NOTIFY updated)
    Q_PROPERTY(QString hostname READ hostname CONSTANT)
    Q_PROPERTY(QString kernel READ kernel CONSTANT)
    Q_PROPERTY(QString osName READ osName CONSTANT)
    Q_PROPERTY(int intervalMs READ intervalMs WRITE setIntervalMs NOTIFY intervalChanged)
    Q_PROPERTY(int historySize READ historySize WRITE setHistorySize NOTIFY historySizeChanged)

public:
    explicit SystemMonitor(QObject *parent = nullptr);

    qreal cpu() const { return m_cpu; }
    QVariantList perCore() const { return m_perCore; }
    qreal ram() const { return m_ram; }
    qreal swap() const { return m_swap; }
    qint64 ramUsedMb() const { return m_ramUsedMb; }
    qint64 ramTotalMb() const { return m_ramTotalMb; }
    qint64 swapUsedMb() const { return m_swapUsedMb; }
    qint64 swapTotalMb() const { return m_swapTotalMb; }
    qreal load1() const { return m_load1; }
    qreal load5() const { return m_load5; }
    qreal load15() const { return m_load15; }
    qreal cpuTemp() const { return m_cpuTemp; }
    qreal cpuFreqMhz() const { return m_cpuFreqMhz; }
    qreal gpu() const { return m_gpu; }
    bool gpuAvailable() const { return m_gpuMode != GpuNone; }
    QString gpuName() const;
    qreal gpuTemp() const { return m_gpuTemp; }
    qint64 gpuVramUsedMb() const { return m_gpuVramUsedMb; }
    qint64 gpuVramTotalMb() const { return m_gpuVramTotalMb; }
    qreal netRx() const { return m_netRx; }
    qreal netTx() const { return m_netTx; }
    QString netIface() const { return m_netIface; }
    QVariantList disks() const { return m_disks; }
    QVariantMap diskRates() const { return m_diskRates; }
    QVariantList cpuHistory() const { return m_cpuHist; }
    QVariantList ramHistory() const { return m_ramHist; }
    QVariantList gpuHistory() const { return m_gpuHist; }
    QVariantList netRxHistory() const { return m_netRxHist; }
    QVariantList netTxHistory() const { return m_netTxHist; }
    QString hostname() const { return m_hostname; }
    QString kernel() const { return m_kernel; }
    QString osName() const { return m_osName; }
    int intervalMs() const { return m_intervalMs; }
    int historySize() const { return m_historySize; }

    void setIntervalMs(int ms);
    void setHistorySize(int n);

signals:
    void updated();
    void intervalChanged();
    void historySizeChanged();

protected:
    void onStart() override;
    void onStop() override;

private:
    enum GpuMode { GpuNone, GpuAmdSysfs, GpuNvidiaSmi };

    void tick();
    void readCpu();
    void readMem();
    void readLoad();
    void readCpuTemp();
    void readGpu();
    void detectGpu();
    void detectTemps();
    void pollNvidia();
    void readNet();
    void readDisks();
    void readDiskRates();
    void push(QVariantList &hist, qreal v);
    void pushNet(QVariantList &hist, qreal v);

    QTimer m_timer;
    int m_intervalMs = 1000;
    int m_historySize = 60;

    QVector<QPair<qulonglong, qulonglong>> m_prevCore;
    qulonglong m_prevIdle = 0;
    qulonglong m_prevTotal = 0;
    bool m_haveCpuPrev = false;

    qreal m_cpu = 0, m_ram = 0, m_swap = 0;
    QVariantList m_perCore;
    qint64 m_ramUsedMb = 0, m_ramTotalMb = 0, m_swapUsedMb = 0, m_swapTotalMb = 0;

    qreal m_load1 = 0, m_load5 = 0, m_load15 = 0;
    qreal m_cpuTemp = -1, m_cpuFreqMhz = 0;
    QString m_cpuTempPath, m_gpuTempPath;

    qreal m_gpu = -1;
    GpuMode m_gpuMode = GpuNone;
    bool m_gpuDetected = false;
    QString m_amdBusyPath, m_amdVramUsedPath, m_amdVramTotalPath, m_nvidiaSmiPath;
    qreal m_gpuTemp = -1;
    qint64 m_gpuVramUsedMb = -1, m_gpuVramTotalMb = -1;
    QProcess *m_nvidiaProc = nullptr;

    QHash<QString, QPair<qulonglong, qulonglong>> m_prevNet;
    QString m_netIface;
    qreal m_netRx = 0, m_netTx = 0;
    qint64 m_prevNetMs = 0;

    QString m_hostname, m_kernel, m_osName;

    QVariantList m_disks;
    QVariantMap m_diskRates;
    QHash<QString, QPair<qulonglong, qulonglong>> m_prevDisk;
    qint64 m_prevDiskMs = 0;
    QVariantList m_cpuHist, m_ramHist, m_gpuHist, m_netRxHist, m_netTxHist;
};
