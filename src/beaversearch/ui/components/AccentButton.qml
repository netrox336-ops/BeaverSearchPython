import QtQuick
import QtQuick.Controls

Button {
    id: root
    property color accent: "#F4A746"
    implicitHeight: 46
    leftPadding: 20
    rightPadding: 20
    font.pixelSize: 14
    font.weight: Font.DemiBold
    contentItem: Text {
        text: root.text
        color: "#17120B"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font: root.font
    }
    background: Rectangle {
        radius: 9
        color: root.down ? "#D98B31" : root.hovered ? "#FFB65A" : root.accent
        border.color: root.hovered ? "#FFD39B" : "#E39A43"
        Behavior on color { ColorAnimation { duration: 120 } }
    }
}
