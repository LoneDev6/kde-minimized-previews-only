import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.kwindowsystem
import org.kde.plasma.core as PlasmaCore

PlasmaCore.ToolTipArea {
    id: root

    required property int taskIndex
    required property var taskModel
    required property var sourceModel
    property bool desktopPreview: false
    property var desktopId
    property string desktopName: ""

    readonly property var modelIndex: sourceModel.makeModelIndex(taskIndex)
    readonly property var winId: desktopPreview
        ? taskModel.winId
        : (taskModel.WinIdList && taskModel.WinIdList.length > 0
            ? taskModel.WinIdList[0]
            : undefined)
    readonly property bool thumbnailAvailable: thumbnailLoader.item
        && thumbnailLoader.item.hasThumbnail

    mainText: desktopPreview ? taskModel.title : (taskModel.AppName || "")
    subText: desktopPreview
        ? desktopName
        : (taskModel.display || "")

    scale: pointer.hovered ? 1.05 : 1.0

    Behavior on scale {
        NumberAnimation {
            duration: Kirigami.Units.shortDuration
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Math.max(4, Math.min(width, height) * 0.10)
        color: Kirigami.Theme.backgroundColor
        border.width: 1
        border.color: pointer.hovered
            ? Kirigami.Theme.highlightColor
            : Kirigami.Theme.disabledTextColor
        opacity: 0.96
    }

    Item {
        id: thumbnailSourceItem

        readonly property var winId: root.winId

        anchors.fill: parent
        anchors.margins: 2
        clip: true

        Loader {
            id: thumbnailLoader

            anchors.fill: parent
            active: KWindowSystem.isPlatformWayland && thumbnailSourceItem.winId !== undefined
            asynchronous: true
            source: "PipeWireThumbnail.qml"
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height) * 0.55
            height: width
            source: root.taskModel.decoration
            visible: !root.thumbnailAvailable
        }
    }

    Rectangle {
        width: Math.max(16, Math.min(root.width, root.height) * 0.34)
        height: width
        radius: width / 2
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 2
        color: Kirigami.Theme.backgroundColor
        border.width: 1
        border.color: Kirigami.Theme.disabledTextColor

        Kirigami.Icon {
            anchors.fill: parent
            anchors.margins: Math.max(2, parent.width * 0.14)
            source: root.taskModel.decoration
        }
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: {
            if (!root.desktopPreview) {
                root.sourceModel.requestToggleMinimized(root.modelIndex)
            }
            root.sourceModel.requestActivate(root.modelIndex)
        }
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: {
            if (!root.desktopPreview) {
                root.sourceModel.requestClose(root.modelIndex)
            }
        }
    }

    HoverHandler {
        id: pointer
        cursorShape: Qt.PointingHandCursor
    }
}
