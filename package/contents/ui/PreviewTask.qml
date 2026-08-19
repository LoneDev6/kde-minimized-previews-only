import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.kwindowsystem
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmaCore.ToolTipArea {
    id: root

    required property int taskIndex
    required property var taskModel
    required property var sourceModel
    required property int zoomIndex
    required property Item tasksRoot
    required property Item dockRef
    property bool desktopPreview: false
    property var desktopId
    property string desktopName: ""
    readonly property bool isPreview: true
    readonly property Item previewGeometryItem: previewFrame
    readonly property real baseLongSize: tasksRoot.previewLongSize
    readonly property real _radius: tasksRoot.iconSize * Plasmoid.configuration.amplitud
    readonly property real _zoom: (Plasmoid.configuration.magnification || 0) / 100
    readonly property var modelIndex: sourceModel.makeModelIndex(taskIndex)
    readonly property var winId: desktopPreview
        ? taskModel.winId
        : (taskModel.WinIdList?.length > 0 ? taskModel.WinIdList[0] : undefined)
    readonly property bool thumbnailAvailable: thumbnailLoader.item?.hasThumbnail || false
    property bool completed: false
    property real entryProgress: dockRef.insideDock ? 1.0 : 0.0
    property real zoomFactor: {
        if (_zoom <= 0 || _radius <= 0 || dockRef.smoothMouse < 0
                || dockRef.launchBounceRunning) {
            return 1.0;
        }
        const distance = Math.abs(dockRef.smoothMouse - dockRef.baseItemCenter(zoomIndex));
        const influence = Math.max(0, 1 - distance / _radius);
        if (influence <= 0) {
            return 1.0;
        }
        return 1.0 + _zoom * entryProgress
            * (0.5 - 0.5 * Math.cos(Math.PI * influence));
    }
    readonly property real itemPos: dockRef.itemPosition(zoomIndex)

    width: tasksRoot.vertical ? dockRef.width : baseLongSize * zoomFactor
    height: tasksRoot.vertical ? baseLongSize * zoomFactor : dockRef.height
    x: tasksRoot.vertical ? 0 : itemPos
    y: tasksRoot.vertical ? itemPos : 0
    clip: false
    active: pointer.hovered
    location: Plasmoid.location
    mainText: desktopPreview ? taskModel.title : (taskModel.AppName || "")
    subText: desktopPreview ? desktopName : (taskModel.display || "")

    Behavior on entryProgress {
        enabled: root.completed

        NumberAnimation {
            duration: 140
            easing.type: Easing.OutCubic
        }
    }

    function publishGeometry(): void {
        tasksRoot.publishDelegateGeometry(sourceModel, modelIndex, previewGeometryItem);
    }

    Component.onCompleted: {
        completed = true;
        Qt.callLater(publishGeometry);
    }

    Item {
        id: previewFrame

        HoverHandler {
            id: pointer
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: {
                if (hovered) {
                    if (root.dockRef.suppressedZoomIndex >= 0
                            && root.dockRef.suppressedZoomIndex !== root.zoomIndex) {
                        root.dockRef.suppressedZoomIndex = -1;
                    }
                    Qt.callLater(() => {
                        if (pointer.hovered) {
                            root.showToolTip();
                        }
                    });
                }
            }
        }

        width: tasksRoot.vertical
            ? root.tasksRoot.iconSize * root.zoomFactor
            : root.baseLongSize * root.zoomFactor
        height: tasksRoot.vertical
            ? root.baseLongSize * root.zoomFactor
            : root.tasksRoot.iconSize * root.zoomFactor
        x: {
            if (!tasksRoot.vertical) {
                return (parent.width - width) / 2;
            }
            return tasksRoot.isLeftPanel
                ? tasksRoot.dockBodyCrossCenter - tasksRoot.iconSize / 2
                : tasksRoot.dockBodyCrossCenter + tasksRoot.iconSize / 2 - width;
        }
        y: {
            if (tasksRoot.vertical) {
                return (parent.height - height) / 2;
            }
            return tasksRoot.isTopPanel
                ? tasksRoot.dockBodyCrossCenter - tasksRoot.iconSize / 2
                : tasksRoot.dockBodyCrossCenter + tasksRoot.iconSize / 2 - height;
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
            width: Math.max(16, Math.min(parent.width, parent.height) * 0.34)
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
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: {
            root.publishGeometry();
            if (!root.desktopPreview) {
                root.sourceModel.requestToggleMinimized(root.modelIndex);
            }
            root.sourceModel.requestActivate(root.modelIndex);
        }
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: {
            if (!root.desktopPreview) {
                root.sourceModel.requestClose(root.modelIndex);
            }
        }
    }

}
