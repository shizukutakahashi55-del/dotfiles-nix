/****************************************************************************
** Generated QML type registration code
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include <QtQml/qqml.h>
#include <QtQml/qqmlmoduleregistration.h>

#if __has_include(<AnimationController.h>)
#  include <AnimationController.h>
#endif
#if __has_include(<FontProbe.h>)
#  include <FontProbe.h>
#endif
#if __has_include(<ProcessList.h>)
#  include <ProcessList.h>
#endif
#if __has_include(<SystemMonitor.h>)
#  include <SystemMonitor.h>
#endif
#if __has_include(<SystemStats.h>)
#  include <SystemStats.h>
#endif
#if __has_include(<WmStream.h>)
#  include <WmStream.h>
#endif


#if !defined(QT_STATIC)
#define Q_QMLTYPE_EXPORT Q_DECL_EXPORT
#else
#define Q_QMLTYPE_EXPORT
#endif
Q_QMLTYPE_EXPORT void qml_register_types_OozeShell_Native()
{
    QT_WARNING_PUSH QT_WARNING_DISABLE_DEPRECATED
    QMetaType::fromType<ActiveSource *>().id();
    qmlRegisterTypesAndRevisions<AnimationController>("OozeShell.Native", 1);
    qmlRegisterTypesAndRevisions<FontProbe>("OozeShell.Native", 1);
    qmlRegisterTypesAndRevisions<ProcessList>("OozeShell.Native", 1);
    qmlRegisterTypesAndRevisions<SystemMonitor>("OozeShell.Native", 1);
    qmlRegisterTypesAndRevisions<SystemStats>("OozeShell.Native", 1);
    qmlRegisterTypesAndRevisions<WmStream>("OozeShell.Native", 1);
    QT_WARNING_POP
    qmlRegisterModule("OozeShell.Native", 1, 0);
}

static const QQmlModuleRegistration oozeShellNativeRegistration("OozeShell.Native", qml_register_types_OozeShell_Native);
