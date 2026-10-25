/****************************************************************************
** Meta object code from reading C++ file 'WmStream.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.11.2)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../WmStream.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'WmStream.h' doesn't include <QObject>."
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
struct qt_meta_tag_ZN8WmStreamE_t {};
} // unnamed namespace

template <> constexpr inline auto WmStream::qt_create_metaobjectdata<qt_meta_tag_ZN8WmStreamE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "WmStream",
        "QML.Element",
        "auto",
        "parsed",
        "",
        "QVariantMap",
        "obj",
        "commandChanged",
        "activeChanged",
        "runningChanged",
        "restartsChanged",
        "droppedLinesChanged",
        "onReadyRead",
        "onFinished",
        "code",
        "QProcess::ExitStatus",
        "status",
        "onRestartTimeout",
        "command",
        "active",
        "running",
        "restarts",
        "droppedLines"
    };

    QtMocHelpers::UintData qt_methods {
        // Signal 'parsed'
        QtMocHelpers::SignalData<void(const QVariantMap &)>(3, 4, QMC::AccessPublic, QMetaType::Void, {{
            { 0x80000000 | 5, 6 },
        }}),
        // Signal 'commandChanged'
        QtMocHelpers::SignalData<void()>(7, 4, QMC::AccessPublic, QMetaType::Void),
        // Signal 'activeChanged'
        QtMocHelpers::SignalData<void()>(8, 4, QMC::AccessPublic, QMetaType::Void),
        // Signal 'runningChanged'
        QtMocHelpers::SignalData<void()>(9, 4, QMC::AccessPublic, QMetaType::Void),
        // Signal 'restartsChanged'
        QtMocHelpers::SignalData<void()>(10, 4, QMC::AccessPublic, QMetaType::Void),
        // Signal 'droppedLinesChanged'
        QtMocHelpers::SignalData<void()>(11, 4, QMC::AccessPublic, QMetaType::Void),
        // Slot 'onReadyRead'
        QtMocHelpers::SlotData<void()>(12, 4, QMC::AccessPrivate, QMetaType::Void),
        // Slot 'onFinished'
        QtMocHelpers::SlotData<void(int, QProcess::ExitStatus)>(13, 4, QMC::AccessPrivate, QMetaType::Void, {{
            { QMetaType::Int, 14 }, { 0x80000000 | 15, 16 },
        }}),
        // Slot 'onRestartTimeout'
        QtMocHelpers::SlotData<void()>(17, 4, QMC::AccessPrivate, QMetaType::Void),
    };
    QtMocHelpers::UintData qt_properties {
        // property 'command'
        QtMocHelpers::PropertyData<QStringList>(18, QMetaType::QStringList, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 1),
        // property 'active'
        QtMocHelpers::PropertyData<bool>(19, QMetaType::Bool, QMC::DefaultPropertyFlags | QMC::Writable | QMC::StdCppSet, 2),
        // property 'running'
        QtMocHelpers::PropertyData<bool>(20, QMetaType::Bool, QMC::DefaultPropertyFlags, 3),
        // property 'restarts'
        QtMocHelpers::PropertyData<int>(21, QMetaType::Int, QMC::DefaultPropertyFlags, 4),
        // property 'droppedLines'
        QtMocHelpers::PropertyData<int>(22, QMetaType::Int, QMC::DefaultPropertyFlags, 5),
    };
    QtMocHelpers::UintData qt_enums {
    };
    QtMocHelpers::UintData qt_constructors {};
    QtMocHelpers::ClassInfos qt_classinfo({
            {    1,    2 },
    });
    return QtMocHelpers::metaObjectData<WmStream, void>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums, qt_constructors, qt_classinfo);
}
Q_CONSTINIT const QMetaObject WmStream::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN8WmStreamE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN8WmStreamE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN8WmStreamE_t>.metaTypes,
    nullptr
} };

void WmStream::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<WmStream *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->parsed((*reinterpret_cast<std::add_pointer_t<QVariantMap>>(_a[1]))); break;
        case 1: _t->commandChanged(); break;
        case 2: _t->activeChanged(); break;
        case 3: _t->runningChanged(); break;
        case 4: _t->restartsChanged(); break;
        case 5: _t->droppedLinesChanged(); break;
        case 6: _t->onReadyRead(); break;
        case 7: _t->onFinished((*reinterpret_cast<std::add_pointer_t<int>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<QProcess::ExitStatus>>(_a[2]))); break;
        case 8: _t->onRestartTimeout(); break;
        default: ;
        }
    }
    if (_c == QMetaObject::IndexOfMethod) {
        if (QtMocHelpers::indexOfMethod<void (WmStream::*)(const QVariantMap & )>(_a, &WmStream::parsed, 0))
            return;
        if (QtMocHelpers::indexOfMethod<void (WmStream::*)()>(_a, &WmStream::commandChanged, 1))
            return;
        if (QtMocHelpers::indexOfMethod<void (WmStream::*)()>(_a, &WmStream::activeChanged, 2))
            return;
        if (QtMocHelpers::indexOfMethod<void (WmStream::*)()>(_a, &WmStream::runningChanged, 3))
            return;
        if (QtMocHelpers::indexOfMethod<void (WmStream::*)()>(_a, &WmStream::restartsChanged, 4))
            return;
        if (QtMocHelpers::indexOfMethod<void (WmStream::*)()>(_a, &WmStream::droppedLinesChanged, 5))
            return;
    }
    if (_c == QMetaObject::ReadProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: *reinterpret_cast<QStringList*>(_v) = _t->command(); break;
        case 1: *reinterpret_cast<bool*>(_v) = _t->active(); break;
        case 2: *reinterpret_cast<bool*>(_v) = _t->running(); break;
        case 3: *reinterpret_cast<int*>(_v) = _t->restarts(); break;
        case 4: *reinterpret_cast<int*>(_v) = _t->droppedLines(); break;
        default: break;
        }
    }
    if (_c == QMetaObject::WriteProperty) {
        void *_v = _a[0];
        switch (_id) {
        case 0: _t->setCommand(*reinterpret_cast<QStringList*>(_v)); break;
        case 1: _t->setActive(*reinterpret_cast<bool*>(_v)); break;
        default: break;
        }
    }
}

const QMetaObject *WmStream::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *WmStream::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN8WmStreamE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int WmStream::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 9)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 9;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 9)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 9;
    }
    if (_c == QMetaObject::ReadProperty || _c == QMetaObject::WriteProperty
            || _c == QMetaObject::ResetProperty || _c == QMetaObject::BindableProperty
            || _c == QMetaObject::RegisterPropertyMetaType) {
        qt_static_metacall(this, _c, _id, _a);
        _id -= 5;
    }
    return _id;
}

// SIGNAL 0
void WmStream::parsed(const QVariantMap & _t1)
{
    QMetaObject::activate<void>(this, &staticMetaObject, 0, nullptr, _t1);
}

// SIGNAL 1
void WmStream::commandChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 1, nullptr);
}

// SIGNAL 2
void WmStream::activeChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 2, nullptr);
}

// SIGNAL 3
void WmStream::runningChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 3, nullptr);
}

// SIGNAL 4
void WmStream::restartsChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 4, nullptr);
}

// SIGNAL 5
void WmStream::droppedLinesChanged()
{
    QMetaObject::activate(this, &staticMetaObject, 5, nullptr);
}
QT_WARNING_POP
