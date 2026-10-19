/****************************************************************************
** Meta object code from reading C++ file 'SystemStats.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.11.2)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../SystemStats.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'SystemStats.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN11SystemStatsE_t {};
} // unnamed namespace

template <> constexpr inline auto SystemStats::qt_create_metaobjectdata<qt_meta_tag_ZN11SystemStatsE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "SystemStats",
        "QML.Element",
        "auto",
        "QML.Singleton",
        "true",
        "updated",
        "",
        "intervalChanged",
        "historySizeChanged",
        "cpu",
        "ram",
        "gpu",
        "ramUsedKb",
        "ramTotalKb",
        "gpuAvailable",
        "gpuName",
        "cpuHistory",
        "QVariantList",
        "ramHistory",
        "gpuHistory",
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
        // property 'ram'
        QtMocHelpers::PropertyData<qreal>(10, QMetaType::QReal, QMC::DefaultPropertyFlags, 0),
        // property 'gpu'
        QtMocHelpers::PropertyData<qreal>(11, QMetaType::QReal, QMC::DefaultPropertyFlags, 0),
        // property 'ramUsedKb'
        QtMocHelpers::PropertyData<qint64>(12, QMetaType::LongLong, QMC::DefaultPropertyFlags, 0),
        // property 'ramTotalKb'
        QtMocHelpers::PropertyData<qint64>(13, QMetaType::LongLong, QMC::DefaultPropertyFlags, 0),
        // property 'gpuAvailable'
        QtMocHelpers::PropertyData<bool>(14, QMetaType::Bool, QMC::DefaultPropertyFlags, 0),
        // property 'gpuName'
        QtMocHelpers::PropertyData<QString>(15, QMetaType::QString, QMC::DefaultPropertyFlags, 0),
        // property 'cpuHistory'
        QtMocHelpers::PropertyData<QVariantList>(16, 0x80000000 | 17, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 0),
        // property 'ramHistory'
        QtMocHelpers::PropertyData<QVariantList>(18, 0x80000000 | 17, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 0),
        // property 'gpuHistory'
        QtMocHelpers::PropertyData<QVariantList>(19, 0x80000000 | 17, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 0),
        // property 'intervalMs'
        QtMocHelpers::PropertyData<int>(20, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 1),
        // property 'historySize'
        QtMocHelpers::PropertyData<int>(21, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 2),
    };
    QtMocHelpers::UintData qt_enums {
    };
    QtMocHelpers::UintData qt_constructors {};
    QtMocHelpers::ClassInfos qt_classinfo({
            {    1,    2 },
            {    3,    4 },
    });
    return QtMocHelpers::metaObjectData<SystemStats, void>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums, qt_constructors, qt_classinfo);
}
Q_CONSTINIT const QMetaObject SystemStats::staticMetaObject = { {
    QMetaObject::SuperData::link<ActiveSource::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN11SystemStatsE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN11SystemStatsE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN11SystemStatsE_t>.metaTypes,
    nullptr
} };

void SystemStats::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<SystemStats *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->updated(); break;
        case 1: _t->intervalChanged(); break;
        case 2: _t->historySizeChanged(); break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (SystemStats::*)()>(_a, &SystemStats::updated, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (SystemStats::*)()>(_a, &SystemStats::intervalChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (SystemStats::*)()>(_a, &SystemStats::historySizeChanged, 2))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<qreal*>(_v) = _t->cpu(); break;
        case 1: *reinterpret_cast<qreal*>(_v) = _t->ram(); break;
        case 2: *reinterpret_cast<qreal*>(_v) = _t->gpu(); break;
        case 3: *reinterpret_cast<qint64*>(_v) = _t->ramUsedKb(); break;
        case 4: *reinterpret_cast<qint64*>(_v) = _t->ramTotalKb(); break;
        case 5: *reinterpret_cast<bool*>(_v) = _t->gpuAvailable(); break;
        case 6: *reinterpret_cast<QString*>(_v) = _t->gpuName(); break;
        case 7: *reinterpret_cast<QVariantList*>(_v) = _t->cpuHistory(); break;
        case 8: *reinterpret_cast<QVariantList*>(_v) = _t->ramHistory(); break;
        case 9: *reinterpret_cast<QVariantList*>(_v) = _t->gpuHistory(); break;
        case 10: *reinterpret_cast<int*>(_v) = _t->intervalMs(); break;
        case 11: *reinterpret_cast<int*>(_v) = _t->historySize(); break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 10: _t->setIntervalMs(*reinterpret_cast<int*>(_v)); break;
        case 11: _t->setHistorySize(*reinterpret_cast<int*>(_v)); break;
        default: break;
        }
    }
}

const QMetaObject *SystemStats::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *SystemStats::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN11SystemStatsE_t>.strings))
        return static_cast<void*>(this);
    return ActiveSource::qt_metacast(_clname);
}

int SystemStats::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
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
        _id -= 12;
    }
    return _id;
}

// SIGNAL 0
void SystemStats::updated()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void SystemStats::intervalChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void SystemStats::historySizeChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}
QT_WARNING_POP
