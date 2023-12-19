# NOTICE:
#
# Application name defined in TARGET has a corresponding QML filename.
# If name defined in TARGET is changed, the following needs to be done
# to match new name:
#   - corresponding QML filename must be changed
#   - desktop icon filename must be changed
#   - desktop filename must be changed
#   - icon definition filename in desktop file must be changed
#   - translation filenames have to be changed

# The name of your application
TARGET = harbour-smartunlock

QT += dbus network
QT -= gui

CONFIG += sailfishapp
CONFIG += link_pkgconfig

DEFINES += "APPVERSION=\\\"$${SPECVERSION}\\\""
PKGCONFIG += mlite5

SOURCES += src/harbour-smartunlock.cpp \
    src/eventhandler.cpp

systemd_services.path = /usr/lib/systemd/user/
systemd_services.files = harbour-smartunlock.service

DISTFILES += rpm/harbour-smartunlock.spec \
    harbour-smartunlock.service \
    settings/SmartUnlockAppSettings.qml \
    settings/harbour-smartunlock.json \
    translations/*.ts \

INSTALLS += target \
            systemd_services

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172

# to disable building translations every time, comment out the
# following CONFIG line
CONFIG += sailfishapp_i18n

# German translation is enabled as an example. If you aren't
# planning to localize your app, remember to comment out the
# following TRANSLATIONS line. And also do not forget to
# modify the localized app name in the the .desktop file.
TRANSLATIONS += translations/harbour-smartunlock-de.ts

HEADERS += \
    src/eventhandler.h

# Settings
settings_json.files = $$PWD/settings/harbour-smartunlock.json
settings_json.path = /usr/share/jolla-settings/entries/
INSTALLS += settings_json

settings_qml.files = $$PWD/settings/*.qml
settings_qml.path = /usr/share/$${TARGET}/settings/
INSTALLS += settings_qml
