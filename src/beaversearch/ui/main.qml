import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "components"

ApplicationWindow {
    id: window
    width: 1600
    height: 900
    minimumWidth: 1180
    minimumHeight: 720
    visible: true
    title: "BeaverSearch"
    color: "#0B0F11"

    property int currentPage: 0
    property color accent: "#F4A746"
    property color textPrimary: "#F1F3F4"
    property color textMuted: "#8F9AA1"

    Connections {
        target: appController
        function onToastRequested(kind, message) {
            toast.text = message
            toast.opacity = 1
            toastTimer.restart()
        }
    }

    Timer { id: toastTimer; interval: 2800; onTriggered: toast.opacity = 0 }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.preferredWidth: 246
            Layout.fillHeight: true
            color: "#0D1113"
            border.color: "#1E2529"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 150
                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        Image {
                            anchors.horizontalCenter: parent.horizontalCenter
                            source: Qt.resolvedUrl("../assets/Brand/beaver_logo.png")
                            width: 86; height: 86; fillMode: Image.PreserveAspectFit
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "BeaverSearch"; color: accent; font.pixelSize: 25; font.bold: true }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "ИГРОКИ ИМЕЮТ ЦЕННОСТЬ"; color: textMuted; font.pixelSize: 10 }
                    }
                }

                Repeater {
                    model: ["Мониторинг", "Серверы", "Результаты", "Диагностика", "Настройки"]
                    delegate: Button {
                        required property int index
                        required property string modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 54
                        text: modelData
                        onClicked: currentPage = index
                        contentItem: Text {
                            text: parent.text
                            color: currentPage === index ? "#FFFFFF" : "#B7C0C5"
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 18
                            font.pixelSize: 15
                        }
                        background: Rectangle {
                            radius: 10
                            color: currentPage === index ? "#33291F" : parent.hovered ? "#151B1E" : "transparent"
                            border.color: currentPage === index ? "#6A4C2D" : "transparent"
                            Rectangle { visible: currentPage === index; width: 3; radius: 2; color: accent; anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
                Image {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 250
                    source: Qt.resolvedUrl("../assets/Sidebar/beaver_scene.png")
                    fillMode: Image.PreserveAspectCrop
                    opacity: 0.72
                }
                Text { text: "БОЛЬШЕ\nЧЕМ ПОИСК"; color: textMuted; font.pixelSize: 13; lineHeight: 1.5 }
                Text { text: "v0.1.0"; color: "#687279"; font.pixelSize: 11 }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: ["Мониторинг серверов", "Управление серверами", "Найденные результаты", "Диагностика", "Настройки"][currentPage]
                        color: textPrimary
                        font.pixelSize: 30
                        font.weight: Font.DemiBold
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        radius: 18; height: 36; width: 150
                        color: appController.monitoring ? "#0B2B21" : "#241D16"
                        border.color: appController.monitoring ? "#167A55" : "#654629"
                        Text { anchors.centerIn: parent; text: appController.monitoring ? "● Monitoring ON" : "○ Monitoring OFF"; color: appController.monitoring ? "#58D99C" : "#D9A45C"; font.pixelSize: 12 }
                    }
                }

                StackLayout {
                    currentIndex: currentPage
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Item {
                        ColumnLayout {
                            anchors.fill: parent; spacing: 14
                            RowLayout {
                                Layout.fillWidth: true; spacing: 12
                                Repeater {
                                    model: [
                                        {label:"Серверов", value:appController.servers.length},
                                        {label:"Проверено сегодня", value:appController.checkedToday},
                                        {label:"Совпадений", value:appController.matchedSession},
                                        {label:"Результатов", value:appController.results.length}
                                    ]
                                    delegate: Panel {
                                        required property var modelData
                                        Layout.fillWidth: true; Layout.preferredHeight: 112
                                        Column { anchors.centerIn: parent; spacing: 8
                                            Text { text: modelData.label; color: textMuted; font.pixelSize: 13 }
                                            Text { text: modelData.value; color: textPrimary; font.pixelSize: 28; font.bold: true }
                                        }
                                    }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 14
                                Panel {
                                    Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1.2
                                    ColumnLayout { anchors.fill: parent; anchors.margins: 18; spacing: 10
                                        RowLayout { Layout.fillWidth: true
                                            Text { text: "Отслеживаемые серверы"; color: textPrimary; font.pixelSize: 18; font.bold: true }
                                            Item { Layout.fillWidth: true }
                                            AccentButton { text: appController.monitoring ? "Остановить" : "Запустить"; onClicked: appController.toggleMonitoring() }
                                        }
                                        ListView {
                                            Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 1
                                            model: appController.servers
                                            delegate: Rectangle {
                                                required property var modelData
                                                width: ListView.view.width; height: 58; color: index % 2 ? "#0F1417" : "#11171A"
                                                RowLayout { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                                                    Text { text: modelData.address; color: textPrimary; Layout.preferredWidth: 180 }
                                                    Text { text: modelData.name; color: "#CCD3D7"; Layout.fillWidth: true; elide: Text.ElideRight }
                                                    Text { text: modelData.map; color: textMuted; Layout.preferredWidth: 120 }
                                                    Text { text: modelData.players; color: textMuted; Layout.preferredWidth: 85 }
                                                    Text { text: modelData.ping; color: modelData.online ? "#62D79D" : "#E66C62"; Layout.preferredWidth: 70 }
                                                }
                                            }
                                        }
                                    }
                                }
                                Panel {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    ColumnLayout { anchors.fill: parent; anchors.margins: 18; spacing: 12
                                        Text { text: "Фильтры поиска"; color: textPrimary; font.pixelSize: 18; font.bold: true }
                                        Repeater {
                                            model: [
                                                {name:"CS2", range:"3 500 – 30 000 ₽", img:"../assets/Games/CS2.jpg"},
                                                {name:"Dota 2", range:"1 000 – 5 000 ₽", img:"../assets/Games/Dota2.jpg"},
                                                {name:"Rust", range:"4 000 – 10 000 ₽", img:"../assets/Games/Rust.jpg"}
                                            ]
                                            delegate: Rectangle {
                                                required property var modelData
                                                Layout.fillWidth: true; Layout.preferredHeight: 112; radius: 12; color: "#151B1E"; border.color: "#2B3337"
                                                RowLayout { anchors.fill: parent; anchors.margins: 12; spacing: 14
                                                    Image { source: Qt.resolvedUrl(modelData.img); Layout.preferredWidth: 72; Layout.preferredHeight: 72; fillMode: Image.PreserveAspectCrop }
                                                    Column { spacing: 7
                                                        Text { text: modelData.name; color: textPrimary; font.pixelSize: 18; font.bold: true }
                                                        Text { text: "Стоимость инвентаря"; color: textMuted; font.pixelSize: 12 }
                                                        Text { text: modelData.range; color: "#F4B55F"; font.pixelSize: 17; font.bold: true }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        ColumnLayout { anchors.fill: parent; spacing: 14
                            Panel { Layout.fillWidth: true; Layout.preferredHeight: 100
                                RowLayout { anchors.fill: parent; anchors.margins: 16; spacing: 12
                                    TextField { id: addressField; Layout.fillWidth: true; placeholderText: "IP:PORT, например 212.22.93.14:27015"; color: textPrimary; placeholderTextColor: "#687279" }
                                    TextField { id: nameField; Layout.preferredWidth: 280; placeholderText: "Название (необязательно)"; color: textPrimary; placeholderTextColor: "#687279" }
                                    AccentButton { text: "+ Добавить сервер"; onClicked: { appController.addServer(addressField.text, nameField.text); addressField.clear(); nameField.clear(); } }
                                }
                            }
                            Panel { Layout.fillWidth: true; Layout.fillHeight: true
                                ListView { anchors.fill: parent; anchors.margins: 14; clip: true; model: appController.servers; spacing: 4
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: ListView.view.width; height: 68; radius: 8; color: "#11171A"; border.color: "#242D31"
                                        RowLayout { anchors.fill: parent; anchors.margins: 12
                                            Text { text: modelData.address; color: textPrimary; Layout.preferredWidth: 220 }
                                            Text { text: modelData.name; color: "#C7CED2"; Layout.fillWidth: true }
                                            Text { text: modelData.map; color: textMuted; Layout.preferredWidth: 120 }
                                            Text { text: modelData.players; color: textMuted; Layout.preferredWidth: 90 }
                                            Button { text: "Удалить"; onClicked: appController.removeServer(modelData.id) }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        ColumnLayout { anchors.fill: parent; spacing: 14
                            Panel { Layout.fillWidth: true; Layout.preferredHeight: 72
                                RowLayout { anchors.fill: parent; anchors.margins: 12
                                    TextField { Layout.fillWidth: true; placeholderText: "Поиск по нику или SteamID..."; color: textPrimary; placeholderTextColor: "#687279" }
                                    AccentButton { text: "Экспорт в Excel"; onClicked: exportDialog.open() }
                                }
                            }
                            Panel { Layout.fillWidth: true; Layout.fillHeight: true
                                ListView { anchors.fill: parent; anchors.margins: 10; clip: true; model: appController.results; spacing: 2
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: ListView.view.width; height: 72; radius: 8; color: index % 2 ? "#0F1417" : "#12181B"
                                        RowLayout { anchors.fill: parent; anchors.margins: 10
                                            Text { text: modelData.nickname; color: textPrimary; Layout.preferredWidth: 180; elide: Text.ElideRight }
                                            Text { text: modelData.steam_id64; color: textMuted; Layout.preferredWidth: 160 }
                                            Text { text: (modelData.cs2_rub ?? "—") + (modelData.cs2_rub ? " ₽" : ""); color: "#E3AB5D"; Layout.preferredWidth: 105 }
                                            Text { text: (modelData.dota2_rub ?? "—") + (modelData.dota2_rub ? " ₽" : ""); color: "#E3AB5D"; Layout.preferredWidth: 105 }
                                            Text { text: (modelData.rust_rub ?? "—") + (modelData.rust_rub ? " ₽" : ""); color: "#E3AB5D"; Layout.preferredWidth: 105 }
                                            Text { text: modelData.total_rub + " ₽"; color: accent; font.bold: true; Layout.preferredWidth: 120 }
                                            Text { text: modelData.server_address; color: textMuted; Layout.fillWidth: true }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        GridLayout { anchors.fill: parent; columns: 3; rowSpacing: 12; columnSpacing: 12
                            Repeater {
                                model: ["A2S доступ", "Resolver SteamID", "Steam Community", "Steam Market", "Кэш системы", "SQLite"]
                                delegate: Panel {
                                    required property string modelData
                                    Layout.fillWidth: true; Layout.preferredHeight: 120
                                    Column { anchors.centerIn: parent; spacing: 10
                                        Text { text: modelData; color: textPrimary; font.pixelSize: 16; font.bold: true }
                                        Text { text: "● Готов"; color: "#58D99C"; font.pixelSize: 13 }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        RowLayout { anchors.fill: parent; spacing: 14
                            Panel {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                ColumnLayout { anchors.fill: parent; anchors.margins: 18; spacing: 14
                                    Text { text: "Общие"; color: textPrimary; font.pixelSize: 19; font.bold: true }
                                    ComboBox { model: ["Русский", "English"]; Layout.fillWidth: true; onActivated: appController.setLanguage(currentIndex === 1 ? "en" : "ru") }
                                    Text { text: "Тема оформления"; color: textMuted }
                                    RowLayout {
                                        Button { text: "Тёмная"; onClicked: appController.requestTheme("dark") }
                                        Button { text: "Системная"; onClicked: appController.requestTheme("system") }
                                        Button { text: "Светлая"; onClicked: appController.requestTheme("light") }
                                    }
                                    Text { text: "Steam Web API key (бесплатный, нужен для точного сопоставления SteamID)"; color: textMuted; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                    TextField { id: keyField; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: "Вставьте ключ"; color: textPrimary; placeholderTextColor: "#687279" }
                                    AccentButton { text: "Сохранить ключ"; onClicked: appController.saveSteamApiKey(keyField.text) }
                                    Item { Layout.fillHeight: true }
                                }
                            }
                            Panel {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                ColumnLayout { anchors.fill: parent; anchors.margins: 18; spacing: 14
                                    Text { text: "Фильтры по умолчанию"; color: textPrimary; font.pixelSize: 19; font.bold: true }
                                    Text { text: "CS2"; color: textPrimary }
                                    RowLayout { TextField { id: cs2min; text: "3500"; color: textPrimary }; TextField { id: cs2max; text: "30000"; color: textPrimary } }
                                    Text { text: "Dota 2"; color: textPrimary }
                                    RowLayout { TextField { id: dotamin; text: "1000"; color: textPrimary }; TextField { id: dotamax; text: "5000"; color: textPrimary } }
                                    Text { text: "Rust"; color: textPrimary }
                                    RowLayout { TextField { id: rustmin; text: "4000"; color: textPrimary }; TextField { id: rustmax; text: "10000"; color: textPrimary } }
                                    AccentButton { text: "Сохранить"; onClicked: appController.saveFilters(parseInt(cs2min.text), parseInt(cs2max.text), parseInt(dotamin.text), parseInt(dotamax.text), parseInt(rustmin.text), parseInt(rustmax.text)) }
                                    Item { Layout.fillHeight: true }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: toast
        property alias text: toastText.text
        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 28
        width: Math.min(480, toastText.implicitWidth + 44); height: 52; radius: 10
        color: "#1A2226"; border.color: "#5B4430"; opacity: 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Text { id: toastText; anchors.centerIn: parent; color: textPrimary; font.pixelSize: 13 }
    }

    FileDialog {
        id: exportDialog
        title: "Экспорт результатов"
        fileMode: FileDialog.SaveFile
        nameFilters: ["Excel (*.xlsx)"]
        defaultSuffix: "xlsx"
        onAccepted: appController.exportResults(selectedFile.toString().replace("file:///", ""), "xlsx")
    }
}
