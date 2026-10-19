#include "SystemMonitor.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QHash>
#include <QRegularExpression>
#include <QSet>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QSysInfo>
#include <QVariantMap>
#include <QtGlobal>

namespace {

QByteArray slurp(const QString &path) {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) return {};
    return f.readAll();
}

qreal clampPct(qreal v) { return qBound<qreal>(0.0, v, 100.0); }

bool cpuHwmon(const QString &name) {
    return name.contains("k10temp") || name.contains("coretemp") || name.contains("zenpower")
        || name.contains("cpu") || name == "acpitz";
}

bool gpuHwmon(const QString &name) {
    return name.contains("amdgpu") || name.contains("nouveau") || name.contains("nvidia")
        || name.contains("radeon");
}

bool wholeDisk(const QString &name) {
    static const QRegularExpression nvme(QStringLiteral("^nvme\\d+n\\d+$"));
    static const QRegularExpression mmc(QStringLiteral("^mmcblk\\d+$"));
    static const QRegularExpression plain(QStringLiteral("^(sd|vd|hd|xvd)[a-z]+$"));
    return nvme.match(name).hasMatch() || mmc.match(name).hasMatch() || plain.match(name).hasMatch();
}

} // namespace

SystemMonitor::SystemMonitor(QObject *parent) : ActiveSource(parent) {
    m_timer.setTimerType(Qt::CoarseTimer);
    m_timer.setInterval(m_intervalMs);
    connect(&m_timer, &QTimer::timeout, this, &SystemMonitor::tick);

    m_hostname = QSysInfo::machineHostName();
    m_kernel = QSysInfo::kernelType() + " " + QSysInfo::kernelVersion();
    const QByteArray os = slurp(QStringLiteral("/etc/os-release"));
    for (const QByteArray &line : os.split('\n')) {
        if (line.startsWith("PRETTY_NAME=")) {
            QString v = QString::fromUtf8(line.mid(12)).trimmed();
            if (v.startsWith('"') && v.endsWith('"')) v = v.mid(1, v.size() - 2);
            m_osName = v;
            break;
        }
    }
    if (m_osName.isEmpty()) m_osName = QSysInfo::prettyProductName();
}

QString SystemMonitor::gpuName() const {
    switch (m_gpuMode) {
    case GpuAmdSysfs:  return QStringLiteral("amdgpu");
    case GpuNvidiaSmi: return QStringLiteral("nvidia");
    default:           return QString();
    }
}

void SystemMonitor::setIntervalMs(int ms) {
    ms = qBound(250, ms, 10000);
    if (ms == m_intervalMs) return;
    m_intervalMs = ms;
    m_timer.setInterval(ms);
    emit intervalChanged();
}

void SystemMonitor::setHistorySize(int n) {
    n = qBound(2, n, 240);
    if (n == m_historySize) return;
    m_historySize = n;
    for (QVariantList *h : {&m_cpuHist, &m_ramHist, &m_gpuHist, &m_netRxHist, &m_netTxHist})
        while (h->size() > n) h->removeFirst();
    emit historySizeChanged();
}

void SystemMonitor::onStart() {
    if (!m_gpuDetected) detectGpu();
    if (m_cpuTempPath.isEmpty()) detectTemps();
    m_haveCpuPrev = false;
    m_prevNet.clear();
    m_prevNetMs = 0;
    m_prevDisk.clear();
    m_prevDiskMs = 0;
    tick();
    m_timer.start();
}

void SystemMonitor::onStop() {
    m_timer.stop();
    if (m_nvidiaProc) {
        m_nvidiaProc->disconnect(this);
        m_nvidiaProc->kill();
        m_nvidiaProc->deleteLater();
        m_nvidiaProc = nullptr;
    }
    m_cpuHist = m_ramHist = m_gpuHist = m_netRxHist = m_netTxHist = QVariantList();
    m_perCore = QVariantList();
    m_cpu = m_ram = m_swap = 0;
    m_netRx = m_netTx = 0;
    m_haveCpuPrev = false;
    m_prevNet.clear();
    m_prevNetMs = 0;
    m_prevDisk.clear();
    m_prevDiskMs = 0;
    m_diskRates.clear();
}

void SystemMonitor::tick() {
    readCpu();
    readMem();
    readLoad();
    readCpuTemp();
    readGpu();
    readNet();
    if (m_disks.isEmpty()) readDisks();
    readDiskRates();
    push(m_cpuHist, m_cpu);
    push(m_ramHist, m_ram);
    if (gpuAvailable() && m_gpu >= 0) push(m_gpuHist, m_gpu);
    pushNet(m_netRxHist, m_netRx);
    pushNet(m_netTxHist, m_netTx);
    emit updated();
}

void SystemMonitor::push(QVariantList &hist, qreal v) {
    hist.append(v);
    while (hist.size() > m_historySize) hist.removeFirst();
}

