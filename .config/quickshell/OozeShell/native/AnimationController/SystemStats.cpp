#include "SystemStats.h"

#include <QDir>
#include <QFile>
#include <QStandardPaths>
#include <QtGlobal>

namespace {

// Lee un archivo pequeño de /proc o /sys entero. QFile sobre /proc devuelve
// size() == 0, por eso readAll() y no confiar en el tamaño.
QByteArray slurp(const QString &path) {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) return {};
    return f.readAll();
}

qreal clamp01(qreal v) { return qBound<qreal>(0.0, v, 1.0); }

} // namespace

SystemStats::SystemStats(QObject *parent) : ActiveSource(parent) {
    m_timer.setTimerType(Qt::CoarseTimer);   // no hace falta precisión de ms
    m_timer.setInterval(m_intervalMs);
    connect(&m_timer, &QTimer::timeout, this, &SystemStats::tick);
}

QString SystemStats::gpuName() const {
    switch (m_gpuMode) {
    case GpuAmdSysfs:   return QStringLiteral("amdgpu");
    case GpuNvidiaSmi:  return QStringLiteral("nvidia");
    default:            return QString();
    }
}

void SystemStats::setIntervalMs(int ms) {
    ms = qBound(250, ms, 10000);
    if (ms == m_intervalMs) return;
    m_intervalMs = ms;
    m_timer.setInterval(ms);
    emit intervalChanged();
}

void SystemStats::setHistorySize(int n) {
    n = qBound(2, n, 240);
    if (n == m_historySize) return;
    m_historySize = n;
    for (QVariantList *h : {&m_cpuHist, &m_ramHist, &m_gpuHist})
        while (h->size() > n) h->removeFirst();
    emit historySizeChanged();
}

void SystemStats::onStart() {
    if (!m_gpuDetected) detectGpu();
    // Primera muestra ya (el CPU necesita dos lecturas; la segunda llega en 1 tick)
    m_haveCpuPrev = false;
    tick();
    m_timer.start();
}

void SystemStats::onStop() {
    m_timer.stop();
    if (m_nvidiaProc) {                      // nada de procesos colgando
        m_nvidiaProc->disconnect(this);
        m_nvidiaProc->kill();
        m_nvidiaProc->deleteLater();
        m_nvidiaProc = nullptr;
    }
    // Soltar la memoria de los historiales (QVariantList no encoge solo)
    m_cpuHist = QVariantList();
    m_ramHist = QVariantList();
    m_gpuHist = QVariantList();
    m_cpu = m_ram = m_gpu = 0;
    m_haveCpuPrev = false;
}

void SystemStats::tick() {
    readCpu();
    readRam();
    readGpu();
    push(m_cpuHist, m_cpu);
    push(m_ramHist, m_ram);
    if (gpuAvailable()) push(m_gpuHist, m_gpu);
    emit updated();
}

void SystemStats::push(QVariantList &hist, qreal v) {
    hist.append(v);
    while (hist.size() > m_historySize) hist.removeFirst();
}

void SystemStats::readCpu() {
    // "cpu  user nice system idle iowait irq softirq steal ..."
    const QByteArray data = slurp(QStringLiteral("/proc/stat"));
    const int eol = data.indexOf('\n');
    if (eol <= 0) return;
    const QList<QByteArray> p = data.left(eol).simplified().split(' ');
    if (p.size() < 8 || p.first() != "cpu") return;

    qulonglong total = 0;
    for (int i = 1; i < p.size(); ++i) total += p.at(i).toULongLong();
    const qulonglong idle = p.at(4).toULongLong() + p.at(5).toULongLong();   // idle + iowait

    if (m_haveCpuPrev && total > m_prevTotal) {
        const qreal dTotal = qreal(total - m_prevTotal);
        const qreal dIdle  = qreal(idle >= m_prevIdle ? idle - m_prevIdle : 0);
        m_cpu = clamp01(1.0 - dIdle / dTotal);
    }
    m_prevTotal = total;
    m_prevIdle = idle;
    m_haveCpuPrev = true;
}

void SystemStats::readRam() {
    const QByteArray data = slurp(QStringLiteral("/proc/meminfo"));
    qint64 total = 0, avail = 0;
    int found = 0;
    for (const QByteArray &line : data.split('\n')) {
        if (line.startsWith("MemTotal:"))          { total = line.simplified().split(' ').value(1).toLongLong(); ++found; }
        else if (line.startsWith("MemAvailable:")) { avail = line.simplified().split(' ').value(1).toLongLong(); ++found; }
        if (found == 2) break;
    }
    if (total <= 0) return;
    m_ramTotalKb = total;
    m_ramUsedKb = qMax<qint64>(0, total - avail);
    m_ram = clamp01(qreal(m_ramUsedKb) / qreal(total));
}

void SystemStats::detectGpu() {
    m_gpuDetected = true;
    m_gpuMode = GpuNone;

    // AMD: el kernel publica el % de uso en sysfs, sin permisos especiales
    const QDir drm(QStringLiteral("/sys/class/drm"));
    const QStringList cards = drm.entryList({QStringLiteral("card?")}, QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    for (const QString &c : cards) {
        const QString p = drm.filePath(c) + QStringLiteral("/device/gpu_busy_percent");
        if (QFile::exists(p)) {
            m_amdBusyPath = p;
            m_gpuMode = GpuAmdSysfs;
            return;
        }
    }

    // NVIDIA: nvidia-smi (si está). Se consulta de forma asíncrona.
    m_nvidiaSmiPath = QStandardPaths::findExecutable(QStringLiteral("nvidia-smi"));
    if (!m_nvidiaSmiPath.isEmpty()) m_gpuMode = GpuNvidiaSmi;
}

void SystemStats::readGpu() {
    switch (m_gpuMode) {
    case GpuAmdSysfs: {
        bool ok = false;
        const int pct = slurp(m_amdBusyPath).trimmed().toInt(&ok);
        if (ok) m_gpu = clamp01(pct / 100.0);
        break;
    }
    case GpuNvidiaSmi:
        pollNvidia();               // el resultado llega después; aquí se queda el último
        break;
    default:
        break;
    }
}

void SystemStats::pollNvidia() {
    if (m_nvidiaProc) return;       // la consulta anterior aún no termina: no apilar
    m_nvidiaProc = new QProcess(this);
    connect(m_nvidiaProc, &QProcess::finished, this, [this](int code, QProcess::ExitStatus) {
        QProcess *p = m_nvidiaProc;
        m_nvidiaProc = nullptr;
        if (p) {
            if (code == 0) {
                bool ok = false;
                const int pct = QString::fromUtf8(p->readAllStandardOutput()).trimmed().toInt(&ok);
                if (ok) m_gpu = clamp01(pct / 100.0);
            }
            p->deleteLater();
        }
    });
    // Si nvidia-smi no arranca (driver caído), se descarta sin ruido
    connect(m_nvidiaProc, &QProcess::errorOccurred, this, [this](QProcess::ProcessError e) {
        if (e == QProcess::FailedToStart && m_nvidiaProc) {
            m_nvidiaProc->deleteLater();
            m_nvidiaProc = nullptr;
            m_gpuMode = GpuNone;
        }
    });
    m_nvidiaProc->start(m_nvidiaSmiPath,
        {QStringLiteral("--query-gpu=utilization.gpu"), QStringLiteral("--format=csv,noheader,nounits")});
}
