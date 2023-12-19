#include "eventhandler.h"
#include <QtDBus/QDBusInterface>
#include <QtDBus/QDBusReply>

#include <QDebug>
#include <mlite5/MGConfItem>

EventHandler::EventHandler(QObject *parent) : QObject(parent)
{
    const QString serviceName("com.nokia.mce");
    const QString servicePath("/com/nokia/mce/signal");
    const QString serviceInterface("com.nokia.mce.signal");

    QDBusInterface *iface = new QDBusInterface(serviceName, servicePath, serviceInterface, QDBusConnection::systemBus(), this);
    if(iface->isValid()) {
        connect(iface, SIGNAL(display_status_ind(QString)), this, SLOT(displayStatus(QString)));
    }
}

void EventHandler::displayStatus(const QString &status)
{
    qDebug() << Q_FUNC_INFO << status;

    MGConfItem devicesConv("/uk/co/piggz/smartunlock/devices");
    QStringList devices = devicesConv.value().toString().split(";", QString::SkipEmptyParts);
    qDebug() << devices;

    if (status == "on") {
        bool deviceConnected = false;

        for (auto device : devices) {
            QDBusInterface bluezInterface("org.bluez", "/org/bluez/" + device, "org.bluez.Device1", QDBusConnection::systemBus() );
            if (bluezInterface.isValid()) {
                if (bluezInterface.property("Connected").toBool() == true) {
                    deviceConnected = true;
                    break;
                }
            }
        }

        if (deviceConnected) {
            qDebug() << "A connected device was found";
            //Send the unlock command
            QDBusInterface deviceLockInterface("org.nemomobile.devicelock", "/devicelock", "org.nemomobile.lipstick.devicelock", QDBusConnection::systemBus() );
            if (deviceLockInterface.isValid()) {
                QDBusReply<void> reply = deviceLockInterface.call("setState", 0);
                if (reply.isValid()) {
                    qDebug() << "Reply was ok";
                    return;
                }

                qWarning("Call failed: %s\n", qPrintable(reply.error().message()));
            }
        } else {
            qDebug() << "No connected device was found";
        }
    }
}