void SystemMonitor::pushNet(QVariantList &hist, qreal v) {
    hist.append(v);
    while (hist.size() > m_historySize) hist.removeFirst();
}

void SystemMonitor::readCpu() {
    const QByteArray data = slurp(QStringLiteral("/proc/stat"));
    if (data.isEmpty()) return;

    QVariantList cores;
    QVector<QPair<qulonglong, qulonglong>> next;
    qulonglong total = 0, idle = 0;
    bool first = true;
    const QList<QByteArray> lines = data.split('\n');
    for (const QByteArray &line : lines) {
        if (!line.startsWith("cpu")) continue;
        const QList<QByteArray> p = line.simplified().split(' ');
        if (p.size() < 8) continue;
        const bool aggregate = (p.first() == "cpu");
        qulonglong t = 0;
        for (int i = 1; i < p.size(); ++i) t += p.at(i).toULongLong();
        const qulonglong id = p.at(4).toULongLong() + p.at(5).toULongLong();
        if (aggregate) {
            total = t;
            idle = id;
        } else {
            const int idx = next.size();
            qreal pct = 0;
            if (idx < m_prevCore.size()) {
                const auto prev = m_prevCore.at(idx);
                if (t > prev.first) pct = clampPct(100.0 * (1.0 - qreal(id - prev.second) / qreal(t - prev.first)));
            }
            next.append({t, id});
            cores.append(pct);
        }
    }
    if (total > 0) {
        if (m_haveCpuPrev && total > m_prevTotal) {
            const qreal dTotal = qreal(total - m_prevTotal);
            const qreal dIdle = qreal(idle >= m_prevIdle ? idle - m_prevIdle : 0);
            m_cpu = clampPct(100.0 * (1.0 - dIdle / dTotal));
        }
        m_prevTotal = total;
        m_prevIdle = idle;
        m_haveCpuPrev = true;
    }
    m_prevCore = next;
    m_perCore = cores;
}

void SystemMonitor::readMem() {
    const QByteArray data = slurp(QStringLiteral("/proc/meminfo"));
    qint64 total = 0, avail = 0, swapTotal = 0, swapFree = 0;
    int found = 0;
    for (const QByteArray &line : data.split('\n')) {
        if (line.startsWith("MemTotal:"))          { total = line.simplified().split(' ').value(1).toLongLong(); ++found; }
        else if (line.startsWith("MemAvailable:")) { avail = line.simplified().split(' ').value(1).toLongLong(); ++found; }
        else if (line.startsWith("SwapTotal:"))    swapTotal = line.simplified().split(' ').value(1).toLongLong();
        else if (line.startsWith("SwapFree:"))     swapFree = line.simplified().split(' ').value(1).toLongLong();
        if (found == 2 && swapTotal > 0 && swapFree > 0) break;
    }
    if (total > 0) {
        m_ramTotalMb = total / 1024;
        m_ramUsedMb = qMax<qint64>(0, total - avail) / 1024;
        m_ram = clampPct(100.0 * qreal(m_ramUsedMb) / qreal(m_ramTotalMb));
    }
    m_swapTotalMb = swapTotal / 1024;
    m_swapUsedMb = qMax<qint64>(0, swapTotal - swapFree) / 1024;
    m_swap = m_swapTotalMb > 0 ? clampPct(100.0 * qreal(m_swapUsedMb) / qreal(m_swapTotalMb)) : 0;
}

void SystemMonitor::readLoad() {
    const QByteArray data = slurp(QStringLiteral("/proc/loadavg")).trimmed();
    if (data.isEmpty()) return;
    const QList<QByteArray> p = data.split(' ');
    if (p.size() >= 3) {
        m_load1 = p.at(0).toDouble();
        m_load5 = p.at(1).toDouble();
        m_load15 = p.at(2).toDouble();
    }
}

