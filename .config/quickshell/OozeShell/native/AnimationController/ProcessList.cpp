#include "ProcessList.h"

#include <QDir>
#include <QFile>
#include <QThread>
#include <QVariantMap>
#include <QtGlobal>
#include <algorithm>
#include <csignal>
#include <unistd.h>

namespace {

QByteArray slurp(const QString &path) {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) return {};
    return f.readAll();
}

} // namespace

ProcessList::ProcessList(QObject *parent) : ActiveSource(parent) {
    m_timer.setTimerType(Qt::CoarseTimer);
    m_timer.setInterval(m_intervalMs);
    connect(&m_timer, &QTimer::timeout, this, &ProcessList::tick);
    m_numCores = qMax(1, QThread::idealThreadCount());
    const long ps = sysconf(_SC_PAGESIZE);
    m_pageKb = ps > 0 ? qint64(ps) / 1024 : 4;
}

void ProcessList::setSortBy(const QString &key) {
    const QString k = (key == "mem" || key == "pid" || key == "name") ? key : QStringLiteral("cpu");
    if (k == m_sortBy) return;
    m_sortBy = k;
    emit sortByChanged();
    if (wanted() && !m_all.isEmpty()) {
        rebuild();
        emit updated();
    }
}

void ProcessList::setLimit(int n) {
    n = qBound(0, n, 2000);
    if (n == m_limit) return;
    m_limit = n;
    emit limitChanged();
    if (wanted() && !m_all.isEmpty()) {
        rebuild();
        emit updated();
    }
}

void ProcessList::setIntervalMs(int ms) {
    ms = qBound(500, ms, 10000);
    if (ms == m_intervalMs) return;
    m_intervalMs = ms;
    m_timer.setInterval(ms);
    emit intervalChanged();
}

void ProcessList::onStart() {
    if (!m_usersLoaded) loadUsers();
    m_havePrev = false;
    m_prevTicks.clear();
    tick();
    m_timer.start();
}

void ProcessList::onStop() {
    m_timer.stop();
    m_rows = QVariantList();
    m_all.clear();
    m_prevTicks.clear();
    m_total = 0;
    m_cpuTotal = 0;
    m_memTotalMb = 0;
    m_havePrev = false;
}

void ProcessList::loadUsers() {
    m_usersLoaded = true;
    const QByteArray data = slurp(QStringLiteral("/etc/passwd"));
    for (const QByteArray &line : data.split('\n')) {
        const QList<QByteArray> p = line.split(':');
        if (p.size() < 3) continue;
        bool ok = false;
        const unsigned uid = p.at(2).toUInt(&ok);
        if (ok) m_users.insert(uid, QString::fromUtf8(p.at(0)));
    }
}

QString ProcessList::userName(unsigned uid) {
    const auto it = m_users.constFind(uid);
    if (it != m_users.constEnd()) return it.value();
    return QString::number(uid);
}

