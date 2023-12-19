/*
 * (C) 2014 Kimmo Lindholm <kimmo.lindholm@gmail.com> Kimmoli
 *
 * Main, Daemon functions
 *
 */

#include <fcntl.h>
#include <signal.h>
#include <sys/stat.h>
#include <unistd.h>

#include <QtCore/QCoreApplication>
#include <QDBusConnection>
#include <QDBusError>
#include <QDBusInterface>

#include <QDebug>

#include "eventhandler.h"

static void daemonize();
static void signalHandler(int sig);

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);

    daemonize();

    setlinebuf(stdout);
    setlinebuf(stderr);

    printf("Starting taskswitcher daemon version %s\n", APPVERSION);

    /* Check that we can connect to dbus systemBus and sessionBus */

    QDBusConnection dbusSystemBus = QDBusConnection::systemBus();
    if (!dbusSystemBus.isConnected())
    {
        printf("Cannot connect to the D-Bus systemBus\n%s\n",
               qPrintable(dbusSystemBus.lastError().message()));
        sleep(3);
        exit(EXIT_FAILURE);
    }
    printf("Connected to D-Bus systembus\n");

    EventHandler eventHandler;
    return app.exec();
}

static void daemonize()
{
    /* Change the file mode mask */
    umask(0);

    /* Change the current working directory */
    if ((chdir("/tmp")) < 0)
        exit(EXIT_FAILURE);

    /* register signals to monitor / ignore */
    signal(SIGCHLD,SIG_IGN); /* ignore child */
    signal(SIGTSTP,SIG_IGN); /* ignore tty signals */
    signal(SIGTTOU,SIG_IGN);
    signal(SIGTTIN,SIG_IGN);
    signal(SIGHUP,signalHandler); /* catch hangup signal */
    signal(SIGTERM,signalHandler); /* catch kill signal */
}


static void signalHandler(int sig) /* signal handler function */
{
    switch(sig)
    {
    case SIGHUP:
        printf("Received signal SIGHUP\n");
        break;

    case SIGTERM:
        printf("Received signal SIGTERM\n");
        QCoreApplication::quit();
        break;
    }
}
