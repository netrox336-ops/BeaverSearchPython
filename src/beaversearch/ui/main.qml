import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Window

ApplicationWindow {
    id: window
    width: 1672
    height: 941
    minimumWidth: 1280
    minimumHeight: 760
    visible: true
    title: "BeaverSearch"
    color: "#0A0E10"
    flags: Qt.Window | Qt.FramelessWindowHint

    property int currentPage: 0
    property int selectedResultIndex: appController.results.length > 0 ? 0 : -1
    property bool english: appController.language === "en"
    property color accent: "#F2A84B"
    property color accentStrong: "#FFB65A"
    property color bg: "#0B0F11"
    property color sidebarBg: "#0D1113"
    property color panel: "#121719"
    property color panelAlt: "#151B1E"
    property color panelSoft: "#101517"
    property color line: "#2A3236"
    property color lineSoft: "#20282C"
    property color textPrimary: "#F0F2F3"
    property color textSecondary: "#C3CBD0"
    property color textMuted: "#7F8A91"
    property color green: "#35D48B"
    property color red: "#F05D55"
    property color blue: "#57A9FF"
    property color warning: "#F3B450"
    property string clockText: ""
    property string dateText: ""
    property string resultSearch: ""
    property string serverSearch: ""
    property var selectedResult: selectedResultIndex >= 0 && selectedResultIndex < appController.results.length ? appController.results[selectedResultIndex] : null

    function tr(ru, en) { return english ? en : ru }
    function money(value) {
        if (value === null || value === undefined || value === "") return "—"
        var n = Number(value)
        if (isNaN(n)) return "—"
        return n.toLocaleString(Qt.locale(english ? "en_US" : "ru_RU"), "f", 0) + " ₽"
    }
    function shortMoney(value) {
        if (value === null || value === undefined) return "—"
        return money(value)
    }
    function formatRange(a, b) { return money(a).replace(" ₽", "") + " – " + money(b) }
    function resultContains(row, needle) {
        if (!needle || needle.trim() === "") return true
        var q = needle.toLowerCase()
        return String(row.nickname || "").toLowerCase().indexOf(q) >= 0 || String(row.steam_id64 || "").toLowerCase().indexOf(q) >= 0
    }
    function matched(row, game) {
        return String(row && row.matched_games ? row.matched_games : "").indexOf(game) >= 0
    }
    function averageResult() {
        if (!appController.results.length) return 0
        var total = 0
        for (var i = 0; i < appController.results.length; ++i) total += Number(appController.results[i].total_rub || 0)
        return Math.round(total / appController.results.length)
    }
    function highestResult() {
        var high = 0
        for (var i = 0; i < appController.results.length; ++i) high = Math.max(high, Number(appController.results[i].total_rub || 0))
        return high
    }
    function refreshClock() {
        var d = new Date()
        clockText = Qt.formatTime(d, "hh:mm")
        dateText = Qt.formatDate(d, english ? "dd MMM yyyy" : "dd MMMM yyyy")
    }

    Component.onCompleted: refreshClock()
    Timer { interval: 30000; running: true; repeat: true; onTriggered: refreshClock() }

    Connections {
        target: appController
        function onToastRequested(kind, message) {
            toast.kind = kind
            toast.message = message
            toast.opacity = 1
            toast.y = window.height - toast.height - 26
            toastTimer.restart()
        }
        function onResultsChanged() {
            if (appController.results.length === 0) selectedResultIndex = -1
            else if (selectedResultIndex < 0 || selectedResultIndex >= appController.results.length) selectedResultIndex = 0
        }
    }

    component Card: Rectangle {
        radius: 10
        color: panel
        border.color: line
        border.width: 1
    }

    component SoftCard: Rectangle {
        radius: 9
        color: panelSoft
        border.color: lineSoft
        border.width: 1
    }

    component Divider: Rectangle {
        implicitHeight: 1
        color: lineSoft
    }

    component PrimaryButton: Rectangle {
        id: rootButton
        property string text: ""
        property string icon: ""
        property bool enabled: true
        property int buttonHeight: 48
        signal clicked()
        implicitHeight: buttonHeight
        implicitWidth: Math.max(120, labelRow.implicitWidth + 34)
        radius: 8
        color: !enabled ? "#3B3329" : mouse.pressed ? "#E69B42" : mouse.containsMouse ? accentStrong : accent
        border.color: !enabled ? "#514839" : "#FFBF69"
        opacity: enabled ? 1 : 0.55
        scale: mouse.pressed && enabled ? 0.985 : 1
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 90 } }
        Row {
            id: labelRow
            anchors.centerIn: parent
            spacing: 9
            Text { visible: rootButton.icon !== ""; text: rootButton.icon; color: "#1B1711"; font.pixelSize: 20; font.bold: true }
            Text { text: rootButton.text; color: "#1B1711"; font.pixelSize: 14; font.weight: Font.DemiBold }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (rootButton.enabled) rootButton.clicked()
        }
    }

    component GhostButton: Rectangle {
        id: ghost
        property string text: ""
        property string icon: ""
        property color foreground: textSecondary
        property int buttonHeight: 44
        signal clicked()
        implicitHeight: buttonHeight
        implicitWidth: Math.max(104, ghostRow.implicitWidth + 30)
        radius: 8
        color: ghostMouse.pressed ? "#20272A" : ghostMouse.containsMouse ? "#191F22" : "#111619"
        border.color: ghostMouse.containsMouse ? "#3B464C" : line
        Behavior on color { ColorAnimation { duration: 120 } }
        Row {
            id: ghostRow
            anchors.centerIn: parent
            spacing: 8
            Text { visible: ghost.icon !== ""; text: ghost.icon; color: ghost.foreground; font.pixelSize: 18 }
            Text { text: ghost.text; color: ghost.foreground; font.pixelSize: 13; font.weight: Font.Medium }
        }
        MouseArea { id: ghostMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ghost.clicked() }
    }

    component IconButton: Rectangle {
        id: ib
        property string icon: "⋮"
        property color hoverColor: "#20272B"
        signal clicked()
        implicitWidth: 36
        implicitHeight: 36
        radius: 7
        color: ibMouse.containsMouse ? hoverColor : "transparent"
        Text { anchors.centerIn: parent; text: ib.icon; color: textSecondary; font.pixelSize: 20 }
        MouseArea { id: ibMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ib.clicked() }
    }

    component Field: TextField {
        id: fld
        property string leading: ""
        implicitHeight: 44
        color: textPrimary
        placeholderTextColor: "#667178"
        selectionColor: accent
        selectedTextColor: "#17120C"
        font.family: "Segoe UI"
        font.pixelSize: 13
        leftPadding: leading === "" ? 14 : 38
        rightPadding: 12
        background: Rectangle {
            radius: 8
            color: "#0E1315"
            border.width: 1
            border.color: fld.activeFocus ? "#8E6738" : fld.hovered ? "#3B454A" : line
        }
        Text {
            visible: fld.leading !== ""
            text: fld.leading
            anchors.left: parent.left
            anchors.leftMargin: 13
            anchors.verticalCenter: parent.verticalCenter
            color: fld.activeFocus ? accent : textMuted
            font.pixelSize: 17
        }
    }

    component MiniField: TextField {
        id: mini
        implicitHeight: 38
        color: textPrimary
        placeholderTextColor: "#667178"
        selectionColor: accent
        font.family: "Segoe UI"
        font.pixelSize: 13
        leftPadding: 12
        rightPadding: 12
        background: Rectangle {
            radius: 7
            color: "#0E1315"
            border.color: mini.activeFocus ? "#8E6738" : line
        }
    }

    component ToggleSwitch: Item {
        id: sw
        property bool checked: true
        property string caption: ""
        signal toggled(bool checked)
        implicitWidth: caption === "" ? 42 : track.width + captionText.implicitWidth + 12
        implicitHeight: 26
        Rectangle {
            id: track
            width: 40
            height: 22
            radius: 11
            anchors.verticalCenter: parent.verticalCenter
            color: sw.checked ? accent : "#30383C"
            border.color: sw.checked ? "#F7BD72" : "#49545A"
            Rectangle {
                width: 16
                height: 16
                radius: 8
                y: 3
                x: sw.checked ? 21 : 3
                color: "#F7F8F8"
                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }
        }
        Text { id: captionText; anchors.left: track.right; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: sw.caption; color: textSecondary; font.pixelSize: 12 }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { sw.checked = !sw.checked; sw.toggled(sw.checked) } }
    }

    component StatusDot: Row {
        property string text: ""
        property color dotColor: green
        spacing: 7
        Rectangle { width: 9; height: 9; radius: 5; color: parent.dotColor; anchors.verticalCenter: parent.verticalCenter }
        Text { text: parent.text; color: parent.dotColor; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
    }

    component SectionHeader: Item {
        id: sh
        property string icon: ""
        property string title: ""
        property string subtitle: ""
        implicitHeight: subtitle === "" ? 56 : 68
        Rectangle { width: 4; height: 30; radius: 2; color: accent; anchors.left: parent.left; anchors.top: parent.top; anchors.topMargin: 2 }
        Text { text: sh.title; color: textPrimary; font.pixelSize: 30; font.weight: Font.DemiBold; anchors.left: parent.left; anchors.leftMargin: 27; anchors.top: parent.top }
        Text { visible: sh.subtitle !== ""; text: sh.subtitle; color: textMuted; font.pixelSize: 13; anchors.left: parent.left; anchors.leftMargin: 27; anchors.top: parent.top; anchors.topMargin: 39 }
    }

    component NavButton: Rectangle {
        id: nav
        property string icon: ""
        property string text: ""
        property bool selected: false
        signal clicked()
        implicitWidth: 226
        implicitHeight: 54
        radius: 8
        color: nav.selected ? "#34291F" : navMouse.containsMouse ? "#161C1F" : "transparent"
        border.color: nav.selected ? "#58432F" : "transparent"
        Rectangle { visible: nav.selected; width: 3; radius: 2; color: accent; anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom }
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 15
            Text { text: nav.icon; color: nav.selected ? accent : "#AEB8BD"; font.pixelSize: 23; width: 28; horizontalAlignment: Text.AlignHCenter }
            Text { text: nav.text; color: nav.selected ? "#F4F5F5" : "#BDC5C9"; font.pixelSize: 15; font.weight: nav.selected ? Font.DemiBold : Font.Normal; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { id: navMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: nav.clicked() }
        Behavior on color { ColorAnimation { duration: 130 } }
    }

    component StatCard: Card {
        id: stat
        property string icon: "●"
        property string label: ""
        property string value: "0"
        property string delta: ""
        property color iconColor: accent
        implicitHeight: 108
        RowLayout {
            anchors.fill: parent
            anchors.margins: 17
            spacing: 13
            Rectangle {
                Layout.preferredWidth: 54
                Layout.preferredHeight: 54
                radius: 10
                color: "#211D18"
                border.color: "#493824"
                Text { anchors.centerIn: parent; text: stat.icon; color: stat.iconColor; font.pixelSize: 25 }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5
                Text { text: stat.label; color: textMuted; font.pixelSize: 12 }
                RowLayout {
                    spacing: 9
                    Text { text: stat.value; color: textPrimary; font.pixelSize: 26; font.weight: Font.DemiBold }
                    Text { visible: stat.delta !== ""; text: stat.delta; color: green; font.pixelSize: 12; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignBottom }
                }
            }
        }
    }

    component GameBadge: Rectangle {
        id: gb
        property string game: "CS2"
        property string sourcePath: ""
        property bool active: true
        implicitWidth: game === "Dota 2" ? 82 : 66
        implicitHeight: 30
        radius: 6
        color: active ? "#161C1F" : "#111618"
        border.color: active ? "#3A4449" : "#252C30"
        Row {
            anchors.centerIn: parent
            spacing: 6
            Image { source: gb.sourcePath; width: 19; height: 19; fillMode: Image.PreserveAspectCrop; opacity: gb.active ? 1 : 0.45 }
            Text { text: gb.game; color: gb.active ? textPrimary : textMuted; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    component GameFilterCard: SoftCard {
        id: gf
        property string game: "CS2"
        property string imageSource: ""
        property int minimum: 0
        property int maximum: 0
        property bool enabled: true
        implicitHeight: 118
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 13
            spacing: 7
            RowLayout {
                Layout.fillWidth: true
                Image { source: gf.imageSource; Layout.preferredWidth: 34; Layout.preferredHeight: 34; fillMode: Image.PreserveAspectCrop }
                Text { text: gf.game; color: textPrimary; font.pixelSize: 16; font.weight: Font.DemiBold }
                Item { Layout.fillWidth: true }
            }
            Text { text: tr("Стоимость инвентаря", "Inventory value"); color: textMuted; font.pixelSize: 11 }
            Text { text: formatRange(gf.minimum, gf.maximum); color: "#F0B45E"; font.pixelSize: 17; font.weight: Font.DemiBold }
            ToggleSwitch { checked: gf.enabled; caption: tr("Включен", "Enabled") }
        }
    }

    component WindowButton: Rectangle {
        id: wb
        property string glyph: "—"
        property bool closeButton: false
        signal clicked()
        width: 46
        height: 34
        color: wbMouse.containsMouse ? (closeButton ? "#C42B1C" : "#22282B") : "transparent"
        Text { anchors.centerIn: parent; text: wb.glyph; color: "#E4E7E8"; font.pixelSize: closeButton ? 18 : 17 }
        MouseArea { id: wbMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: wb.clicked() }
    }

    Rectangle {
        anchors.fill: parent
        color: bg
        border.color: "#3A4348"
        border.width: 1
        radius: window.visibility === Window.Maximized ? 0 : 10
        clip: true

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                id: sidebar
                Layout.preferredWidth: 252
                Layout.fillHeight: true
                color: sidebarBg
                border.color: lineSoft

                Rectangle {
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    width: 1
                    color: "#252C30"
                }

                IconButton { icon: "☰"; anchors.left: parent.left; anchors.leftMargin: 10; anchors.top: parent.top; anchors.topMargin: 6; onClicked: appController.showMessage(tr("Компактное меню появится позже", "Compact menu is coming later")) }

                Image {
                    id: brandImage
                    anchors.top: parent.top
                    anchors.topMargin: 28
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 190
                    height: 142
                    fillMode: Image.PreserveAspectFit
                    source: "https://raw.githubusercontent.com/netrox336-ops/BeaverSearch/main/src/BeaverSearch/Assets/Brand/sidebar_brand_transparent.png"
                    cache: true
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.top: parent.top
                    anchors.topMargin: 184
                    spacing: 6
                    NavButton { width: parent.width; icon: "⌁"; text: tr("Мониторинг", "Monitoring"); selected: currentPage === 0; onClicked: currentPage = 0 }
                    NavButton { width: parent.width; icon: "▤"; text: tr("Серверы", "Servers"); selected: currentPage === 1; onClicked: currentPage = 1 }
                    NavButton { width: parent.width; icon: "▣"; text: tr("Результаты", "Results"); selected: currentPage === 2; onClicked: currentPage = 2 }
                    NavButton { width: parent.width; icon: "▥"; text: tr("Диагностика", "Diagnostics"); selected: currentPage === 3; onClicked: currentPage = 3 }
                    NavButton { width: parent.width; icon: "⚙"; text: tr("Настройки", "Settings"); selected: currentPage === 4; onClicked: currentPage = 4 }
                }

                Image {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 330
                    fillMode: Image.PreserveAspectCrop
                    source: "https://raw.githubusercontent.com/netrox336-ops/BeaverSearch/main/src/BeaverSearch/Assets/Sidebar/beaver_scene.png"
                    opacity: 0.68
                    cache: true
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 185
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#00101315" }
                        GradientStop { position: 1.0; color: "#F20D1113" }
                    }
                }
                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 28
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 18
                    spacing: 12
                    Text { text: tr("БОЛЬШЕ\nЧЕМ ПОИСК", "MORE THAN\nA SEARCH"); color: "#8A949A"; font.pixelSize: 12; lineHeight: 1.45 }
                    Text { text: "v0.2.0"; color: "#69737A"; font.pixelSize: 10 }
                }
            }

            Item {
                id: mainArea
                Layout.fillWidth: true
                Layout.fillHeight: true

                MouseArea {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: windowControls.left
                    height: 34
                    acceptedButtons: Qt.LeftButton
                    onPressed: window.startSystemMove()
                    onDoubleClicked: {
                        if (window.visibility === Window.Maximized) window.showNormal()
                        else window.showMaximized()
                    }
                }

                Row {
                    id: windowControls
                    anchors.top: parent.top
                    anchors.right: parent.right
                    WindowButton { glyph: "—"; onClicked: window.showMinimized() }
                    WindowButton { glyph: window.visibility === Window.Maximized ? "❐" : "□"; onClicked: window.visibility === Window.Maximized ? window.showNormal() : window.showMaximized() }
                    WindowButton { glyph: "×"; closeButton: true; onClicked: window.close() }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 21
                    anchors.rightMargin: 21
                    anchors.topMargin: 20
                    anchors.bottomMargin: 18
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 69
                        SectionHeader {
                            Layout.fillWidth: true
                            title: [tr("Мониторинг серверов", "Server monitoring"), tr("Управление серверами", "Server management"), tr("Найденные результаты", "Found results"), tr("Диагностика", "Diagnostics"), tr("Настройки", "Settings")][currentPage]
                            subtitle: [
                                tr("Отслеживание игроков в реальном времени на выбранных серверах", "Real-time player tracking on selected servers"),
                                tr("Настройка и управление серверами для отслеживания игроков. Добавьте до 20 серверов.", "Configure and manage servers. Add up to 20 servers."),
                                tr("Игроки, соответствующие заданным критериям, и стоимость их инвентарей", "Players matching your criteria and their inventory values"),
                                tr("Проверка соединений, диагностика сервисов и сопоставление SteamID", "Connection checks, service diagnostics and SteamID resolution"),
                                tr("Поведение приложения, провайдеры и внешний вид", "Application behavior, providers and appearance")
                            ][currentPage]
                        }

                        RowLayout {
                            visible: currentPage !== 4
                            spacing: 13
                            Rectangle {
                                visible: currentPage === 0 || currentPage === 2 || currentPage === 3
                                Layout.preferredWidth: 140
                                Layout.preferredHeight: 38
                                radius: 19
                                color: appController.monitoring ? "#0B2A20" : "#221C16"
                                border.color: appController.monitoring ? "#176C4D" : "#62462B"
                                Row { anchors.centerIn: parent; spacing: 7
                                    Rectangle { width: 9; height: 9; radius: 5; color: appController.monitoring ? green : warning; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: appController.monitoring ? tr("Мониторинг ON", "Monitoring ON") : tr("Мониторинг OFF", "Monitoring OFF"); color: appController.monitoring ? "#58D99C" : "#E1AA62"; font.pixelSize: 12 }
                                }
                            }
                            Row {
                                visible: currentPage === 0 || currentPage === 2 || currentPage === 3
                                spacing: 8
                                Text { text: "▥"; color: accent; font.pixelSize: 18 }
                                Text { text: tr("Сбор данных и анализ инвентарей", "Collecting data and analyzing inventories"); color: textMuted; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                            }
                            Card {
                                Layout.preferredWidth: 248
                                Layout.preferredHeight: 56
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 12
                                    spacing: 10
                                    Text { text: "◷"; color: textSecondary; font.pixelSize: 19 }
                                    ColumnLayout {
                                        spacing: 2
                                        Text { text: dateText + ", " + clockText; color: textSecondary; font.pixelSize: 12 }
                                        Text { text: appController.monitoring ? tr("Мониторинг активен", "Monitoring active") : tr("Мониторинг остановлен", "Monitoring stopped"); color: textMuted; font.pixelSize: 10 }
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text { text: "⋮"; color: textMuted; font.pixelSize: 20 }
                                }
                            }
                        }
                    }

                    StackLayout {
                        currentIndex: currentPage
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Item {
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 12
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 108
                                    spacing: 12
                                    StatCard { Layout.fillWidth: true; icon: "▤"; label: tr("Серверов онлайн", "Servers online"); value: appController.onlineServers + " / " + appController.servers.length; delta: appController.onlineServers > 0 ? "+" + appController.onlineServers : "" }
                                    StatCard { Layout.fillWidth: true; icon: "●"; label: tr("Игроков онлайн", "Players online"); value: String(appController.onlinePlayers); delta: appController.onlinePlayers > 0 ? "+" + Math.min(99, appController.onlinePlayers) : "" }
                                    StatCard { Layout.fillWidth: true; icon: "▣"; label: tr("Проверено сегодня", "Checked today"); value: String(appController.checkedToday); delta: appController.checkedToday > 0 ? "+" + Math.min(99, appController.checkedToday) : "" }
                                    StatCard { Layout.fillWidth: true; icon: "◎"; label: tr("Совпадений", "Matches"); value: String(appController.results.length); delta: appController.matchedSession > 0 ? "+" + appController.matchedSession : "" }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 12

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.preferredWidth: 7
                                        spacing: 12

                                        Card {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: Math.max(295, parent.height * 0.48)
                                            ColumnLayout {
                                                anchors.fill: parent
                                                spacing: 0
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: 54
                                                    Layout.leftMargin: 16
                                                    Layout.rightMargin: 13
                                                    Text { text: "▤"; color: accent; font.pixelSize: 20 }
                                                    Text { text: tr("Отслеживаемые серверы", "Tracked servers"); color: textPrimary; font.pixelSize: 16; font.weight: Font.DemiBold }
                                                    Item { Layout.fillWidth: true }
                                                    GhostButton { text: tr("Добавить сервер", "Add server"); icon: "+"; buttonHeight: 34; onClicked: currentPage = 1 }
                                                    IconButton { icon: "⋮" }
                                                }
                                                Divider { Layout.fillWidth: true }
                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: 40
                                                    color: "#141A1D"
                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 14
                                                        anchors.rightMargin: 14
                                                        Text { text: "IP:PORT"; color: textMuted; font.pixelSize: 10; Layout.preferredWidth: 160 }
                                                        Text { text: tr("Игра", "Game"); color: textMuted; font.pixelSize: 10; Layout.preferredWidth: 72 }
                                                        Text { text: tr("Карта", "Map"); color: textMuted; font.pixelSize: 10; Layout.fillWidth: true }
                                                        Text { text: tr("Игроки", "Players"); color: textMuted; font.pixelSize: 10; Layout.preferredWidth: 78 }
                                                        Text { text: tr("Пинг", "Ping"); color: textMuted; font.pixelSize: 10; Layout.preferredWidth: 68 }
                                                        Text { text: tr("Статус", "Status"); color: textMuted; font.pixelSize: 10; Layout.preferredWidth: 80 }
                                                    }
                                                }
                                                ListView {
                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true
                                                    clip: true
                                                    model: appController.servers
                                                    delegate: Rectangle {
                                                        required property var modelData
                                                        width: ListView.view.width
                                                        height: 50
                                                        color: "transparent"
                                                        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: lineSoft }
                                                        RowLayout {
                                                            anchors.fill: parent
                                                            anchors.leftMargin: 14
                                                            anchors.rightMargin: 10
                                                            Text { text: modelData.address; color: textPrimary; font.pixelSize: 11; Layout.preferredWidth: 160; elide: Text.ElideRight }
                                                            Row { Layout.preferredWidth: 72; spacing: 6; Image { source: Qt.resolvedUrl("../assets/Games/CS2.jpg"); width: 22; height: 22 }; Text { text: "CS2"; color: textSecondary; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter } }
                                                            Text { text: modelData.map || "—"; color: textSecondary; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
                                                            Text { text: modelData.players; color: textSecondary; font.pixelSize: 11; Layout.preferredWidth: 78 }
                                                            Text { text: modelData.ping; color: modelData.online ? "#B7C1C6" : red; font.pixelSize: 11; Layout.preferredWidth: 68 }
                                                            StatusDot { Layout.preferredWidth: 80; text: modelData.online ? tr("Онлайн", "Online") : tr("Оффлайн", "Offline"); dotColor: modelData.online ? green : red }
                                                        }
                                                    }
                                                    Text { visible: appController.servers.length === 0; anchors.centerIn: parent; text: tr("Добавьте CS2-сервер для начала мониторинга", "Add a CS2 server to start monitoring"); color: textMuted; font.pixelSize: 13 }
                                                }
                                            }
                                        }

                                        Card {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            ColumnLayout {
                                                anchors.fill: parent
                                                spacing: 0
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: 50
                                                    Layout.leftMargin: 16
                                                    Layout.rightMargin: 14
                                                    Text { text: "◷"; color: accent; font.pixelSize: 20 }
                                                    Text { text: tr("Последняя активность", "Latest activity"); color: textPrimary; font.pixelSize: 16; font.weight: Font.DemiBold }
                                                    Item { Layout.fillWidth: true }
                                                    GhostButton { text: tr("Все события", "All events"); buttonHeight: 32; onClicked: currentPage = 3 }
                                                }
                                                Divider { Layout.fillWidth: true }
                                                ListView {
                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true
                                                    clip: true
                                                    model: Math.min(5, appController.results.length)
                                                    delegate: Rectangle {
                                                        width: ListView.view.width
                                                        height: 46
                                                        color: "transparent"
                                                        property var rowData: appController.results[index]
                                                        RowLayout {
                                                            anchors.fill: parent
                                                            anchors.leftMargin: 16
                                                            anchors.rightMargin: 14
                                                            Text { text: "•"; color: green; font.pixelSize: 22 }
                                                            ColumnLayout {
                                                                Layout.fillWidth: true
                                                                spacing: 1
                                                                Text { text: tr("Игрок найден", "Player found") + ": " + (rowData ? rowData.nickname : ""); color: textSecondary; font.pixelSize: 11 }
                                                                Text { text: rowData ? rowData.server_address : ""; color: textMuted; font.pixelSize: 9 }
                                                            }
                                                            Text { text: rowData ? money(rowData.total_rub) : ""; color: accent; font.pixelSize: 11; font.weight: Font.DemiBold }
                                                        }
                                                    }
                                                    Column { visible: appController.results.length === 0; anchors.centerIn: parent; spacing: 6
                                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: appController.monitoring ? tr("Мониторинг запущен", "Monitoring is running") : tr("Мониторинг не запущен", "Monitoring is not running"); color: textSecondary; font.pixelSize: 13 }
                                                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: tr("Новые события появятся здесь", "New events will appear here"); color: textMuted; font.pixelSize: 11 }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.preferredWidth: 5
                                        spacing: 12

                                        Card {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 260
                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.margins: 14
                                                spacing: 10
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    Text { text: "▼"; color: accent; font.pixelSize: 18 }
                                                    Text { text: tr("Фильтры поиска игроков", "Player search filters"); color: textPrimary; font.pixelSize: 16; font.weight: Font.DemiBold }
                                                    Item { Layout.fillWidth: true }
                                                    GhostButton { text: tr("Изменить фильтры", "Edit filters"); icon: "⚙"; buttonHeight: 32; onClicked: currentPage = 4 }
                                                }
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true
                                                    spacing: 10
                                                    GameFilterCard { Layout.fillWidth: true; game: "CS2"; imageSource: Qt.resolvedUrl("../assets/Games/CS2.jpg"); minimum: appController.cs2Min; maximum: appController.cs2Max }
                                                    GameFilterCard { Layout.fillWidth: true; game: "Dota 2"; imageSource: Qt.resolvedUrl("../assets/Games/Dota2.jpg"); minimum: appController.dotaMin; maximum: appController.dotaMax }
                                                    GameFilterCard { Layout.fillWidth: true; game: "Rust"; imageSource: Qt.resolvedUrl("../assets/Games/Rust.jpg"); minimum: appController.rustMin; maximum: appController.rustMax }
                                                }
                                            }
                                        }

                                        Card {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            ColumnLayout {
                                                anchors.fill: parent
                                                spacing: 0
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: 50
                                                    Layout.leftMargin: 15
                                                    Layout.rightMargin: 13
                                                    Text { text: "♟"; color: accent; font.pixelSize: 20 }
                                                    Text { text: tr("Найденные игроки", "Found players"); color: textPrimary; font.pixelSize: 16; font.weight: Font.DemiBold }
                                                    Item { Layout.fillWidth: true }
                                                    Text { text: tr("Всего: ", "Total: ") + appController.results.length; color: textMuted; font.pixelSize: 11 }
                                                    GhostButton { text: tr("Сначала новые", "Newest first"); buttonHeight: 30 }
                                                }
                                                Divider { Layout.fillWidth: true }
                                                ListView {
                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true
                                                    clip: true
                                                    model: appController.results
                                                    delegate: Rectangle {
                                                        required property var modelData
                                                        width: ListView.view.width
                                                        height: 92
                                                        color: "transparent"
                                                        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: lineSoft }
                                                        RowLayout {
                                                            anchors.fill: parent
                                                            anchors.margins: 12
                                                            Rectangle { Layout.preferredWidth: 42; Layout.preferredHeight: 42; radius: 21; color: "#1C2326"; border.color: "#3A4449"; Text { anchors.centerIn: parent; text: (modelData.nickname || "?").charAt(0).toUpperCase(); color: textSecondary; font.pixelSize: 18; font.weight: Font.DemiBold } }
                                                            ColumnLayout {
                                                                Layout.fillWidth: true
                                                                spacing: 4
                                                                Row { spacing: 8
                                                                    Text { text: modelData.nickname; color: textPrimary; font.pixelSize: 13; font.weight: Font.DemiBold }
                                                                    Text { text: "●"; color: blue; font.pixelSize: 10 }
                                                                }
                                                                Text { text: "◉ Steam"; color: textMuted; font.pixelSize: 10 }
                                                                Text { text: tr("Найден на: ", "Found on: ") + modelData.server_address + "  (" + (modelData.map_name || "—") + ")"; color: textMuted; font.pixelSize: 9; elide: Text.ElideRight }
                                                            }
                                                            Column { spacing: 3; width: 74
                                                                Text { text: "CS2"; color: matched(modelData, "cs2") ? accent : textMuted; font.pixelSize: 9 }
                                                                Text { text: money(modelData.cs2_rub); color: matched(modelData, "cs2") ? "#F0B45E" : textMuted; font.pixelSize: 11; font.weight: matched(modelData, "cs2") ? Font.DemiBold : Font.Normal }
                                                            }
                                                            Column { spacing: 3; width: 74
                                                                Text { text: "Dota 2"; color: matched(modelData, "dota2") ? accent : textMuted; font.pixelSize: 9 }
                                                                Text { text: money(modelData.dota2_rub); color: matched(modelData, "dota2") ? "#F0B45E" : textMuted; font.pixelSize: 11 }
                                                            }
                                                            Column { spacing: 3; width: 74
                                                                Text { text: "Rust"; color: matched(modelData, "rust") ? accent : textMuted; font.pixelSize: 9 }
                                                                Text { text: money(modelData.rust_rub); color: matched(modelData, "rust") ? "#F0B45E" : textMuted; font.pixelSize: 11 }
                                                            }
                                                            Column { spacing: 3; width: 82
                                                                Text { text: tr("Всего", "Total"); color: textMuted; font.pixelSize: 9 }
                                                                Text { text: money(modelData.total_rub); color: accent; font.pixelSize: 14; font.weight: Font.DemiBold }
                                                            }
                                                            IconButton { icon: "⋮" }
                                                        }
                                                    }
                                                    Text { visible: appController.results.length === 0; anchors.centerIn: parent; text: tr("Подходящие игроки пока не найдены", "No matching players yet"); color: textMuted; font.pixelSize: 12 }
                                                }
                                            }
                                        }
                                    }
                                }
                                Text { Layout.alignment: Qt.AlignRight; text: tr("Работаем, пока другие ждут 🦫", "Working while others wait 🦫"); color: "#646F75"; font.pixelSize: 9 }
                            }
                        }

                        Item {
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 12
                                Card {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 74
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 12
                                        PrimaryButton { text: tr("Добавить сервер", "Add server"); icon: "+"; buttonHeight: 48; onClicked: addressField.forceActiveFocus() }
                                        GhostButton { text: tr("Импорт списка", "Import list"); icon: "⇩"; buttonHeight: 48; onClicked: appController.showMessage(tr("Импорт списка будет добавлен позже", "List import is coming later")) }
                                        Item { Layout.fillWidth: true }
                                        Field { id: serverSearchField; Layout.preferredWidth: 320; leading: "⌕"; placeholderText: tr("Поиск по серверам...", "Search servers..."); onTextChanged: serverSearch = text }
                                    }
                                }

                                Card {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.max(300, parent.height * 0.45)
                                    ColumnLayout {
                                        anchors.fill: parent
                                        spacing: 0
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 44
                                            color: "#151B1E"
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 14
                                                anchors.rightMargin: 12
                                                Text { text: "IP:PORT"; color: textMuted; font.pixelSize: 10; Layout.preferredWidth: 170 }
                                                Text { text: tr("Название", "Name"); color: textMuted; font.pixelSize: 10; Layout.preferredWidth: 230 }
                                                Text { text: tr("Карта", "Map"); color: textMuted; font.pixelSize: 10; Layout.preferredWidth: 150 }
                                                Text { text: tr("Статус", "Status"); color: textMuted; font.pixelSize: 10; Layout.preferredWidth: 100 }
                                                Text { text: tr("Игроков", "Players"); color: textMuted; font.pixelSize: 10; Layout.preferredWidth: 86 }
                                                Text { text: tr("Последняя проверка", "Last check"); color: textMuted; font.pixelSize: 10; Layout.fillWidth: true }
                                                Text { text: tr("Источник", "Source"); color: textMuted; font.pixelSize: 10; Layout.preferredWidth: 125 }
                                                Text { text: tr("Действия", "Actions"); color: textMuted; font.pixelSize: 10; Layout.preferredWidth: 116 }
                                            }
                                        }
                                        ListView {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            clip: true
                                            model: appController.servers
                                            delegate: Rectangle {
                                                required property var modelData
                                                visible: serverSearch === "" || String(modelData.address).toLowerCase().indexOf(serverSearch.toLowerCase()) >= 0 || String(modelData.name).toLowerCase().indexOf(serverSearch.toLowerCase()) >= 0
                                                height: visible ? 52 : 0
                                                width: ListView.view.width
                                                color: "transparent"
                                                Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: lineSoft }
                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 14
                                                    anchors.rightMargin: 10
                                                    Text { text: modelData.address; color: textPrimary; font.pixelSize: 11; Layout.preferredWidth: 170 }
                                                    Row { Layout.preferredWidth: 230; spacing: 8; Image { source: Qt.resolvedUrl("../assets/Games/CS2.jpg"); width: 24; height: 24 }; Text { text: modelData.name; color: textSecondary; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter; width: 190; elide: Text.ElideRight } }
                                                    Text { text: modelData.map; color: textSecondary; font.pixelSize: 11; Layout.preferredWidth: 150 }
                                                    StatusDot { Layout.preferredWidth: 100; text: modelData.online ? tr("Онлайн", "Online") : tr("Оффлайн", "Offline"); dotColor: modelData.online ? green : red }
                                                    Text { text: modelData.players; color: textSecondary; font.pixelSize: 11; Layout.preferredWidth: 86 }
                                                    Text { text: clockText; color: textMuted; font.pixelSize: 10; Layout.fillWidth: true }
                                                    Row { Layout.preferredWidth: 125; spacing: 7; Text { text: "⚡"; color: accent; font.pixelSize: 17 }; Text { text: "A2S Direct"; color: textSecondary; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter } }
                                                    Row { Layout.preferredWidth: 116; spacing: 2
                                                        IconButton { icon: "✎"; onClicked: appController.showMessage(tr("Редактирование сервера будет добавлено позже", "Server editing is coming later")) }
                                                        IconButton { icon: "□"; onClicked: appController.showMessage(modelData.address) }
                                                        IconButton { icon: "⌫"; onClicked: appController.removeServer(modelData.id) }
                                                    }
                                                }
                                            }
                                            Text { visible: appController.servers.length === 0; anchors.centerIn: parent; text: tr("Список серверов пуст", "Server list is empty"); color: textMuted }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 12
                                    Card {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.preferredWidth: 1.2
                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 16
                                            spacing: 10
                                            RowLayout { Layout.fillWidth: true
                                                Text { text: "⚙"; color: accent; font.pixelSize: 20 }
                                                Text { text: tr("Добавить / Редактировать сервер", "Add / Edit server"); color: textPrimary; font.pixelSize: 16; font.weight: Font.DemiBold }
                                                Item { Layout.fillWidth: true }
                                                GhostButton { text: tr("Очистить форму", "Clear form"); icon: "⌫"; buttonHeight: 32; onClicked: { addressField.clear(); serverNameField.clear() } }
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 10
                                                ColumnLayout { Layout.fillWidth: true; spacing: 5; Text { text: tr("IP адрес", "IP address"); color: textMuted; font.pixelSize: 11 }; Field { id: addressField; Layout.fillWidth: true; placeholderText: tr("Например: 212.22.93.14:27015", "Example: 212.22.93.14:27015") } }
                                                ColumnLayout { Layout.preferredWidth: 170; spacing: 5; Text { text: tr("Порт", "Port"); color: textMuted; font.pixelSize: 11 }; Field { text: "27015"; Layout.fillWidth: true; enabled: false } }
                                            }
                                            ColumnLayout { Layout.fillWidth: true; spacing: 5; Text { text: tr("Название сервера", "Server name"); color: textMuted; font.pixelSize: 11 }; Field { id: serverNameField; Layout.fillWidth: true; placeholderText: tr("Например: Мой сервер CS2", "Example: My CS2 server") } }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 12
                                                ColumnLayout { Layout.fillWidth: true; spacing: 5; Text { text: tr("Интервал проверки", "Poll interval"); color: textMuted; font.pixelSize: 11 }; Field { text: appController.pollInterval + tr(" секунд", " seconds"); enabled: false; Layout.fillWidth: true } }
                                                ColumnLayout { Layout.fillWidth: true; spacing: 5; Text { text: tr("Источник (резолвер)", "Source (resolver)"); color: textMuted; font.pixelSize: 11 }; Field { text: "⚡  A2S Direct"; enabled: false; Layout.fillWidth: true } }
                                                ColumnLayout { Layout.preferredWidth: 130; spacing: 5; Text { text: tr("Включен", "Enabled"); color: textMuted; font.pixelSize: 11 }; ToggleSwitch { checked: true; caption: tr("Сервер активен", "Server active") } }
                                            }
                                            RowLayout { Layout.fillWidth: true; Item { Layout.fillWidth: true }; PrimaryButton { text: tr("Сохранить сервер", "Save server"); icon: "▣"; onClicked: { appController.addServer(addressField.text, serverNameField.text); addressField.clear(); serverNameField.clear() } }; GhostButton { text: tr("Отмена", "Cancel"); icon: "×"; onClicked: { addressField.clear(); serverNameField.clear() } } }
                                        }
                                    }

                                    Card {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        ColumnLayout {
                                            anchors.fill: parent
                                            spacing: 0
                                            RowLayout { Layout.fillWidth: true; Layout.preferredHeight: 50; Layout.leftMargin: 16; Text { text: "▤"; color: accent; font.pixelSize: 20 }; Text { text: tr("Источники мониторинга", "Monitoring sources"); color: textPrimary; font.pixelSize: 16; font.weight: Font.DemiBold } }
                                            Divider { Layout.fillWidth: true }
                                            Repeater {
                                                model: [
                                                    { icon:"⚡", title:"A2S Direct", desc:tr("Прямое подключение к игровому серверу (протокол A2S). Наиболее точные данные.", "Direct connection to the game server via A2S. Most accurate data."), ping:"~50 ms", reliability:tr("Высокая", "High"), active:true },
                                                    { icon:"S", title:"Steam Community", desc:tr("Бесплатный поиск публичных Steam-профилей для сопоставления игроков.", "Free public Steam profile search for player resolution."), ping:"~180 ms", reliability:tr("Средняя", "Medium"), active:true },
                                                    { icon:"M", title:"Steam Market", desc:tr("Актуальные цены торговой площадки для CS2, Dota 2 и Rust.", "Current Steam Market prices for CS2, Dota 2 and Rust."), ping:"~220 ms", reliability:tr("Высокая", "High"), active:true }
                                                ]
                                                delegate: Rectangle {
                                                    required property var modelData
                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true
                                                    color: "transparent"
                                                    border.color: "transparent"
                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 16
                                                        anchors.rightMargin: 16
                                                        spacing: 12
                                                        Rectangle { Layout.preferredWidth: 48; Layout.preferredHeight: 48; radius: 9; color: "#1C211E"; border.color: "#4B3A26"; Text { anchors.centerIn: parent; text: modelData.icon; color: accent; font.pixelSize: 22; font.weight: Font.DemiBold } }
                                                        ColumnLayout { Layout.fillWidth: true; spacing: 3; Row { spacing: 9; Text { text: modelData.title; color: textPrimary; font.pixelSize: 13; font.weight: Font.DemiBold }; StatusDot { text: tr("Работает", "Working"); dotColor: green } }; Text { text: modelData.desc; color: textMuted; font.pixelSize: 10; wrapMode: Text.WordWrap; Layout.fillWidth: true } }
                                                        Column { Layout.preferredWidth: 72; Text { text: tr("Пинг", "Ping"); color: textMuted; font.pixelSize: 9 }; Text { text: modelData.ping; color: green; font.pixelSize: 11 } }
                                                        Column { Layout.preferredWidth: 92; Text { text: tr("Надёжность", "Reliability"); color: textMuted; font.pixelSize: 9 }; Text { text: modelData.reliability; color: modelData.reliability === tr("Высокая", "High") ? green : warning; font.pixelSize: 11 } }
                                                    }
                                                    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: lineSoft }
                                                }
                                            }
                                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 38; color: "#101719"; Text { anchors.centerIn: parent; text: tr("ⓘ Можно отслеживать не более 20 серверов одновременно. Сейчас используется ", "ⓘ Up to 20 servers can be monitored simultaneously. In use: ") + appController.servers.length + tr(" из 20.", " of 20."); color: textMuted; font.pixelSize: 10 } }
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 12
                                Card {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 72
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 12
                                        Field { Layout.preferredWidth: 310; leading: "⌕"; placeholderText: tr("Поиск по нику или SteamID...", "Search nickname or SteamID..."); onTextChanged: resultSearch = text }
                                        Text { text: tr("Игры:", "Games:"); color: textMuted; font.pixelSize: 11 }
                                        GameBadge { game: "CS2"; sourcePath: Qt.resolvedUrl("../assets/Games/CS2.jpg") }
                                        GameBadge { game: "Dota 2"; sourcePath: Qt.resolvedUrl("../assets/Games/Dota2.jpg") }
                                        GameBadge { game: "Rust"; sourcePath: Qt.resolvedUrl("../assets/Games/Rust.jpg") }
                                        GameBadge { game: tr("Все", "All"); sourcePath: "" }
                                        Item { Layout.fillWidth: true }
                                        GhostButton { text: tr("По итоговой стоимости", "By total value"); buttonHeight: 42 }
                                        GhostButton { text: tr("За все время", "All time"); icon: "▣"; buttonHeight: 42 }
                                        PrimaryButton { text: tr("Экспорт в Excel", "Export to Excel"); icon: "⇩"; buttonHeight: 48; onClicked: exportDialog.open() }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 98
                                    spacing: 10
                                    StatCard { Layout.fillWidth: true; label: tr("Всего совпадений", "Total matches"); value: String(appController.results.length); icon: "♟"; delta: appController.results.length > 0 ? "+" + appController.results.length : "" }
                                    StatCard { Layout.fillWidth: true; label: tr("Уникальных игроков", "Unique players"); value: String(appController.results.length); icon: "♟"; delta: "" }
                                    StatCard { Layout.fillWidth: true; label: tr("Средняя стоимость", "Average value"); value: money(averageResult()); icon: "◉"; delta: "" }
                                    StatCard { Layout.fillWidth: true; label: tr("Наивысший итог", "Highest total"); value: money(highestResult()); icon: "♛"; delta: "" }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 12
                                    Card {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.preferredWidth: 4.2
                                        ColumnLayout {
                                            anchors.fill: parent
                                            spacing: 0
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 48
                                                Layout.leftMargin: 14
                                                Layout.rightMargin: 12
                                                Text { text: "♟"; color: accent; font.pixelSize: 18 }
                                                Text { text: tr("Результаты поиска", "Search results") + " (" + appController.results.length + ")"; color: textPrimary; font.pixelSize: 15; font.weight: Font.DemiBold }
                                                Item { Layout.fillWidth: true }
                                            }
                                            Divider { Layout.fillWidth: true }
                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 38
                                                color: "#151B1E"
                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 12
                                                    anchors.rightMargin: 10
                                                    Text { text: "□"; color: textMuted; Layout.preferredWidth: 24 }
                                                    Text { text: tr("Игрок", "Player"); color: textMuted; font.pixelSize: 9; Layout.preferredWidth: 150 }
                                                    Text { text: "SteamID64"; color: textMuted; font.pixelSize: 9; Layout.preferredWidth: 155 }
                                                    Text { text: "CS2"; color: textMuted; font.pixelSize: 9; Layout.preferredWidth: 82 }
                                                    Text { text: "Dota 2"; color: textMuted; font.pixelSize: 9; Layout.preferredWidth: 82 }
                                                    Text { text: "Rust"; color: textMuted; font.pixelSize: 9; Layout.preferredWidth: 82 }
                                                    Text { text: tr("Итог", "Total"); color: textMuted; font.pixelSize: 9; Layout.preferredWidth: 96 }
                                                    Text { text: tr("Совпадение", "Match"); color: textMuted; font.pixelSize: 9; Layout.preferredWidth: 128 }
                                                    Text { text: tr("Сервер", "Server"); color: textMuted; font.pixelSize: 9; Layout.fillWidth: true }
                                                    Text { text: tr("Проверка", "Check"); color: textMuted; font.pixelSize: 9; Layout.preferredWidth: 96 }
                                                }
                                            }
                                            ListView {
                                                id: resultList
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                clip: true
                                                model: appController.results
                                                delegate: Rectangle {
                                                    required property var modelData
                                                    visible: resultContains(modelData, resultSearch)
                                                    width: ListView.view.width
                                                    height: visible ? 60 : 0
                                                    color: index === selectedResultIndex ? "#2A2119" : resultMouse.containsMouse ? "#151B1E" : "transparent"
                                                    border.color: index === selectedResultIndex ? "#B37C3C" : "transparent"
                                                    radius: index === selectedResultIndex ? 7 : 0
                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 10
                                                        anchors.rightMargin: 8
                                                        Text { text: index === selectedResultIndex ? "☑" : "□"; color: index === selectedResultIndex ? accent : textMuted; Layout.preferredWidth: 24 }
                                                        Row { Layout.preferredWidth: 150; spacing: 8; Rectangle { width: 32; height: 32; radius: 16; color: "#1B2225"; border.color: "#3B454A"; Text { anchors.centerIn: parent; text: (modelData.nickname || "?").charAt(0).toUpperCase(); color: textSecondary; font.pixelSize: 13; font.bold: true } }; Column { spacing: 2; Text { text: modelData.nickname; color: textPrimary; font.pixelSize: 11; width: 104; elide: Text.ElideRight }; Text { text: "◉ Steam"; color: textMuted; font.pixelSize: 8 } } }
                                                        Text { text: modelData.steam_id64; color: textMuted; font.pixelSize: 9; Layout.preferredWidth: 155; elide: Text.ElideRight }
                                                        Text { text: money(modelData.cs2_rub); color: matched(modelData, "cs2") ? textPrimary : textMuted; font.pixelSize: 10; Layout.preferredWidth: 82 }
                                                        Text { text: money(modelData.dota2_rub); color: matched(modelData, "dota2") ? textPrimary : textMuted; font.pixelSize: 10; Layout.preferredWidth: 82 }
                                                        Text { text: money(modelData.rust_rub); color: matched(modelData, "rust") ? textPrimary : textMuted; font.pixelSize: 10; Layout.preferredWidth: 82 }
                                                        Text { text: money(modelData.total_rub); color: accent; font.pixelSize: 12; font.weight: Font.DemiBold; Layout.preferredWidth: 96 }
                                                        Row { Layout.preferredWidth: 128; spacing: 4; GameBadge { visible: matched(modelData, "cs2"); game: "CS2"; sourcePath: Qt.resolvedUrl("../assets/Games/CS2.jpg"); scale: 0.75; transformOrigin: Item.Left }; GameBadge { visible: matched(modelData, "rust"); game: "Rust"; sourcePath: Qt.resolvedUrl("../assets/Games/Rust.jpg"); scale: 0.75; transformOrigin: Item.Left } }
                                                        Text { text: modelData.map_name || modelData.server_address; color: textMuted; font.pixelSize: 9; Layout.fillWidth: true; elide: Text.ElideRight }
                                                        Text { text: modelData.last_seen_at ? String(modelData.last_seen_at).slice(0, 16).replace("T", " ") : "—"; color: textMuted; font.pixelSize: 8; Layout.preferredWidth: 96 }
                                                    }
                                                    MouseArea { id: resultMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: selectedResultIndex = index }
                                                }
                                                Text { visible: appController.results.length === 0; anchors.centerIn: parent; text: tr("Результатов пока нет", "No results yet"); color: textMuted; font.pixelSize: 12 }
                                            }
                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 40
                                                color: "#0F1416"
                                                RowLayout { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                                                    Text { text: tr("Показано ", "Showing ") + appController.results.length + tr(" результатов", " results"); color: textMuted; font.pixelSize: 9 }
                                                    Item { Layout.fillWidth: true }
                                                    GhostButton { text: "‹"; buttonHeight: 28 }
                                                    PrimaryButton { text: "1"; buttonHeight: 28 }
                                                    GhostButton { text: "2"; buttonHeight: 28 }
                                                    GhostButton { text: "3"; buttonHeight: 28 }
                                                }
                                            }
                                        }
                                    }

                                    Card {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.preferredWidth: 1.35
                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 14
                                            spacing: 10
                                            RowLayout { Layout.fillWidth: true; Text { text: "♟"; color: accent; font.pixelSize: 18 }; Text { text: tr("Информация об игроке", "Player information"); color: textPrimary; font.pixelSize: 15; font.weight: Font.DemiBold }; Item { Layout.fillWidth: true }; Text { text: "×"; color: textMuted; font.pixelSize: 18 } }
                                            Divider { Layout.fillWidth: true }
                                            Item { Layout.fillWidth: true; Layout.preferredHeight: 70
                                                Rectangle { width: 60; height: 60; radius: 30; color: "#1C2326"; border.color: "#3A454A"; Text { anchors.centerIn: parent; text: selectedResult ? String(selectedResult.nickname || "?").charAt(0).toUpperCase() : "?"; color: textSecondary; font.pixelSize: 23; font.bold: true } }
                                                Column { anchors.left: parent.left; anchors.leftMargin: 74; anchors.verticalCenter: parent.verticalCenter; spacing: 5
                                                    Row { spacing: 7; Text { text: selectedResult ? selectedResult.nickname : tr("Игрок не выбран", "No player selected"); color: textPrimary; font.pixelSize: 15; font.weight: Font.DemiBold }; Text { text: selectedResult ? "●" : ""; color: blue; font.pixelSize: 10 } }
                                                    GhostButton { visible: selectedResult !== null; text: "Steam"; icon: "◉"; buttonHeight: 30; onClicked: if (selectedResult) Qt.openUrlExternally(selectedResult.profile_url) }
                                                }
                                            }
                                            RowLayout { Layout.fillWidth: true; Text { text: "SteamID64"; color: textMuted; font.pixelSize: 10 }; Item { Layout.fillWidth: true }; Text { text: selectedResult ? selectedResult.steam_id64 : "—"; color: textSecondary; font.pixelSize: 9 } }
                                            Divider { Layout.fillWidth: true }
                                            RowLayout { Layout.fillWidth: true; Text { text: tr("Итоговая стоимость", "Total value"); color: textMuted; font.pixelSize: 11 }; Item { Layout.fillWidth: true }; Text { text: selectedResult ? money(selectedResult.total_rub) : "—"; color: accent; font.pixelSize: 19; font.weight: Font.DemiBold } }
                                            RowLayout { Layout.fillWidth: true; Image { source: Qt.resolvedUrl("../assets/Games/CS2.jpg"); width: 22; height: 22 }; Text { text: tr("CS2 инвентарь", "CS2 inventory"); color: textSecondary; font.pixelSize: 11 }; Item { Layout.fillWidth: true }; Text { text: selectedResult ? money(selectedResult.cs2_rub) : "—"; color: accent; font.pixelSize: 13; font.weight: Font.DemiBold } }
                                            RowLayout { Layout.fillWidth: true; Image { source: Qt.resolvedUrl("../assets/Games/Dota2.jpg"); width: 22; height: 22 }; Text { text: tr("Dota 2 инвентарь", "Dota 2 inventory"); color: textSecondary; font.pixelSize: 11 }; Item { Layout.fillWidth: true }; Text { text: selectedResult ? money(selectedResult.dota2_rub) : "—"; color: accent; font.pixelSize: 13; font.weight: Font.DemiBold } }
                                            RowLayout { Layout.fillWidth: true; Image { source: Qt.resolvedUrl("../assets/Games/Rust.jpg"); width: 22; height: 22 }; Text { text: tr("Rust инвентарь", "Rust inventory"); color: textSecondary; font.pixelSize: 11 }; Item { Layout.fillWidth: true }; Text { text: selectedResult ? money(selectedResult.rust_rub) : "—"; color: accent; font.pixelSize: 13; font.weight: Font.DemiBold } }
                                            Divider { Layout.fillWidth: true }
                                            Text { text: tr("Совпадения", "Matches"); color: textMuted; font.pixelSize: 10 }
                                            Row { spacing: 6; GameBadge { visible: selectedResult && matched(selectedResult, "cs2"); game: "CS2"; sourcePath: Qt.resolvedUrl("../assets/Games/CS2.jpg") }; GameBadge { visible: selectedResult && matched(selectedResult, "dota2"); game: "Dota 2"; sourcePath: Qt.resolvedUrl("../assets/Games/Dota2.jpg") }; GameBadge { visible: selectedResult && matched(selectedResult, "rust"); game: "Rust"; sourcePath: Qt.resolvedUrl("../assets/Games/Rust.jpg") } }
                                            Text { text: tr("Найден на сервере", "Found on server"); color: textMuted; font.pixelSize: 10 }
                                            Text { text: selectedResult ? selectedResult.server_address + "  •  " + (selectedResult.map_name || "—") : "—"; color: textSecondary; font.pixelSize: 10; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                            Text { visible: selectedResult; text: tr("Найден: ", "Seen: ") + (selectedResult ? selectedResult.times_seen : 0) + tr(" раз", " times"); color: textMuted; font.pixelSize: 10 }
                                            Item { Layout.fillHeight: true }
                                            Text { text: tr("Быстрые действия", "Quick actions"); color: textMuted; font.pixelSize: 10 }
                                            PrimaryButton { Layout.fillWidth: true; text: tr("Открыть в Steam", "Open in Steam"); icon: "⌕"; onClicked: if (selectedResult) Qt.openUrlExternally(selectedResult.profile_url) }
                                            GhostButton { Layout.fillWidth: true; text: tr("Скопировать SteamID", "Copy SteamID"); icon: "⌘"; onClicked: appController.showMessage(selectedResult ? selectedResult.steam_id64 : tr("Игрок не выбран", "No player selected")) }
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 12
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 96
                                    spacing: 10
                                    Repeater {
                                        model: [
                                            {icon:"⌁", title:tr("A2S доступ", "A2S access"), state: appController.servers.length > 0 ? tr("Готов", "Ready") : tr("Нет серверов", "No servers"), desc:tr("UDP запросы", "UDP queries")},
                                            {icon:"⌕", title:"Resolver SteamID", state:appController.servicesReady ? tr("Работает", "Working") : tr("Запуск", "Starting"), desc:tr("Steam-поиск", "Steam search")},
                                            {icon:"◉", title:tr("API цены", "Price API"), state:appController.servicesReady ? tr("Доступно", "Available") : tr("Запуск", "Starting"), desc:"Steam Market"},
                                            {icon:"□", title:tr("Сканирование инвентарей", "Inventory scan"), state:appController.servicesReady ? tr("Работает", "Working") : tr("Запуск", "Starting"), desc:tr("Получение данных", "Fetching data")},
                                            {icon:"▤", title:tr("Кэш системы", "System cache"), state:tr("В норме", "Healthy"), desc:"SQLite"}
                                        ]
                                        delegate: Card {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            RowLayout { anchors.fill: parent; anchors.margins: 12; spacing: 10
                                                Rectangle { Layout.preferredWidth: 46; Layout.preferredHeight: 46; radius: 8; color: "#211D18"; border.color: "#493824"; Text { anchors.centerIn: parent; text: modelData.icon; color: accent; font.pixelSize: 21 } }
                                                ColumnLayout { Layout.fillWidth: true; spacing: 3; Row { spacing: 7; Text { text: modelData.title; color: textPrimary; font.pixelSize: 12; font.weight: Font.DemiBold }; StatusDot { text: modelData.state; dotColor: green } }; Text { text: modelData.desc; color: textMuted; font.pixelSize: 9 } }
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 12
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.preferredWidth: 3
                                        spacing: 12
                                        Card {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 340
                                            ColumnLayout {
                                                anchors.fill: parent
                                                spacing: 0
                                                RowLayout { Layout.fillWidth: true; Layout.preferredHeight: 48; Layout.leftMargin: 14; Layout.rightMargin: 12; Text { text: "♟"; color: accent; font.pixelSize: 19 }; Column { Text { text: tr("Поток игроков", "Player stream"); color: textPrimary; font.pixelSize: 15; font.weight: Font.DemiBold }; Text { text: tr("Последние обнаруженные и обработанные игроки", "Recently discovered and processed players"); color: textMuted; font.pixelSize: 9 } }; Item { Layout.fillWidth: true }; GhostButton { text: tr("Все серверы", "All servers"); icon: "▤"; buttonHeight: 30 } }
                                                Divider { Layout.fillWidth: true }
                                                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 34; color: "#151B1E"; RowLayout { anchors.fill: parent; anchors.leftMargin: 12; Text { text: tr("Ник", "Nickname"); color: textMuted; font.pixelSize: 9; Layout.preferredWidth: 180 }; Text { text: tr("Сервер", "Server"); color: textMuted; font.pixelSize: 9; Layout.preferredWidth: 110 }; Text { text: "SteamID64"; color: textMuted; font.pixelSize: 9; Layout.preferredWidth: 180 }; Text { text: tr("Статус", "Status"); color: textMuted; font.pixelSize: 9; Layout.preferredWidth: 100 }; Text { text: tr("Источник сопоставления", "Resolution source"); color: textMuted; font.pixelSize: 9; Layout.fillWidth: true } } }
                                                ListView {
                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true
                                                    clip: true
                                                    model: Math.min(6, appController.results.length)
                                                    delegate: Rectangle {
                                                        width: ListView.view.width
                                                        height: 42
                                                        color: "transparent"
                                                        property var rowData: appController.results[index]
                                                        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: lineSoft }
                                                        RowLayout { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10
                                                            Row { Layout.preferredWidth: 180; spacing: 7; Rectangle { width: 25; height: 25; radius: 13; color: "#1B2225"; Text { anchors.centerIn: parent; text: rowData ? String(rowData.nickname).charAt(0).toUpperCase() : "?"; color: textSecondary; font.pixelSize: 10 } }; Text { text: rowData ? rowData.nickname : ""; color: textSecondary; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter } }
                                                            Row { Layout.preferredWidth: 110; spacing: 5; Image { source: Qt.resolvedUrl("../assets/Games/CS2.jpg"); width: 18; height: 18 }; Text { text: "CS2"; color: textMuted; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter } }
                                                            Text { text: rowData ? rowData.steam_id64 : "—"; color: textMuted; font.pixelSize: 9; Layout.preferredWidth: 180 }
                                                            StatusDot { Layout.preferredWidth: 100; text: tr("Найден", "Found"); dotColor: green }
                                                            Text { text: tr("Точный матч", "Exact match"); color: textMuted; font.pixelSize: 9; Layout.fillWidth: true }
                                                        }
                                                    }
                                                    Text { visible: appController.results.length === 0; anchors.centerIn: parent; text: tr("Поток появится после обнаружения игроков", "The stream will appear after players are discovered"); color: textMuted; font.pixelSize: 11 }
                                                }
                                            }
                                        }

                                        Card {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            ColumnLayout {
                                                anchors.fill: parent
                                                spacing: 0
                                                RowLayout { Layout.fillWidth: true; Layout.preferredHeight: 46; Layout.leftMargin: 14; Layout.rightMargin: 12; Text { text: "▣"; color: accent; font.pixelSize: 18 }; Text { text: tr("Журнал событий", "Event log"); color: textPrimary; font.pixelSize: 15; font.weight: Font.DemiBold }; Item { Layout.fillWidth: true }; GhostButton { text: tr("Все уровни", "All levels"); buttonHeight: 29 } }
                                                Divider { Layout.fillWidth: true }
                                                Repeater {
                                                    model: [
                                                        {time:clockText, level:"INFO", service:"A2S", message:appController.onlineServers > 0 ? tr("Серверы отвечают на запросы", "Servers are responding") : tr("Ожидание активных серверов", "Waiting for active servers"), color:blue},
                                                        {time:clockText, level:"INFO", service:"Resolver", message:appController.steamApiConfigured ? tr("Steam Web API ключ настроен", "Steam Web API key configured") : tr("Работа без Steam Web API ключа", "Working without Steam Web API key"), color:appController.steamApiConfigured ? green : warning},
                                                        {time:clockText, level:"INFO", service:"Cache", message:tr("SQLite кэш доступен", "SQLite cache is available"), color:green},
                                                        {time:clockText, level:"INFO", service:"Scanner", message:appController.monitoring ? tr("Мониторинг выполняется", "Monitoring is running") : tr("Мониторинг остановлен", "Monitoring stopped"), color:appController.monitoring ? green : warning}
                                                    ]
                                                    delegate: Rectangle {
                                                        required property var modelData
                                                        Layout.fillWidth: true
                                                        Layout.fillHeight: true
                                                        color: "transparent"
                                                        RowLayout { anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 12; Text { text: modelData.time; color: textMuted; font.pixelSize: 9; Layout.preferredWidth: 62 }; Text { text: "● " + modelData.level; color: modelData.color; font.pixelSize: 9; Layout.preferredWidth: 76 }; Text { text: modelData.service; color: textMuted; font.pixelSize: 9; Layout.preferredWidth: 86 }; Text { text: modelData.message; color: textSecondary; font.pixelSize: 9; Layout.fillWidth: true } }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        Layout.preferredWidth: 2
                                        spacing: 12
                                        Card {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 310
                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.margins: 14
                                                spacing: 10
                                                RowLayout { Layout.fillWidth: true; Text { text: "⌕"; color: accent; font.pixelSize: 20 }; Text { text: tr("Проверка SteamID вручную", "Manual SteamID check"); color: textPrimary; font.pixelSize: 15; font.weight: Font.DemiBold }; Item { Layout.fillWidth: true }; Text { text: "?"; color: textMuted; font.pixelSize: 18 } }
                                                Text { text: tr("Введите SteamID64, ссылку на профиль или ник игрока", "Enter SteamID64, profile URL or player nickname"); color: textMuted; font.pixelSize: 10 }
                                                RowLayout { Layout.fillWidth: true; Field { id: manualSteam; Layout.fillWidth: true; placeholderText: "76561198012345678" }; PrimaryButton { text: tr("Проверить", "Check"); onClicked: { if (manualSteam.text.length > 0) Qt.openUrlExternally(manualSteam.text.indexOf("http") === 0 ? manualSteam.text : "https://steamcommunity.com/profiles/" + manualSteam.text) } } }
                                                SoftCard { Layout.fillWidth: true; Layout.fillHeight: true; ColumnLayout { anchors.fill: parent; anchors.margins: 12; spacing: 8; Text { text: tr("Ручная проверка", "Manual check"); color: textSecondary; font.pixelSize: 13; font.weight: Font.DemiBold }; Text { text: tr("Для SteamID64 кнопка откроет профиль Steam. Автоматический анализ инвентаря выполняется основным мониторингом.", "For a SteamID64 the button opens the Steam profile. Automatic inventory analysis is handled by monitoring."); color: textMuted; font.pixelSize: 10; wrapMode: Text.WordWrap; Layout.fillWidth: true }; Item { Layout.fillHeight: true }; RowLayout { Layout.fillWidth: true; StatusDot { text: appController.servicesReady ? tr("Сервисы готовы", "Services ready") : tr("Запуск сервисов", "Starting services"); dotColor: appController.servicesReady ? green : warning }; Item { Layout.fillWidth: true }; Text { text: appController.steamApiConfigured ? tr("API ключ: настроен", "API key: configured") : tr("API ключ: не задан", "API key: not set"); color: textMuted; font.pixelSize: 9 } } } }
                                            }
                                        }

                                        Card {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 176
                                            ColumnLayout { anchors.fill: parent; anchors.margins: 14; spacing: 10
                                                RowLayout { Layout.fillWidth: true; Text { text: "▥"; color: accent; font.pixelSize: 18 }; Text { text: tr("Статистика очереди и обработки", "Queue and processing stats"); color: textPrimary; font.pixelSize: 14; font.weight: Font.DemiBold }; Item { Layout.fillWidth: true }; GhostButton { text: tr("Всё время", "All time"); buttonHeight: 28 } }
                                                GridLayout { Layout.fillWidth: true; Layout.fillHeight: true; columns: 2; rowSpacing: 8; columnSpacing: 8
                                                    SoftCard { Layout.fillWidth: true; Layout.fillHeight: true; RowLayout { anchors.fill: parent; anchors.margins: 10; Text { text: "◷"; color: accent; font.pixelSize: 20 }; Column { Text { text: "0"; color: textPrimary; font.pixelSize: 20; font.bold: true }; Text { text: tr("В очереди", "Queued"); color: textMuted; font.pixelSize: 9 } } } }
                                                    SoftCard { Layout.fillWidth: true; Layout.fillHeight: true; RowLayout { anchors.fill: parent; anchors.margins: 10; Text { text: "⚙"; color: accent; font.pixelSize: 20 }; Column { Text { text: appController.monitoring ? String(appController.concurrentScans) : "0"; color: textPrimary; font.pixelSize: 20; font.bold: true }; Text { text: tr("Обрабатывается", "Processing"); color: textMuted; font.pixelSize: 9 } } } }
                                                    SoftCard { Layout.fillWidth: true; Layout.fillHeight: true; RowLayout { anchors.fill: parent; anchors.margins: 10; Text { text: "●"; color: green; font.pixelSize: 20 }; Column { Text { text: String(appController.checkedToday); color: textPrimary; font.pixelSize: 20; font.bold: true }; Text { text: tr("Обработано", "Processed"); color: textMuted; font.pixelSize: 9 } } } }
                                                    SoftCard { Layout.fillWidth: true; Layout.fillHeight: true; RowLayout { anchors.fill: parent; anchors.margins: 10; Text { text: "▲"; color: red; font.pixelSize: 18 }; Column { Text { text: "0"; color: textPrimary; font.pixelSize: 20; font.bold: true }; Text { text: tr("Ошибки", "Errors"); color: textMuted; font.pixelSize: 9 } } } }
                                                }
                                            }
                                        }

                                        Card {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            ColumnLayout { anchors.fill: parent; anchors.margins: 14; spacing: 9
                                                RowLayout { Layout.fillWidth: true; Text { text: "▤"; color: accent; font.pixelSize: 18 }; Text { text: tr("Текущие процессы", "Current processes"); color: textPrimary; font.pixelSize: 14; font.weight: Font.DemiBold }; Item { Layout.fillWidth: true }; GhostButton { text: tr("Показать все", "Show all"); buttonHeight: 28 } }
                                                Repeater { model: [tr("Сканирование инвентарей", "Inventory scanning"), tr("Обновление кэша цен", "Updating price cache"), tr("Проверка серверов (A2S)", "Checking servers (A2S)")]; delegate: RowLayout { required property string modelData; Layout.fillWidth: true; Text { text: "●"; color: appController.monitoring ? green : textMuted; font.pixelSize: 14 }; Text { text: modelData; color: textSecondary; font.pixelSize: 10; Layout.preferredWidth: 180 }; Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 8; radius: 4; color: "#293135"; Rectangle { width: appController.monitoring ? parent.width * 0.82 : 0; height: parent.height; radius: 4; color: green; Behavior on width { NumberAnimation { duration: 300 } } } }; Text { text: appController.monitoring ? "✓" : "—"; color: textMuted; font.pixelSize: 9 } } }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            Flickable {
                                anchors.fill: parent
                                contentWidth: width
                                contentHeight: settingsContent.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                                ColumnLayout {
                                    id: settingsContent
                                    width: parent.width
                                    spacing: 12

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 395
                                        spacing: 12

                                        Card {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            ColumnLayout {
                                                anchors.fill: parent
                                                spacing: 0
                                                RowLayout { Layout.fillWidth: true; Layout.preferredHeight: 56; Layout.leftMargin: 16; Text { text: "⚙"; color: accent; font.pixelSize: 22 }; Text { text: tr("Общие", "General"); color: textPrimary; font.pixelSize: 16; font.weight: Font.DemiBold } }
                                                Divider { Layout.fillWidth: true }
                                                ColumnLayout { Layout.fillWidth: true; Layout.fillHeight: true; Layout.margins: 18; spacing: 16
                                                    RowLayout { Layout.fillWidth: true; Text { text: "◎"; color: textSecondary; font.pixelSize: 18; Layout.preferredWidth: 30 }; Text { text: tr("Язык интерфейса", "Interface language"); color: textSecondary; font.pixelSize: 12; Layout.preferredWidth: 160 }; ComboBox { Layout.fillWidth: true; model: ["🇷🇺  Русский", "🇬🇧  English"]; currentIndex: english ? 1 : 0; onActivated: appController.setLanguage(currentIndex === 1 ? "en" : "ru") } }
                                                    RowLayout { Layout.fillWidth: true; Text { text: "▷"; color: textSecondary; font.pixelSize: 19; Layout.preferredWidth: 30 }; Text { text: tr("Запуск приложения", "App startup"); color: textSecondary; font.pixelSize: 12; Layout.preferredWidth: 160 }; ComboBox { Layout.fillWidth: true; model: [tr("Показывать главное окно", "Show main window")]; } }
                                                    RowLayout { Layout.fillWidth: true; Text { text: "▣"; color: textSecondary; font.pixelSize: 18; Layout.preferredWidth: 30 }; Text { text: tr("Сворачивать в трей", "Minimize to tray"); color: textSecondary; font.pixelSize: 12; Layout.preferredWidth: 160 }; ToggleSwitch { checked: true; caption: tr("При закрытии окна сворачивать в трей", "Minimize to tray when closing") }; Item { Layout.fillWidth: true } }
                                                    RowLayout { Layout.fillWidth: true; Text { text: "◉"; color: textSecondary; font.pixelSize: 18; Layout.preferredWidth: 30 }; Text { text: tr("Тема оформления", "Theme"); color: textSecondary; font.pixelSize: 12; Layout.preferredWidth: 160 }; Item { Layout.fillWidth: true } }
                                                    RowLayout { Layout.fillWidth: true; Layout.leftMargin: 190; spacing: 12
                                                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 86; radius: 8; color: "#171C1E"; border.width: 2; border.color: accent; Column { anchors.fill: parent; anchors.margins: 8; spacing: 5; Rectangle { width: parent.width; height: 45; radius: 4; color: "#0D1113"; border.color: "#2A3236"; Rectangle { x: 7; y: 7; width: 18; height: 31; color: "#171D20" }; Rectangle { x: 32; y: 7; width: parent.width - 39; height: 12; color: "#20272A" }; Rectangle { x: 32; y: 25; width: parent.width - 39; height: 13; color: "#151A1D" } }; Text { text: "● " + tr("Тёмная", "Dark"); color: accent; font.pixelSize: 10 } }; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: appController.requestTheme("dark") } }
                                                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 86; radius: 8; color: "#151A1D"; border.color: line; opacity: 0.78; Column { anchors.fill: parent; anchors.margins: 8; spacing: 5; Rectangle { width: parent.width; height: 45; radius: 4; color: "#DDE0E2"; Rectangle { x: 7; y: 7; width: 18; height: 31; color: "#1A2023" }; Rectangle { x: 32; y: 7; width: parent.width - 39; height: 12; color: "#2A3033" }; Rectangle { x: 32; y: 25; width: parent.width - 39; height: 13; color: "#F1F2F3" } }; Text { text: tr("Системная", "System"); color: textSecondary; font.pixelSize: 10 } }; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: appController.requestTheme("system") } }
                                                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 86; radius: 8; color: "#E5E7E8"; border.color: line; opacity: 0.72; Column { anchors.fill: parent; anchors.margins: 8; spacing: 5; Rectangle { width: parent.width; height: 45; radius: 4; color: "#F9FAFA"; Rectangle { x: 7; y: 7; width: 18; height: 31; color: "#D0D3D5" }; Rectangle { x: 32; y: 7; width: parent.width - 39; height: 12; color: "#DBDEDF" }; Rectangle { x: 32; y: 25; width: parent.width - 39; height: 13; color: "#F7F8F8" } }; Text { text: tr("Светлая", "Light"); color: "#464D51"; font.pixelSize: 10 } }; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: appController.requestTheme("light") } }
                                                    }
                                                }
                                            }
                                        }

                                        Card {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            ColumnLayout {
                                                anchors.fill: parent
                                                spacing: 0
                                                RowLayout { Layout.fillWidth: true; Layout.preferredHeight: 56; Layout.leftMargin: 16; Text { text: "⌕"; color: accent; font.pixelSize: 22 }; Text { text: tr("Сканирование", "Scanning"); color: textPrimary; font.pixelSize: 16; font.weight: Font.DemiBold } }
                                                Divider { Layout.fillWidth: true }
                                                ColumnLayout { Layout.fillWidth: true; Layout.fillHeight: true; Layout.margins: 18; spacing: 15
                                                    RowLayout { Layout.fillWidth: true; Text { text: "◷"; color: textSecondary; font.pixelSize: 18; Layout.preferredWidth: 30 }; Text { text: tr("Интервал опроса серверов", "Server polling interval"); color: textSecondary; font.pixelSize: 12; Layout.fillWidth: true }; MiniField { id: pollField; text: String(appController.pollInterval); Layout.preferredWidth: 105 }; Text { text: tr("сек", "sec"); color: textMuted; font.pixelSize: 11 } }
                                                    RowLayout { Layout.fillWidth: true; Text { text: "◴"; color: textSecondary; font.pixelSize: 18; Layout.preferredWidth: 30 }; Text { text: tr("Таймаут запроса", "Request timeout"); color: textSecondary; font.pixelSize: 12; Layout.fillWidth: true }; MiniField { id: timeoutField; text: String(appController.requestTimeout); Layout.preferredWidth: 105 }; Text { text: tr("сек", "sec"); color: textMuted; font.pixelSize: 11 } }
                                                    RowLayout { Layout.fillWidth: true; Text { text: "↻"; color: textSecondary; font.pixelSize: 18; Layout.preferredWidth: 30 }; Text { text: tr("Пауза для повторной проверки", "Player recheck delay"); color: textSecondary; font.pixelSize: 12; Layout.fillWidth: true }; MiniField { id: recheckField; text: String(appController.recheckHours); Layout.preferredWidth: 105 }; Text { text: tr("часа", "hours"); color: textMuted; font.pixelSize: 11 } }
                                                    RowLayout { Layout.fillWidth: true; Text { text: "▱"; color: textSecondary; font.pixelSize: 18; Layout.preferredWidth: 30 }; Text { text: tr("Одновременных сканов", "Concurrent scans"); color: textSecondary; font.pixelSize: 12; Layout.fillWidth: true }; MiniField { id: concurrentField; text: String(appController.concurrentScans); Layout.preferredWidth: 105 }; Text { text: tr("потоков", "threads"); color: textMuted; font.pixelSize: 11 } }
                                                    Item { Layout.fillHeight: true }
                                                    PrimaryButton { Layout.alignment: Qt.AlignRight; text: tr("Применить", "Apply"); onClicked: appController.saveScanSettings(parseInt(pollField.text), parseInt(timeoutField.text), parseInt(recheckField.text), parseInt(concurrentField.text)) }
                                                }
                                            }
                                        }

                                        Card {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            ColumnLayout {
                                                anchors.fill: parent
                                                spacing: 0
                                                RowLayout { Layout.fillWidth: true; Layout.preferredHeight: 56; Layout.leftMargin: 16; Text { text: "⌘"; color: accent; font.pixelSize: 22 }; Text { text: tr("Провайдеры", "Providers"); color: textPrimary; font.pixelSize: 16; font.weight: Font.DemiBold } }
                                                Divider { Layout.fillWidth: true }
                                                ColumnLayout { Layout.fillWidth: true; Layout.fillHeight: true; Layout.margins: 14; spacing: 9
                                                    SoftCard { Layout.fillWidth: true; Layout.preferredHeight: 66; RowLayout { anchors.fill: parent; anchors.margins: 10; Rectangle { width: 38; height: 38; radius: 19; color: "#1B5EA5"; Text { anchors.centerIn: parent; text: "S"; color: "white"; font.bold: true; font.pixelSize: 18 } }; Text { text: "Steam Web API"; color: textPrimary; font.pixelSize: 11; Layout.preferredWidth: 112 }; ToggleSwitch { checked: appController.steamApiConfigured }; MiniField { id: keyField; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: tr("API ключ", "API key") }; GhostButton { text: tr("Сохранить", "Save"); buttonHeight: 34; onClicked: appController.saveSteamApiKey(keyField.text) } } }
                                                    SoftCard { Layout.fillWidth: true; Layout.preferredHeight: 66; RowLayout { anchors.fill: parent; anchors.margins: 10; Rectangle { width: 38; height: 38; radius: 19; color: "#1E2730"; Text { anchors.centerIn: parent; text: "C"; color: accent; font.bold: true; font.pixelSize: 18 } }; Text { text: "Steam Community"; color: textPrimary; font.pixelSize: 11; Layout.preferredWidth: 112 }; ToggleSwitch { checked: true }; Text { text: tr("Бесплатный resolver", "Free resolver"); color: textMuted; font.pixelSize: 10; Layout.fillWidth: true }; StatusDot { text: tr("Доступно", "Available"); dotColor: green } } }
                                                    SoftCard { Layout.fillWidth: true; Layout.preferredHeight: 66; RowLayout { anchors.fill: parent; anchors.margins: 10; Rectangle { width: 38; height: 38; radius: 19; color: "#2A2620"; Text { anchors.centerIn: parent; text: "₽"; color: accent; font.bold: true; font.pixelSize: 18 } }; Text { text: "Steam Market"; color: textPrimary; font.pixelSize: 11; Layout.preferredWidth: 112 }; ToggleSwitch { checked: true }; Text { text: tr("Цены CS2 / Dota 2 / Rust", "CS2 / Dota 2 / Rust prices"); color: textMuted; font.pixelSize: 10; Layout.fillWidth: true }; StatusDot { text: tr("Доступно", "Available"); dotColor: green } } }
                                                    SoftCard { Layout.fillWidth: true; Layout.preferredHeight: 66; RowLayout { anchors.fill: parent; anchors.margins: 10; Rectangle { width: 38; height: 38; radius: 19; color: "#3B2A1D"; Text { anchors.centerIn: parent; text: "⚡"; color: accent; font.bold: true; font.pixelSize: 18 } }; Text { text: "A2S Direct"; color: textPrimary; font.pixelSize: 11; Layout.preferredWidth: 112 }; ToggleSwitch { checked: true }; Text { text: tr("Прямой опрос CS2-серверов", "Direct CS2 server queries"); color: textMuted; font.pixelSize: 10; Layout.fillWidth: true }; StatusDot { text: tr("Работает", "Working"); dotColor: green } } }
                                                    Text { text: tr("ⓘ Steam Web API key хранится локально в настройках приложения.", "ⓘ Steam Web API key is stored locally in the app settings."); color: textMuted; font.pixelSize: 9 }
                                                }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 330
                                        spacing: 12
                                        Card {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            Layout.preferredWidth: 1.2
                                            ColumnLayout { anchors.fill: parent; spacing: 0
                                                RowLayout { Layout.fillWidth: true; Layout.preferredHeight: 54; Layout.leftMargin: 16; Text { text: "▼"; color: accent; font.pixelSize: 20 }; Column { Text { text: tr("Фильтры по умолчанию", "Default filters"); color: textPrimary; font.pixelSize: 15; font.weight: Font.DemiBold }; Text { text: tr("Базовые ценовые диапазоны для поиска игроков", "Base price ranges for player search"); color: textMuted; font.pixelSize: 9 } } }
                                                Divider { Layout.fillWidth: true }
                                                GridLayout { Layout.fillWidth: true; Layout.fillHeight: true; Layout.margins: 14; columns: 3; columnSpacing: 10; rowSpacing: 8
                                                    Text { text: "" }
                                                    Text { text: tr("Минимальная цена", "Minimum price"); color: textMuted; font.pixelSize: 9 }
                                                    Text { text: tr("Максимальная цена", "Maximum price"); color: textMuted; font.pixelSize: 9 }
                                                    Row { spacing: 8; Image { source: Qt.resolvedUrl("../assets/Games/CS2.jpg"); width: 34; height: 34 }; Text { text: "CS2"; color: textPrimary; font.pixelSize: 14; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter } }
                                                    MiniField { id: cs2min; text: String(appController.cs2Min); Layout.fillWidth: true }
                                                    MiniField { id: cs2max; text: String(appController.cs2Max); Layout.fillWidth: true }
                                                    Row { spacing: 8; Image { source: Qt.resolvedUrl("../assets/Games/Dota2.jpg"); width: 34; height: 34 }; Text { text: "Dota 2"; color: textPrimary; font.pixelSize: 14; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter } }
                                                    MiniField { id: dotamin; text: String(appController.dotaMin); Layout.fillWidth: true }
                                                    MiniField { id: dotamax; text: String(appController.dotaMax); Layout.fillWidth: true }
                                                    Row { spacing: 8; Image { source: Qt.resolvedUrl("../assets/Games/Rust.jpg"); width: 34; height: 34 }; Text { text: "Rust"; color: textPrimary; font.pixelSize: 14; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter } }
                                                    MiniField { id: rustmin; text: String(appController.rustMin); Layout.fillWidth: true }
                                                    MiniField { id: rustmax; text: String(appController.rustMax); Layout.fillWidth: true }
                                                }
                                            }
                                        }

                                        Card {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            ColumnLayout { anchors.fill: parent; spacing: 0
                                                RowLayout { Layout.fillWidth: true; Layout.preferredHeight: 54; Layout.leftMargin: 16; Text { text: "▤"; color: accent; font.pixelSize: 20 }; Text { text: tr("Данные", "Data"); color: textPrimary; font.pixelSize: 15; font.weight: Font.DemiBold } }
                                                Divider { Layout.fillWidth: true }
                                                ColumnLayout { Layout.fillWidth: true; Layout.fillHeight: true; Layout.margins: 14; spacing: 12
                                                    RowLayout { Layout.fillWidth: true; Text { text: "▱"; color: accent; font.pixelSize: 18 }; Text { text: tr("Путь к данным", "Data path"); color: textSecondary; font.pixelSize: 10; Layout.preferredWidth: 110 }; Field { text: appController.dataDirectory; enabled: false; Layout.fillWidth: true }; GhostButton { text: "□"; buttonHeight: 40 } }
                                                    RowLayout { Layout.fillWidth: true; Text { text: "▱"; color: accent; font.pixelSize: 18 }; Text { text: tr("Файл настроек", "Settings file"); color: textSecondary; font.pixelSize: 10; Layout.preferredWidth: 110 }; Field { text: appController.settingsFile; enabled: false; Layout.fillWidth: true }; GhostButton { text: "□"; buttonHeight: 40 } }
                                                    Text { text: tr("Кэш цен и проверок хранится локально и ускоряет повторные сканирования.", "Price and scan caches are stored locally to speed up repeated checks."); color: textMuted; font.pixelSize: 9; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                                    Item { Layout.fillHeight: true }
                                                    RowLayout { Layout.fillWidth: true; Item { Layout.fillWidth: true }; GhostButton { text: tr("Очистить кэш", "Clear cache"); icon: "⌫"; foreground: red; onClicked: appController.clearCache() } }
                                                }
                                            }
                                        }

                                        Card {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            Layout.preferredWidth: 0.8
                                            ColumnLayout { anchors.fill: parent; spacing: 0
                                                RowLayout { Layout.fillWidth: true; Layout.preferredHeight: 54; Layout.leftMargin: 16; Text { text: "ⓘ"; color: accent; font.pixelSize: 20 }; Text { text: tr("О программе", "About"); color: textPrimary; font.pixelSize: 15; font.weight: Font.DemiBold } }
                                                Divider { Layout.fillWidth: true }
                                                ColumnLayout { Layout.fillWidth: true; Layout.fillHeight: true; Layout.margins: 16; spacing: 9
                                                    RowLayout { Layout.fillWidth: true; Image { source: "https://raw.githubusercontent.com/netrox336-ops/BeaverSearch/main/src/BeaverSearch/Assets/Brand/beaver_logo.png"; Layout.preferredWidth: 78; Layout.preferredHeight: 78; fillMode: Image.PreserveAspectFit }; Column { Text { text: "BeaverSearch"; color: accent; font.pixelSize: 21; font.weight: Font.DemiBold }; Text { text: tr("Версия 0.2.0", "Version 0.2.0"); color: textMuted; font.pixelSize: 10 } } }
                                                    Text { text: tr("BeaverSearch — инструмент для мониторинга игроков на игровых серверах. Находим ценность там, где другие не ищут.", "BeaverSearch monitors players on game servers and evaluates public Steam inventories."); color: textMuted; font.pixelSize: 10; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                                    Divider { Layout.fillWidth: true }
                                                    Text { Layout.alignment: Qt.AlignHCenter; text: tr("БОЛЬШЕ ЧЕМ ПОИСК", "MORE THAN A SEARCH"); color: "#89939A"; font.pixelSize: 11; letterSpacing: 1.5 }
                                                    Text { Layout.alignment: Qt.AlignHCenter; text: "© 2026 BeaverSearch"; color: "#677178"; font.pixelSize: 9 }
                                                    Item { Layout.fillHeight: true }
                                                }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 54
                                        Item { Layout.fillWidth: true }
                                        GhostButton { text: tr("Отмена", "Cancel"); onClicked: appController.showMessage(tr("Изменения не применены", "Changes not applied")) }
                                        GhostButton { text: tr("Применить", "Apply"); onClicked: { appController.saveFilters(parseInt(cs2min.text), parseInt(cs2max.text), parseInt(dotamin.text), parseInt(dotamax.text), parseInt(rustmin.text), parseInt(rustmax.text)); appController.saveScanSettings(parseInt(pollField.text), parseInt(timeoutField.text), parseInt(recheckField.text), parseInt(concurrentField.text)) } }
                                        PrimaryButton { text: tr("Сохранить", "Save"); icon: "✓"; onClicked: { appController.saveFilters(parseInt(cs2min.text), parseInt(cs2max.text), parseInt(dotamin.text), parseInt(dotamax.text), parseInt(rustmin.text), parseInt(rustmax.text)); appController.saveScanSettings(parseInt(pollField.text), parseInt(timeoutField.text), parseInt(recheckField.text), parseInt(concurrentField.text)) } }
                                    }
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
        property string message: ""
        property string kind: "info"
        width: Math.min(520, toastText.implicitWidth + 56)
        height: 52
        x: window.width - width - 28
        y: window.height
        radius: 10
        color: kind === "error" ? "#2B1717" : kind === "ok" ? "#12251E" : "#1A2023"
        border.color: kind === "error" ? "#6E302C" : kind === "ok" ? "#236444" : "#56442F"
        opacity: 0
        z: 1000
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Row { anchors.centerIn: parent; spacing: 10; Text { text: toast.kind === "error" ? "!" : toast.kind === "ok" ? "✓" : "ⓘ"; color: toast.kind === "error" ? red : toast.kind === "ok" ? green : accent; font.pixelSize: 17 }; Text { id: toastText; text: toast.message; color: textPrimary; font.pixelSize: 12 } }
    }
    Timer { id: toastTimer; interval: 3200; onTriggered: { toast.opacity = 0; toast.y = window.height } }

    FileDialog {
        id: exportDialog
        title: tr("Экспорт результатов", "Export results")
        fileMode: FileDialog.SaveFile
        nameFilters: ["Excel (*.xlsx)"]
        defaultSuffix: "xlsx"
        onAccepted: {
            var p = selectedFile.toString()
            if (p.indexOf("file:///") === 0) p = p.substring(8)
            appController.exportResults(decodeURIComponent(p), "xlsx")
        }
    }
}