void ProcessList::tick() {
    const QByteArray stat = slurp(QStringLiteral("/proc/stat"));
    const int eol = stat.indexOf('\n');
    if (eol <= 0) return;
    qulonglong total = 0;
    {
        const QList<QByteArray> p = stat.left(eol).simplified().split(' ');
        for (int i = 1; i < p.size() && i <= 8; ++i) total += p.at(i).toULongLong();
    }
    const qulonglong dTotal = (m_havePrev && total > m_prevTotal) ? (total - m_prevTotal) : 0;

    QHash<int, qulonglong> nextTicks;
    QVector<QVariantMap> out;
    qreal cpuTotal = 0;
    qint64 memTotalMb = 0;

    const QDir proc(QStringLiteral("/proc"));
    const QStringList names = proc.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::NoSort);
    for (const QString &name : names) {
        bool ok = false;
        const int pid = name.toInt(&ok);
        if (!ok) continue;

        const QByteArray raw = slurp(proc.filePath(name) + QStringLiteral("/stat"));
        if (raw.isEmpty()) continue;
        const int open = raw.indexOf('(');
        const int close = raw.lastIndexOf(')');
        if (open < 0 || close <= open) continue;
        const QString comm = QString::fromUtf8(raw.mid(open + 1, close - open - 1));
        const QList<QByteArray> rest = raw.mid(close + 2).simplified().split(' ');
        if (rest.size() < 13) continue;
        const QString state = QString::fromUtf8(rest.at(0));
        const qulonglong utime = rest.at(11).toULongLong();
        const qulonglong stime = rest.at(12).toULongLong();
        const qulonglong ticks = utime + stime;
        nextTicks.insert(pid, ticks);

        qreal cpu = 0;
        const auto prev = m_prevTicks.constFind(pid);
        if (prev != m_prevTicks.constEnd() && dTotal > 0 && ticks >= prev.value())
            cpu = 100.0 * qreal(ticks - prev.value()) * qreal(m_numCores) / qreal(dTotal);

        unsigned uid = 0;
        qint64 rssKb = 0;
        const QByteArray status = slurp(proc.filePath(name) + QStringLiteral("/status"));
        for (const QByteArray &line : status.split('\n')) {
            if (line.startsWith("Uid:")) {
                const QList<QByteArray> u = line.mid(4).simplified().split(' ');
                if (!u.isEmpty()) uid = u.first().toUInt();
            } else if (line.startsWith("VmRSS:")) {
                rssKb = line.mid(6).simplified().split(' ').value(0).toLongLong();
            }
            if (uid != 0 && rssKb != 0) break;
        }
        if (rssKb == 0) {
            const QList<QByteArray> stm = slurp(proc.filePath(name) + QStringLiteral("/statm")).simplified().split(' ');
            if (stm.size() >= 2) rssKb = stm.at(1).toLongLong() * m_pageKb;
        }

        const qreal memMb = qreal(rssKb) / 1024.0;
        cpuTotal += cpu;
        memTotalMb += qint64(memMb);
        out.append(QVariantMap{
            {QStringLiteral("pid"), pid},
            {QStringLiteral("name"), comm},
            {QStringLiteral("user"), userName(uid)},
            {QStringLiteral("state"), state},
            {QStringLiteral("cpu"), cpu},
            {QStringLiteral("memMb"), memMb},
        });
    }

    m_prevTotal = total;
    m_prevTicks = nextTicks;
    m_havePrev = true;

    m_all = out;
    m_total = nextTicks.size();
    m_cpuTotal = cpuTotal;
    m_memTotalMb = memTotalMb;
    rebuild();
    emit updated();
}

void ProcessList::rebuild() {
    QVector<QVariantMap> out = m_all;
    sortRows(out);
    if (m_limit > 0 && out.size() > m_limit) out.resize(m_limit);
    QVariantList rows;
    rows.reserve(out.size());
    for (const QVariantMap &r : out) rows.append(r);
    m_rows = rows;
}

void ProcessList::sortRows(QVector<QVariantMap> &rows) const {
    const QString key = m_sortBy;
    std::stable_sort(rows.begin(), rows.end(), [&key](const QVariantMap &a, const QVariantMap &b) {
        const int pa = a.value(QStringLiteral("pid")).toInt();
        const int pb = b.value(QStringLiteral("pid")).toInt();
        if (key == QLatin1String("pid")) return pa < pb;
        if (key == QLatin1String("name")) {
            const int c = a.value(QStringLiteral("name")).toString()
                              .compare(b.value(QStringLiteral("name")).toString(), Qt::CaseInsensitive);
            return c != 0 ? c < 0 : pa < pb;
        }
        const QString first = key == QLatin1String("mem") ? QStringLiteral("memMb") : QStringLiteral("cpu");
        const QString second = key == QLatin1String("mem") ? QStringLiteral("cpu") : QStringLiteral("memMb");
        const qreal x = a.value(first).toReal();
        const qreal y = b.value(first).toReal();
        if (x != y) return x > y;
        const qreal x2 = a.value(second).toReal();
        const qreal y2 = b.value(second).toReal();
        if (x2 != y2) return x2 > y2;
        return pa < pb;
    });
}

bool ProcessList::kill(int pid, int sig) {
    if (pid <= 1) return false;
    return ::kill(pid, sig) == 0;
}
