import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.DBus 2.0
import QtQml 2.2
import Nemo.Configuration 1.0
import Sailfish.Pickers 1.0
import org.kde.bluezqt 1.0 as BluezQt

Page {
    id: root

    property bool userserviceRunning
    property bool smartUnlockUserAutostart
    property bool ready: false

    property QtObject adapter: _bluetoothManager ? _bluetoothManager.usableAdapter : null
    property QtObject _bluetoothManager : BluezQt.Manager

    property var devices: []


    ConfigurationValue {
        id:cfgDevices
        key: "/uk/co/piggz/smartunlock/devices"
        defaultValue: ""
    }

    BluezQt.DevicesModel {
        id: devicesModel
    }

    Timer {
        id: delayedATimer
        repeat: false
        running: true
        interval: 100
        onTriggered: {
            console.log("Delayed Manager operational:", _bluetoothManager.operational, _bluetoothManager.usableAdapter);
            if (typeof(devicesModel.filters) == 'number') {
                devicesModel.filters = BluezQt.DevicesModelPrivate.PairedDevices;
            }
        }
    }

    Component.onCompleted: {
        console.log("Manager operational:", _bluetoothManager.operational, _bluetoothManager.usableAdapter);
        devices = cfgDevices.value.split(";");
        ready = true;
    }

    DBusInterface {
        id: smartUnlockUserService

        bus: DBus.SessionBus
        service: "org.freedesktop.systemd1"
        iface: "org.freedesktop.systemd1.Unit"
        signalsEnabled: true

        function updateProperties() {
            var status = smartUnlockUserService.getProperty("ActiveState")
            smartUnlockSystemdStatus.status = status
            if (path !== "") {
                root.userserviceRunning = status === "active"
            } else {
                root.userserviceRunning = false
            }
        }
        onPathChanged: updateProperties()
    }

    DBusInterface {
        id: manager

        bus: DBus.SessionBus
        service: "org.freedesktop.systemd1"
        path: "/org/freedesktop/systemd1"
        iface: "org.freedesktop.systemd1.Manager"
        signalsEnabled: true

        signal unitNew(string name)
        onUnitNew: {
            if ( name == "harbour-smartunlock.service" ) {
                pathUpdateTimer.start()
            }
        }

        signal unitRemoved(string name)
        onUnitRemoved: {
            if ( name == "harbour-smartunlock.service" ) {
                smartUnlockUserService.path = ""
                pathUpdateTimer.stop()
            }
        }

        signal unitFilesChanged()
        onUnitFilesChanged: {
            updateAutostart()
        }

        Component.onCompleted: {
            updatePath()
            updateAutostart()
        }
        function updateAutostart() {
            manager.typedCall("GetUnitFileState", [{"type": "s", "value": "harbour-smartunlock.service"}],
                              function(state) {
                                  console.log(state)
                                  if (state !== "disabled" && state !== "invalid") {
                                      root.smartUnlockUserAutostart = true
                                  } else {
                                      root.smartUnlockUserAutostart = false
                                  }
                              },
                              function() {
                                  root.smartUnlockUserAutostart = false
                              })
        }

        function setAutostart(isAutostart) {
            if(isAutostart)
                enableSmartUnlockUnit()
            else
                disableSmartUnlockUnit()
        }

        function enableSmartUnlockUnit() {
            manager.typedCall( "EnableUnitFiles",[{"type":"as","value":["harbour-smartunlock.service"]},
                                                  {"type":"b","value":false},
                                                  {"type":"b","value":false}],
                              function(carries_install_info,changes){
                                  root.smartUnlockUserAutostart = true
                                  console.log(changes)
                              },
                              function() {
                                  console.log("Enabling user error")
                              }
                              )
        }

        function disableSmartUnlockUnit() {
            manager.typedCall( "DisableUnitFiles",[{"type":"as","value":["harbour-smartunlock.service"]},
                                                   {"type":"b","value":false}],
                              function(changes){
                                  root.smartUnlockUserAutostart = false
                                  console.log(changes)
                              },
                              function() {
                                  console.log("Disabling user error")
                              }
                              )
        }

        function startSmartUnlockUnit() {
            manager.typedCall( "StartUnit",[{"type":"s","value":"harbour-smartunlock.service"},
                                            {"type":"s","value":"fail"}],
                              function(job) {
                                  console.log("job started - ", job)
                                  smartUnlockUserService.updateProperties()
                                  runningUpdateTimer.start()
                              },
                              function() {
                                  console.log("job started user failure")
                              })
        }

        function stopSmartUnlockUnit() {
            manager.typedCall( "StopUnit",[{"type":"s","value":"harbour-smartunlock.service"},
                                           {"type":"s","value":"replace"}],
                              function(job) {
                                  console.log("job stopped - ", job)
                                  smartUnlockUserService.updateProperties()
                              },
                              function() {
                                  console.log("job stopped user failure")
                              })
        }

        function updatePath() {
            manager.typedCall("GetUnit", [{ "type": "s", "value": "harbour-smartunlock.service"}], function(unit) {
                smartUnlockUserService.path = unit
            }, function() {
                smartUnlockUserService.path = ""
            })
        }
    }

    Timer {
        // starting and stopping can result in lots of property changes
        id: runningUpdateTimer
        interval: 1000
        repeat: true
        onTriggered:{
            smartUnlockUserService.updateProperties()
        }
    }

    Timer {
        // stopping service can result in unit appearing and disappering, for some reason.
        id: pathUpdateTimer
        interval: 200
        onTriggered: manager.updatePath()
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: content.height + Theme.paddingMedium
        width: parent.width

        Column {
            id:content
            width:parent.width

            PageHeader {
                id: header
                title: qsTr("Smart Unlock")
            }

            TextSwitch {
                id: autostart
                //% "Start SmartUnlock on bootup"
                text: qsTr("Start SmartUnlock on bootup")
                description: qsTr("When this is off, you won't get SmartUnlock on boot")
                enabled: root.ready
                automaticCheck: false
                checked: root.smartUnlockUserAutostart
                onClicked: {
                    manager.setAutostart(!checked)
                }
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2*Theme.horizontalPageMargin
                text: qsTr("Start/stop SmartUnlock daemon.")
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
            }

            Label {
                id: smartUnlockSystemdStatus
                property string status: "invalid"
                x: Theme.horizontalPageMargin
                width: parent.width - 2*Theme.horizontalPageMargin
                text: qsTr("SmartUnlock current status") + " - " + status
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                color: Theme.secondaryHighlightColor
            }

            Item {
                width: 1
                height: Theme.paddingLarge
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.paddingLarge

                Button {
                    enabled: root.ready && (!root.userserviceRunning)
                    text: qsTr("Start daemon")
                    width: (content.width - 2*Theme.horizontalPageMargin - parent.spacing) / 2
                    onClicked: manager.startSmartUnlockUnit()
                }

                Button {
                    enabled: root.ready && (root.userserviceRunning)
                    //% "Stop"
                    text: qsTr("Stop daemon")
                    width: (content.width - 2*Theme.horizontalPageMargin - parent.spacing) / 2
                    onClicked: manager.stopSmartUnlockUnit()
                }
            }

            Item {
                width: 1
                height: Theme.paddingLarge
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2*Theme.horizontalPageMargin
                text: qsTr("Select devices which unlock the phone")
            }

            SilicaListView {
                x: Theme.horizontalPageMargin
                width: parent.width - 2*Theme.horizontalPageMargin
                height: root.height / 2
                model: devicesModel
                delegate: BackgroundItem {
                    width: ListView.view.width
                    contentHeight: Theme.itemSizeSmall
                    property bool selected: {
                        var devicePath = "hci0/" + "dev_" + Address.replace(/:/g, '_');
                        return devices.indexOf(devicePath) >= 0;
                    }

                    highlighted: selected;

                    onClicked: {
                        selected = !selected
                        console.log("clicked ", Name, FriendlyName, AdapterName, AdapterAddress, RemoteName)
                        var devicePath = "hci0/" + "dev_" + Address.replace(/:/g, '_');

                        if (selected) {
                            devices.push(devicePath);
                        } else {
                            var idx = devices.indexOf(devicePath);
                            if (idx >= 0) {
                                devices.splice(idx, 1);
                            }
                        }
                        console.log("Current devices:", devices);
                        cfgDevices.value = devices.join(";");
                    }

                    Label {
                        text: FriendlyName
                        anchors.centerIn: parent
                        color: highlighted ? Theme.highlightColor : Theme.primaryColor
                    }
                }
            }
        }
    }
}
