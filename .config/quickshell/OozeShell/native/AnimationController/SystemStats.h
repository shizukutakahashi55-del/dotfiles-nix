#pragma once

#include <QProcess>
#include <QString>
#include <QTimer>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

#include "ActiveSource.h"

// SystemStats — CPU, RAM y GPU para el widget SystemInfo (y lo que venga).
//
//   cpu / ram / gpu           0..1
//   ramUsedKb / ramTotalKb    kB
//   gpuAvailable              false si no se encontró ninguna GPU legible
//   gpuName                   "amdgpu" | "nvidia" | ""
//   cpuHistory / ramHistory / gpuHistory   últimas `historySize` muestras (0..1)
//
// Fuentes (sin dependencias extra):
//   CPU  /proc/stat          RAM  /proc/meminfo
//   GPU  AMD:    /sys/class/drm/card*/device/gpu_busy_percent
//        NVIDIA: `nvidia-smi` (solo si existe y no hay sysfs AMD)
//        Intel:  no hay "uso %" sin privilegios -> gpuAvailable = false
//
// Cuesta CERO mientras nadie la pida (ver ActiveSource): sin timer, sin
// procesos, historiales vacíos.
class SystemStats final : public ActiveSource {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(qreal cpu READ cpu NOTIFY updated)
    Q_PROPERTY(qreal ram READ ram NOTIFY updated)
    Q_PROPERTY(qreal gpu READ gpu NOTIFY updated)
    Q_PROPERTY(qint64 ramUsedKb READ ramUsedKb NOTIFY updated)
    Q_PROPERTY(qint64 ramTotalKb READ ramTotalKb NOTIFY updated)
    Q_PROPERTY(bool gpuAvailable READ gpuAvailable NOTIFY updated)
    Q_PROPERTY(QString gpuName READ gpuName NOTIFY updated)
    Q_PROPERTY(QVariantList cpuHistory READ cpuHistory NOTIFY updated)
    Q_PROPERTY(QVariantList ramHistory READ ramHistory NOTIFY updated)
    Q_PROPERTY(QVariantList gpuHistory READ gpuHistory NOTIFY updated)
    Q_PROPERTY(int intervalMs READ intervalMs WRITE setIntervalMs NOTIFY intervalChanged)
    Q_PROPERTY(int historySize READ historySize WRITE setHistorySize NOTIFY historySizeChanged)

public:
    explicit SystemStats(QObject *parent = nullptr);

    qreal cpu() const { return m_cpu; }
    qreal ram() const { return m_ram; }
    qreal gpu() const { return m_gpu; }
    qint64 ramUsedKb() const { return m_ramUsedKb; }
    qint64 ramTotalKb() const { return m_ramTotalKb; }
    bool gpuAvailable() const { return m_gpuMode != GpuNone; }
    QString gpuName() const;
    QVariantList cpuHistory() const { return m_cpuHist; }
    QVariantList ramHistory() const { return m_ramHist; }
    QVariantList gpuHistory() const { return m_gpuHist; }
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
    void readRam();
    void readGpu();
    void detectGpu();
    void pollNvidia();
    void push(QVariantList &hist, qreal v);

    QTimer m_timer;
    int m_intervalMs = 1000;
    int m_historySize = 40;

    // CPU: se calcula con la diferencia entre dos lecturas de /proc/stat
    qulonglong m_prevIdle = 0;
    qulonglong m_prevTotal = 0;
    bool m_haveCpuPrev = false;

    qreal m_cpu = 0, m_ram = 0, m_gpu = 0;
    qint64 m_ramUsedKb = 0, m_ramTotalKb = 0;
    QVariantList m_cpuHist, m_ramHist, m_gpuHist;

    GpuMode m_gpuMode = GpuNone;
    bool m_gpuDetected = false;
    QString m_amdBusyPath;
    QString m_nvidiaSmiPath;
    QProcess *m_nvidiaProc = nullptr;
};
