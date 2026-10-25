/****************************************************************************
** Meta object code from reading C++ file 'ProcessList.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.11.2)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../ProcessList.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'ProcessList.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN11ProcessListE_t {};
} // unnamed namespace

template <> constexpr inline auto ProcessList::qt_create_metaobjectdata<qt_meta_tag_ZN11ProcessListE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "ProcessList",
        "QML.Element",
        "auto",
        "updated",
        "",
        "sortByChanged",
        "limitChanged",
        "intervalChanged",
        "kill",
        "pid",
        "sig",
        "rows",
        "QVariantList",
        "total",
        "numCores",
        "cpuTotal",
        "memTotalMb",
        "sortBy",
        "limit",
        "intervalMs"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'updated'
        QtMocHelpers::SignalData<void()>(3, 4, QMC::AccessPublic, QMetaType::Void),
        // Signal 'sortByChanged'
        QtMocHelpers::SignalData<void()>(5, 4, QMC::AccessPublic, QMetaType::Void),
        // Signal 'limitChanged'
        QtMocHelpers::SignalData<void()>(6, 4, QMC::AccessPublic, QMetaType::Void),
        // Signal 'intervalChanged'
        QtMocHelpers::SignalData<void()>(7, 4, QMC::AccessPublic, QMetaType::Void),
        // Method 'kill'
        QtMocHelpers::MethodData<bool(int, int)>(8, 4, QMC::AccessPublic, QMetaType::Bool, {{
            { QMetaType::Int, 9 }, { QMetaType::Int, 10 },
        }}),
        // Method 'kill'
        QtMocHelpers::MethodData<bool(int)>(8, 4, QMC::AccessPublic | QMC::MethodCloned, QMetaType::Bool, {{
            { QMetaType::Int, 9 },
        }}),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'rows'
        QtMocHelpers::PropertyData<QVariantList>(11, 0x80000000 | 12, QMC::DefaultPropertyFlags | QMC::EnumOrFlag, 0),
        // property 'total'
        QtMocHelpers::PropertyData<int>(13, QMetaType::Int, QMC::DefaultPropertyFlags, 0),
        // property 'numCores'
        QtMocHelpers::PropertyData<int>(14, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Constant),
        // property 'cpuTotal'
        QtMocHelpers::PropertyData<qreal>(15, QMetaType::QReal, QMC::DefaultPropertyFlags, 0),
        // property 'memTotalMb'
        QtMocHelpers::PropertyData<qint64>(16, QMetaType::LongLong, QMC::DefaultPropertyFlags, 0),
        // property 'sortBy'
        QtMocHelpers::PropertyData<QString>(17, QMetaType::QString, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 1),
        // property 'limit'
        QtMocHelpers::PropertyData<int>(18, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 2),
        // property 'intervalMs'
        QtMocHelpers::PropertyData<int>(19, QMetaType::Int, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 3),
    };
    QtMocHelpers::UintData qt_enums {
    };
    QtMocHelpers::UintData qt_constructors {};
    QtMocHelpers::ClassInfos qt_classinfo({
            {    1,    2 },
    });
    return QtMocHelpers::metaObjectData<ProcessList, void>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums, qt_constructors, qt_classinfo);
}
Q_CONSTINIT const QMetaObject ProcessList::staticMetaObject = { {
    QMetaObject::SuperData::link<ActiveSource::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN11ProcessListE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN11ProcessListE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN11ProcessListE_t>.metaTypes,
    nullptr
} };

void ProcessList::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<ProcessList *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->updated(); break;
        case 1: _t->sortByChanged(); break;
        case 2: _t->limitChanged(); break;
        case 3: _t->intervalChanged(); break;
        case 4: { bool _r = _t->kill((*reinterpret_cast<std::add_pointer_t<int>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[2])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        case 5: { bool _r = _t->kill((*reinterpret_cast<std::add_pointer_t<int>>(_a[1])));
            if (_a[0]) *reinterpret_cast<bool*>(_a[0]) = std::move(_r); }  break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (ProcessList::*)()>(_a, &ProcessList::updated, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (ProcessList::*)()>(_a, &ProcessList::sortByChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (ProcessList::*)()>(_a, &ProcessList::limitChanged, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (ProcessList::*)()>(_a, &ProcessList::intervalChanged, 3))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<QVariantList*>(_v) = _t->rows(); break;
        case 1: *reinterpret_cast<int*>(_v) = _t->total(); break;
        case 2: *reinterpret_cast<int*>(_v) = _t->numCores(); break;
        case 3: *reinterpret_cast<qreal*>(_v) = _t->cpuTotal(); break;
        case 4: *reinterpret_cast<qint64*>(_v) = _t->memTotalMb(); break;
        case 5: *reinterpret_cast<QString*>(_v) = _t->sortBy(); break;
        case 6: *reinterpret_cast<int*>(_v) = _t->limit(); break;
        case 7: *reinterpret_cast<int*>(_v) = _t->intervalMs(); break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 5: _t->setSortBy(*reinterpret_cast<QString*>(_v)); break;
        case 6: _t->setLimit(*reinterpret_cast<int*>(_v)); break;
        case 7: _t->setIntervalMs(*reinterpret_cast<int*>(_v)); break;
        default: break;
        }
    }
}

const QMetaObject *ProcessList::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *ProcessList::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN11ProcessListE_t>.strings))
        return static_cast<void*>(this);
    return ActiveSource::qt_metacast(_clname);
}

int ProcessList::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = ActiveSource::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 6)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 6;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 6)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 6;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 8;
    }
    return _id;
}

// SIGNAL 0
void ProcessList::updated()
{
    QMetaObject::activate(this, &staticMetaObject, 0, nullptr);
}

// SIGNAL 1
void ProcessList::sortByChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void ProcessList::limitChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void ProcessList::intervalChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 3, nullptr);
}
QT_WARNING_POP
