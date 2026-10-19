#pragma once

#include <QObject>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QtQml/qqmlregistration.h>

// FontProbe — reconoce y registra las fuentes que el tema necesita.
//
// Problema que resuelve: Qt arma su base de fuentes UNA vez al arrancar y, en
// NixOS, a veces no ve las de home-manager / nix-profile / per-user aunque
// `fc-list` sí las liste (o se instalaron con el shell ya abierto). Además, los
// nombres no siempre coinciden letra por letra ("MPLUSRounded1c" vs
// "M PLUS Rounded 1c").
//
//   has(nombre)      ¿Qt conoce la familia? (sin distinguir mayúsculas/espacios)
//   resolve(nombre)  nombre REAL con el que Qt la conoce, o "" si no está
//   families()       todas las familias que Qt conoce ahora
//   rescan(wanted)   busca en las carpetas estándar archivos de las familias
//                    pedidas que Qt aún no conoce y los registra
//                    (QFontDatabase::addApplicationFont). Devuelve cuántos.
//   searchDirs()     carpetas que se revisan (para diagnóstico)
//   lastReport       resumen de la última búsqueda
//
// Cuesta CERO hasta que se llama a rescan(); solo recorre carpetas de fuentes
// y filtra por nombre de archivo antes de abrir nada.
class FontProbe final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QString lastReport READ lastReport NOTIFY changed)
    Q_PROPERTY(int registered READ registered NOTIFY changed)

public:
    explicit FontProbe(QObject *parent = nullptr);

    QString lastReport() const { return m_report; }
    int registered() const { return m_registered; }

    Q_INVOKABLE QStringList families() const;
    Q_INVOKABLE bool has(const QString &family) const;
    Q_INVOKABLE QString resolve(const QString &family) const;
    Q_INVOKABLE int rescan(const QStringList &wanted);
    Q_INVOKABLE QStringList searchDirs() const;

    static QString normalize(const QString &s);

signals:
    void changed();

private:
    QSet<QString> m_seenFiles;
    QString m_report;
    int m_registered = 0;
};
