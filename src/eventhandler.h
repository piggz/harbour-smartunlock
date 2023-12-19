#ifndef EVENTHANDLER_H
#define EVENTHANDLER_H

#include <QObject>

class EventHandler : public QObject
{
    Q_OBJECT
public:
    explicit EventHandler(QObject *parent = nullptr);

signals:


private:
    Q_INVOKABLE void displayStatus(const QString & status);
};

#endif // EVENTHANDLER_H
