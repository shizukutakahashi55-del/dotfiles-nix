#include "FontProbe.h"

#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QFontDatabase>
#include <QStandardPaths>

FontProbe::FontProbe(QObject *parent) : QObject(parent) {}

QString FontProbe::normalize(const QString &s) {
    QString out;
    out.reserve(s.size());
    for (const QChar c : s)
        if (c.isLetterOrNumber()) out.append(c.toLower());
    return out;
}

QStringList FontProbe::families() const { return QFontDatabase::families(); }

QString FontProbe::resolve(const QString &family) const {
    const QString want = normalize(family);
    if (want.isEmpty()) return {};
    const QStringList all = QFontDatabase::families();
    for (const QString &f : all)
        if (normalize(f) == want) return f;
    return {};
}

bool FontProbe::has(const QString &family) const { return !resolve(family).isEmpty(); }

QStringList FontProbe::searchDirs() const {
    QStringList dirs;
    const QString home = QDir::homePath();
    const QString user = qEnvironmentVariable("USER");

    // XDG: ~/.local/share/fonts, $XDG_DATA_DIRS/fonts, ~/.fonts
    for (const QString &d : QStandardPaths::standardLocations(QStandardPaths::FontsLocation))
        dirs << d;
    dirs << home + QStringLiteral("/.fonts");

    // Nix / NixOS / home-manager
    dirs << home + QStringLiteral("/.nix-profile/share/fonts")
         << home + QStringLiteral("/.local/state/nix/profile/share/fonts")
         << QStringLiteral("/etc/profiles/per-user/%1/share/fonts").arg(user)
         << QStringLiteral("/run/current-system/sw/share/fonts")
         << QStringLiteral("/run/current-system/sw/share/X11/fonts")
         << QStringLiteral("/nix/var/nix/profiles/default/share/fonts");

    // Distros "normales"
    dirs << QStringLiteral("/usr/share/fonts") << QStringLiteral("/usr/local/share/fonts");

    // Carpetas extra a mano:  OOZESHELL_FONT_DIRS=/ruta/a:/ruta/b
    const QString extra = qEnvironmentVariable("OOZESHELL_FONT_DIRS");
    if (!extra.isEmpty()) dirs << extra.split(QLatin1Char(':'), Qt::SkipEmptyParts);

    QStringList out;
    QSet<QString> seen;
    for (const QString &d : std::as_const(dirs)) {
        const QString canon = QFileInfo(d).canonicalFilePath();
        if (canon.isEmpty() || seen.contains(canon)) continue;
        seen.insert(canon);
        out << canon;
    }
    return out;
}

int FontProbe::rescan(const QStringList &wanted) {
    // Tokens normalizados ("M PLUS Rounded 1c" -> "mplusrounded1c") que deben
    // aparecer en el NOMBRE DEL ARCHIVO para que valga la pena registrarlo.
    QStringList tokens;
    for (const QString &w : wanted) {
        const QString t = normalize(w);
        if (t.size() >= 4 && !tokens.contains(t)) tokens << t;
    }

    int added = 0, scanned = 0;
    QStringList newFamilies;
    const QStringList dirs = searchDirs();

    for (const QString &dir : dirs) {
        QDirIterator it(dir,
            { QStringLiteral("*.ttf"), QStringLiteral("*.otf"), QStringLiteral("*.ttc") },
            QDir::Files, QDirIterator::Subdirectories | QDirIterator::FollowSymlinks);
        while (it.hasNext()) {
            const QString path = it.next();
            ++scanned;
            const QString canon = QFileInfo(path).canonicalFilePath();
            if (canon.isEmpty() || m_seenFiles.contains(canon)) continue;

            const QString base = normalize(QFileInfo(path).completeBaseName());
            bool match = false;
            for (const QString &t : std::as_const(tokens))
                if (base.contains(t)) { match = true; break; }
            if (!match) continue;
            m_seenFiles.insert(canon);

            const int id = QFontDatabase::addApplicationFont(canon);
            if (id < 0) continue;
            ++added;
            newFamilies << QFontDatabase::applicationFontFamilies(id);
        }
    }

    m_registered += added;
    m_report = QStringLiteral("%1 archivos revisados en %2 carpetas, %3 fuentes registradas%4")
        .arg(scanned).arg(dirs.size()).arg(added)
        .arg(newFamilies.isEmpty() ? QString()
             : QStringLiteral(" (") + newFamilies.join(QStringLiteral(", ")) + QLatin1Char(')'));
    emit changed();
    return added;
}
