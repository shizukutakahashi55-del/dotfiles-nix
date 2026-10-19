/****************************************************************************
** Meta object code from reading C++ file 'SystemMonitor.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.11.2)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../SystemMonitor.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'SystemMonitor.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 69
#error "This file was generated using the moc from 6.11.2. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

#ifndef Q_CONSTINIT
#define Q_CONSTINIT
#endif

QT_WARNING_PUSH
QT_WARNING_DISABLE_DEPRECATED
QT_WARNING_DISABLE_GCC("-Wuseless-cast")
namespace {
struct qt_meta_tag_ZN13SystemMonitorE_t {};
} // unnamed namespace

template <> constexpr inline auto SystemMonitor::qt_create_metaobjectdata<qt_meta_tag_ZN13SystemMonitorE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "SystemMonitor",
        "QML.Element",
        "auto",
        "QML.Singleton",
        "true",
        "updated",
        "",
        "intervalChanged",
        "historySizeChanged",
        "cpu",
        "perCore",
        "QVariantList",
        "ram",
        "swap",
        "ramUsedMb",
        "ramTotalMb",
        "swapUsedMb",
        "swapTotalMb",
        "load1",
        "load5",
        "load15",
        "cpuTemp",
        "cpuFreqMhz",
        "gpu",
        "gpuAvailable",
        "gpuName",
        "gpuTemp",
        "gpuVramUsedMb",
        "gpuVramTotalMb",
        "netRx",
        "netTx",
        "netIface",
        "disks",
        "diskRates",
        "QVariantMap",
        "cpuHistory",
        "ramHistory",
        "gpuHistory",
        "netRxHistory",
        "netTxHistory",
        "hostname",
        "kernel",
        "osName",
        "intervalMs",
        "historySize"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'updated'
        QtMocHelpers::SignalData<void()>(5, 6, QMC::AccessPublic, QMetaType::Void),
        // Signal 'intervalChanged'
        QtMocHelpers::SignalData<void()>(7, 6, QMC::AccessPublic, QMetaType::Void),
        // Signal 'historySizeChanged'
        QtMocHelpers::SignalData<void()>(8, 6, QMC::AccessPublic, QMetaType::Void),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'cpu'
        QtMocHelpers::PropertyData<qreal>(9, QMetaType::QReal, QMC::DefaultPropertyFlags, 0),
        // property 'perCore'
        QtMocHelpers::PropertyData<QVariantList>(10, 0x80000000 | 11, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 0),
        // property 'ram'
        QtMocHelpers::PropertyData<qreal>(12, QMetaType::QReal, QMC::DefaultPropertyFlags, 0),
        // property 'swap'
        QtMocHelpers::PropertyData<qreal>(13, QMetaType::QReal, QMC::DefaultPropertyFlags, 0),
        // property 'ramUsedMb'
        QtMocHelpers::PropertyData<qint64>(14, QMetaType::LongLong, QMC::DefaultPropertyFlags, 0),
        // property 'ramTotalMb'
        QtMocHelpers::PropertyData<qint64>(15, QMetaType::LongLong, QMC::DefaultPropertyFlags, 0),
        // property 'swapUsedMb'
        QtMocHelpers::PropertyData<qint64>(16, QMetaType::LongLong, QMC::DefaultPropertyFlags, 0),
        // property 'swapTotalMb'
        QtMocHelpers::PropertyData<qint64>(17, QMetaType::LongLong, QMC::DefaultPropertyFlags, 0),
        // property 'load1'
        QtMocHelpers::PropertyData<qreal>(18, QMetaType::QReal, QMC::DefaultPropertyFlags, 0),
        // property 'load5'
        QtMocHelpers::PropertyData<qreal>(19, QMetaType::QReal, QMC::DefaultPropertyFlags, 0),
        // property 'load15'
        QtMocHelpers::PropertyData<qreal>(20, QMetaType::QReal, QMC::DefaultPropertyFlags, 0),
        // property 'cpuTemp'
        QtMocHelpers::PropertyData<qreal>(21, QMetaType::QReal, QMC::DefaultPropertyFlags, 0),
        // property 'cpuFreqMhz'
        QtMocHelpers::PropertyData<qreal>(22, QMetaType::QReal, QMC::DefaultPropertyFlags, 0),
        // property 'gpu'
        QtMocHelpers::PropertyData<qreal>(23, QMetaType::QReal, QMC::DefaultPropertyFlags, 0),
        // property 'gpuAvailable'
        QtMocHelpers::PropertyData<bool>(24, QMetaType::Bool, QMC::DefaultPropertyFlags, 0),
        // property 'gpuName'
        QtMocHelpers::PropertyData<QString>(25, QMetaType::QString, QMC::DefaultPropertyFlags, 0),
        // property 'gpuTemp'
        QtMocHelpers::PropertyData<qreal>(26, QMetaType::QReal, QMC::DefaultPropertyFlags, 0),
        // property 'gpuVramUsedMb'
        QtMocHelpers::PropertyData<qint64>(27, QMetaType::LongLong, QMC::DefaultPropertyFlags, 0),
        // property 'gpuVramTotalMb'
        QtMocHelpers::PropertyData<qint64>(28, QMetaType::LongLong, QMC::DefaultPropertyFlags, 0),
        // property 'netRx'
        QtMocHelpers::PropertyData<qreal>(29, QMetaType::QReal, QMC::DefaultPropertyFlags, 0),
        // property 'netTx'
        QtMocHelpers::PropertyData<qreal>(30, QMetaType::QReal, QMC::DefaultPropertyFlags, 0),
        // property 'netIface'
        QtMocHelpers::PropertyData<QString>(31, QMetaType::QString, QMC::DefaultPropertyFlags, 0),
        // property 'disks'
        QtMocHelpers::PropertyData<QVariantList>(32, 0x80000000 | 11, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 0),
        // property 'diskRates'
        QtMocHelpers::PropertyData<QVariantMap>(33, 0x80000000 | 34, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 0),
        // property 'cpuHistory'
        QtMocHelpers::PropertyData<QVariantList>(35, 0x80000000 | 11, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 0),
        // property 'ramHistory'
        QtMocHelpers::PropertyData<QVariantList>(36, 0x80000000 | 11, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 0),
        // property 'gpuHistory'
        QtMocHelpers::PropertyData<QVariantList>(37, 0x80000000 | 11, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 0),
        // property 'netRxHistory'
        QtMocHelpers::PropertyData<QVariantList>(38, 0x80000000 | 11, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 0),
        // property 'netTxHistory'
        QtMocHelpers::PropertyData<QVariantList>(39, 0x80000000 | 11, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 0),
        // property 'hostname'
        QtMocHelpers::PropertyData<QString>(40, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Constant),
        // property 'kernel'
        QtMocHelpers::PropertyData<QString>(41, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Constant),
        // property 'osName'
        QtMocHelpers::PropertyData<QString>(42, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Constant),
        // property 'intervalMs'
        QtMocHelpers::PropertyData<int>(43, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 1),
        // property 'historySize'
        QtMocHelpers::PropertyData<int>(44, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 2),
    };
    QtMocHelpers::UintData qt_enums {
    };
    QtMocHelpers::UintData qt_constructors {};
    QtMocHelpers::ClassInfos qt_classinfo({
            {    1,    2 },
            {    3,    4 },
    });
    return QtMocHelpers::metaObjectData<SystemMonitor, void>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums, qt_constructors, qt_classinfo);
}
Q_CONSTINIT const QMetaObject SystemMonitor::staticMetaObject = { {
    QMetaObject::SuperData::link<ActiveSource::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN13SystemMonitorE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN13SystemMonitorE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN13SystemMonitorE_t>.metaTypes,
    nullptr
} };

void SystemMonitor::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<SystemMonitor *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->updated(); break;
        case 1: _t->intervalChanged(); break;
        case 2: _t->historySizeChanged(); break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (SystemMonitor::*)()>(_a, &SystemMonitor::updated, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (SystemMonitor::*)()>(_a, &SystemMonitor::intervalChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (SystemMonitor::*)()>(_a, &SystemMonitor::historySizeChanged, 2))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<qreal*>(_v) = _t->cpu(); break;
        case 1: *reinterpret_cast<QVariantList*>(_v) = _t->perCore(); break;
        case 2: *reinterpret_cast<qreal*>(_v) = _t->ram(); break;
        case 3: *reinterpret_cast<qreal*>(_v) = _t->swap(); break;
        case 4: *reinterpret_cast<qint64*>(_v) = _t->ramUsedMb(); break;
        case 5: *reinterpret_cast<qint64*>(_v) = _t->ramTotalMb(); break;
        case 6: *reinterpret_cast<qint64*>(_v) = _t->swapUsedMb(); break;
        case 7: *reinterpret_cast<qint64*>(_v) = _t->swapTotalMb(); break;
        case 8: *reinterpret_cast<qreal*>(_v) = _t->load1(); break;
        case 9: *reinterpret_cast<qreal*>(_v) = _t->load5(); break;
        case 10: *reinterpret_cast<qreal*>(_v) = _t->load15(); break;
        case 11: *reinterpret_cast<qreal*>(_v) = _t->cpuTemp(); break;
        case 12: *reinterpret_cast<qreal*>(_v) = _t->cpuFreqMhz(); break;
        case 13: *reinterpret_cast<qreal*>(_v) = _t->gpu(); break;
        case 14: *reinterpret_cast<bool*>(_v) = _t->gpuAvailable(); break;
        case 15: *reinterpret_cast<QString*>(_v) = _t->gpuName(); break;
        case 16: *reinterpret_cast<qreal*>(_v) = _t->gpuTemp(); break;
        case 17: *reinterpret_cast<qint64*>(_v) = _t->gpuVramUsedMb(); break;
        case 18: *reinterpret_cast<qint64*>(_v) = _t->gpuVramTotalMb(); break;
        case 19: *reinterpret_cast<qreal*>(_v) = _t->netRx(); break;
        case 20: *reinterpret_cast<qreal*>(_v) = _t->netTx(); break;
        case 21: *reinterpret_cast<QString*>(_v) = _t->netIface(); break;
        case 22: *reinterpret_cast<QVariantList*>(_v) = _t->disks(); break;
        case 23: *reinterpret_cast<QVariantMap*>(_v) = _t->diskRates(); break;
        case 24: *reinterpret_cast<QVariantList*>(_v) = _t->cpuHistory(); break;
        case 25: *reinterpret_cast<QVariantList*>(_v) = _t->ramHistory(); break;
        case 26: *reinterpret_cast<QVariantList*>(_v) = _t->gpuHistory(); break;
        case 27: *reinterpret_cast<QVariantList*>(_v) = _t->netRxHistory(); break;
        case 28: *reinterpret_cast<QVariantList*>(_v) = _t->netTxHistory(); break;
        case 29: *reinterpret_cast<QString*>(_v) = _t->hostname(); break;
        case 30: *reinterpret_cast<QString*>(_v) = _t->kernel(); break;
        case 31: *reinterpret_cast<QString*>(_v) = _t->osName(); break;
        case 32: *reinterpret_cast<int*>(_v) = _t->intervalMs(); break;
        case 33: *reinterpret_cast<int*>(_v) = _t->historySize(); break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 32: _t->setIntervalMs(*reinterpret_cast<int*>(_v)); break;
        case 33: _t->setHistorySize(*reinterpret_cast<int*>(_v)); break;
        default: break;
        }
    }
}

const QMetaObject *SystemMonitor::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *SystemMonitor::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN13SystemMonitorE_t>.strings))
        return static_cast<void*>(this);
    return ActiveSource::qt_metacast(_clname);
}

int SystemMonitor::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = ActiveSource::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 3)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 3;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 3)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 3;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 34;
    }
    return _id;
}

// SIGNAL 0
void SystemMonitor::updated()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void SystemMonitor::intervalChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void SystemMonitor::historySizeChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}
QT_WARNING_POP