void SystemMonitor::detectTemps() {
    m_cpuTempPath.clear();
    m_gpuTempPath.clear();
    const QDir hw(QStringLiteral("/sys/class/hwmon"));
    const QStringList dirs = hw.entryList({QStringLiteral("hwmon*")}, QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    for (const QString &d : dirs) {
        const QString base = hw.filePath(d);
        const QString name = QString::fromUtf8(slurp(base + QStringLiteral("/name"))).trimmed();
        const bool isCpu = cpuHwmon(name);
        const bool isGpu = gpuHwmon(name);
        if (!isCpu && !isGpu) continue;
        const QStringList temps = QDir(base).entryList({QStringLiteral("temp*_input")}, QDir::Files, QDir::Name);
        if (temps.isEmpty()) continue;
        const QString path = base + "/" + temps.first();
        if (isCpu && m_cpuTempPath.isEmpty()) m_cpuTempPath = path;
        if (isGpu && m_gpuTempPath.isEmpty()) m_gpuTempPath = path;
    }
    const QString freq = QStringLiteral("/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq");
    if (QFile::exists(freq)) m_cpuFreqMhz = slurp(freq).trimmed().toDouble() / 1000.0;
}

void SystemMonitor::readCpuTemp() {
    if (!m_cpuTempPath.isEmpty()) {
        bool ok = false;
        const qreal milli = slurp(m_cpuTempPath).trimmed().toDouble(&ok);
        if (ok) m_cpuTemp = milli / 1000.0;
    }
    const QString freq = QStringLiteral("/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq");
    if (QFile::exists(freq)) {
        bool ok = false;
        const qreal khz = slurp(freq).trimmed().toDouble(&ok);
        if (ok && khz > 0) m_cpuFreqMhz = khz / 1000.0;
    }
}

void SystemMonitor::detectGpu() {
    m_gpuDetected = true;
    m_gpuMode = GpuNone;
    const QDir drm(QStringLiteral("/sys/class/drm"));
    const QStringList cards = drm.entryList({QStringLiteral("card?")}, QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    for (const QString &c : cards) {
        const QString dev = drm.filePath(c) + QStringLiteral("/device");
        const QString busy = dev + QStringLiteral("/gpu_busy_percent");
        if (!QFile::exists(busy)) continue;
        m_amdBusyPath = busy;
        const QString vu = dev + QStringLiteral("/mem_info_vram_used");
        const QString vt = dev + QStringLiteral("/mem_info_vram_total");
        if (QFile::exists(vu) && QFile::exists(vt)) { m_amdVramUsedPath = vu; m_amdVramTotalPath = vt; }
        m_gpuMode = GpuAmdSysfs;
        return;
    }
    m_nvidiaSmiPath = QStandardPaths::findExecutable(QStringLiteral("nvidia-smi"));
    if (!m_nvidiaSmiPath.isEmpty()) m_gpuMode = GpuNvidiaSmi;
}

void SystemMonitor::readGpu() {
    switch (m_gpuMode) {
    case GpuAmdSysfs: {
        bool ok = false;
        const qreal pct = slurp(m_amdBusyPath).trimmed().toDouble(&ok);
        if (ok) m_gpu = clampPct(pct);
        if (!m_amdVramUsedPath.isEmpty()) {
            const qreal used = slurp(m_amdVramUsedPath).trimmed().toDouble(&ok);
            if (ok) m_gpuVramUsedMb = qint64(used / 1048576.0);
            const qreal tot = slurp(m_amdVramTotalPath).trimmed().toDouble(&ok);
            if (ok) m_gpuVramTotalMb = qint64(tot / 1048576.0);
        }
        if (!m_gpuTempPath.isEmpty()) {
            const qreal milli = slurp(m_gpuTempPath).trimmed().toDouble(&ok);
            if (ok) m_gpuTemp = milli / 1000.0;
        }
        break;
    }
    case GpuNvidiaSmi:
        pollNvidia();
        break;
    default:
        break;
    }
}

void SystemMonitor::pollNvidia() {
    if (m_nvidiaProc) return;
    m_nvidiaProc = new QProcess(this);
    connect(m_nvidiaProc, &QProcess::finished, this, [this](int code, QProcess::ExitStatus) {
        QProcess *p = m_nvidiaProc;
        m_nvidiaProc = nullptr;
        if (p) {
            if (code == 0) {
                const QString out = QString::fromUtf8(p->readAllStandardOutput()).trimmed();
                const QStringList parts = out.split(',');
                bool ok = false;
                if (!parts.isEmpty()) {
                    const qreal pct = parts.at(0).trimmed().toDouble(&ok);
                    if (ok) m_gpu = clampPct(pct);
                }
                if (parts.size() >= 2) {
                    const qreal used = parts.at(1).trimmed().toDouble(&ok);
                    if (ok) m_gpuVramUsedMb = qint64(used);
                }
                if (parts.size() >= 3) {
                    const qreal tot = parts.at(2).trimmed().toDouble(&ok);
                    if (ok) m_gpuVramTotalMb = qint64(tot);
                }
            }
            p->deleteLater();
        }
    });
    connect(m_nvidiaProc, &QProcess::errorOccurred, this, [this](QProcess::ProcessError e) {
        if (e == QProcess::FailedToStart && m_nvidiaProc) {
            m_nvidiaProc->deleteLater();
            m_nvidiaProc = nullptr;
            m_gpuMode = GpuNone;
        }
    });
    m_nvidiaProc->start(m_nvidiaSmiPath,
        {QStringLiteral("--query-gpu=utilization.gpu,memory.used,memory.total"),
         QStringLiteral("--format=csv,noheader,nounits")});
}

void SystemMonitor::readNet() {
    const QByteArray data = slurp(QStringLiteral("/proc/net/dev"));
    if (data.isEmpty()) return;

    QHash<QString, QPair<qulonglong, qulonglong>> cur;
    QString best;
    qulonglong bestSum = 0;
    const QList<QByteArray> lines = data.split('\n');
    for (const QByteArray &line : lines) {
        const int colon = line.indexOf(':');
        if (colon < 0) continue;
        const QString name = QString::fromUtf8(line.left(colon)).trimmed();
        if (name.isEmpty() || name == "lo") continue;
        const QList<QByteArray> f = line.mid(colon + 1).simplified().split(' ');
        if (f.size() < 9) continue;
        const qulonglong rx = f.at(0).toULongLong();
        const qulonglong tx = f.at(8).toULongLong();
        cur.insert(name, {rx, tx});
        if (rx + tx > bestSum) { bestSum = rx + tx; best = name; }
    }
    if (best.isEmpty()) return;

    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    const auto it = cur.constFind(best);
    if (it != cur.constEnd()) {
        const auto prev = m_prevNet.constFind(best);
        if (prev != m_prevNet.constEnd() && m_prevNetMs > 0 && nowMs > m_prevNetMs) {
            const qreal dt = qreal(nowMs - m_prevNetMs) / 1000.0;
            if (dt > 0) {
                m_netRx = qMax<qreal>(0, qreal(it->first - prev->first) / dt);
                m_netTx = qMax<qreal>(0, qreal(it->second - prev->second) / dt);
            }
        }
        m_netIface = best;
    }
    m_prevNet = cur;
    m_prevNetMs = nowMs;
}

void SystemMonitor::readDisks() {
    QVariantList out;
    QSet<QString> seen;
    const QList<QStorageInfo> vols = QStorageInfo::mountedVolumes();
    for (const QStorageInfo &v : vols) {
        if (!v.isValid()) continue;
        const qint64 total = v.bytesTotal();
        if (total <= 0) continue;
        const QString fs = QString::fromUtf8(v.fileSystemType());
        if (fs == "tmpfs" || fs == "devtmpfs" || fs == "squashfs" || fs == "overlay"
            || fs == "ramfs" || fs == "proc" || fs == "sysfs" || fs == "cgroup2")
            continue;
        const QString root = v.rootPath();
        const bool realFs = root == "/" || root.startsWith("/home") || root.startsWith("/mnt")
            || root.startsWith("/media") || root.startsWith("/run/media")
            || QString::fromUtf8(v.device()).startsWith("/dev/");
        if (!realFs) continue;
        const QString dev = QString::fromUtf8(v.device());
        if (seen.contains(dev)) continue;
        seen.insert(dev);
        const qint64 used = total - v.bytesAvailable();
        out.append(QVariantMap{
            {QStringLiteral("name"), v.displayName().isEmpty() ? dev : v.displayName()},
            {QStringLiteral("mount"), root},
            {QStringLiteral("device"), dev},
            {QStringLiteral("fs"), fs},
            {QStringLiteral("total"), double(total)},
            {QStringLiteral("used"), double(used)},
            {QStringLiteral("percent"), total > 0 ? clampPct(100.0 * qreal(used) / qreal(total)) : 0.0},
        });
    }
    m_disks = out;
}

void SystemMonitor::readDiskRates() {
    const QByteArray data = slurp(QStringLiteral("/proc/diskstats"));
    if (data.isEmpty()) return;

    QHash<QString, QPair<qulonglong, qulonglong>> cur;
    const QList<QByteArray> lines = data.split('\n');
    for (const QByteArray &line : lines) {
        const QList<QByteArray> f = line.simplified().split(' ');
        if (f.size() < 10) continue;
        const QString name = QString::fromUtf8(f.at(2));
        if (!wholeDisk(name)) continue;
        cur.insert(name, {f.at(5).toULongLong(), f.at(9).toULongLong()});
    }

    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    const qreal dt = m_prevDiskMs > 0 ? qreal(nowMs - m_prevDiskMs) / 1000.0 : 0.0;
    if (dt > 0) {
        QVariantMap rates;
        for (auto it = cur.constBegin(); it != cur.constEnd(); ++it) {
            const auto prev = m_prevDisk.constFind(it.key());
            if (prev == m_prevDisk.constEnd()) continue;
            const qreal r = qMax<qreal>(0, qreal(it.value().first - prev.value().first) * 512.0 / dt);
            const qreal w = qMax<qreal>(0, qreal(it.value().second - prev.value().second) * 512.0 / dt);
            rates.insert(it.key(), QVariantMap{
                {QStringLiteral("r"), r}, {QStringLiteral("w"), w}});
        }
        if (!rates.isEmpty()) m_diskRates = rates;
    }
    m_prevDisk = cur;
    m_prevDiskMs = nowMs;
}
