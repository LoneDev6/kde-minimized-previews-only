import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.constraintHints: Plasmoid.CanFillArea

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    property var desktopPreviewTasks: []
    readonly property int taskCount: tasksModel.count + desktopPreviewTasks.length
    readonly property real spacing: Math.max(2, Kirigami.Units.smallSpacing)
    readonly property real margin: 3
    readonly property real crossSize: Math.max(24, vertical ? width : height)
    readonly property real thumbnailCrossSize: Math.max(20, crossSize - margin * 2)
    readonly property real thumbnailLongSize: Math.round(thumbnailCrossSize * 1.55)
    readonly property real separatorExtent: taskCount > 0 ? spacing * 2 + 1 : 0
    readonly property real contentExtent: taskCount === 0
        ? 0
        : separatorExtent + taskCount * thumbnailLongSize
            + Math.max(0, taskCount - 1) * spacing + margin * 2

    Layout.minimumWidth: taskCount === 0 ? 0 : (vertical ? crossSize : contentExtent)
    Layout.preferredWidth: taskCount === 0 ? 0.01 : (vertical ? crossSize : contentExtent)
    Layout.maximumWidth: Layout.preferredWidth

    Layout.minimumHeight: taskCount === 0 ? 0 : (vertical ? contentExtent : crossSize)
    Layout.preferredHeight: taskCount === 0 ? 0.01 : (vertical ? contentExtent : crossSize)
    Layout.maximumHeight: Layout.preferredHeight

    TaskManager.ActivityInfo {
        id: activityInfo
    }

    TaskManager.VirtualDesktopInfo {
        id: virtualDesktopInfo
    }

    TaskManager.TasksModel {
        id: tasksModel

        screenGeometry: Plasmoid.containment.screenGeometry
        activity: activityInfo.currentActivity

        filterByCurrentVirtualDesktop: true
        filterByScreen: true
        filterByActivity: true

        // Filter out non-minimized entries, leaving minimized windows only.
        filterNotMinimized: true

        hideActivatedLaunchers: true
        launcherList: []
        separateLaunchers: true
        groupMode: TaskManager.TasksModel.GroupDisabled
        sortMode: TaskManager.TasksModel.SortLastActivated
    }

    TaskManager.TasksModel {
        id: allTasksModel

        filterByCurrentVirtualDesktop: false
        filterByScreen: false
        filterByActivity: false
        hideActivatedLaunchers: true
        launcherList: []
        separateLaunchers: true
        groupMode: TaskManager.TasksModel.GroupDisabled
        sortMode: TaskManager.TasksModel.SortVirtualDesktop
    }

    function rebuildDesktopPreviewTasks() {
        const desktopIds = virtualDesktopInfo.desktopIds;
        const desktopNames = virtualDesktopInfo.desktopNames;
        const currentDesktop = virtualDesktopInfo.currentDesktop;
        const windowsByDesktop = {};

        for (let desktopIndex = 0; desktopIndex < desktopIds.length; ++desktopIndex) {
            windowsByDesktop[String(desktopIds[desktopIndex])] = [];
        }

        for (let row = 0; row < allTasksModel.count; ++row) {
            const modelIndex = allTasksModel.makeModelIndex(row);
            const isWindow = allTasksModel.data(modelIndex, TaskManager.AbstractTasksModel.IsWindow);
            const skipTaskbar = allTasksModel.data(modelIndex, TaskManager.AbstractTasksModel.SkipTaskbar);
            const onAllDesktops = allTasksModel.data(modelIndex, TaskManager.AbstractTasksModel.IsOnAllVirtualDesktops);
            const taskDesktops = allTasksModel.data(modelIndex, TaskManager.AbstractTasksModel.VirtualDesktops) || [];
            if (!isWindow || skipTaskbar || onAllDesktops) {
                continue;
            }

            const activities = allTasksModel.data(modelIndex, TaskManager.AbstractTasksModel.Activities) || [];
            if (activities.length > 0 && !activities.includes(activityInfo.currentActivity)) {
                continue;
            }

            for (const desktopId of taskDesktops) {
                const key = String(desktopId);
                if (windowsByDesktop[key] !== undefined) {
                    windowsByDesktop[key].push(row);
                }
            }
        }

        const nextTasks = [];
        for (let desktopIndex = 0; desktopIndex < desktopIds.length; ++desktopIndex) {
            const desktopId = desktopIds[desktopIndex];
            const rows = windowsByDesktop[String(desktopId)];
            if (String(desktopId) === String(currentDesktop) || rows.length !== 1) {
                continue;
            }

            const row = rows[0];
            const modelIndex = allTasksModel.makeModelIndex(row);
            const winIds = allTasksModel.data(modelIndex, TaskManager.AbstractTasksModel.WinIdList) || [];
            if (!allTasksModel.data(modelIndex, TaskManager.AbstractTasksModel.IsFullScreen)
                    || allTasksModel.data(modelIndex, TaskManager.AbstractTasksModel.IsMinimized)
                    || winIds.length !== 1) {
                continue;
            }

            nextTasks.push({
                row: row,
                desktopId: desktopId,
                desktopName: desktopNames[desktopIndex] || String(desktopId),
                winId: winIds[0],
                title: allTasksModel.data(modelIndex, Qt.DisplayRole) || "",
                appName: allTasksModel.data(modelIndex, TaskManager.AbstractTasksModel.AppName) || "",
                decoration: allTasksModel.data(modelIndex, Qt.DecorationRole)
            });
        }

        const oldIds = desktopPreviewTasks.map(task => `${task.desktopId}:${task.winId}`).join(",");
        const newIds = nextTasks.map(task => `${task.desktopId}:${task.winId}`).join(",");
        if (oldIds !== newIds) {
            console.info(`[MinimizedPreviews] Desktop previews changed: ${oldIds || "none"} -> ${newIds || "none"}`);
        }
        desktopPreviewTasks = nextTasks;
    }

    function scheduleDesktopPreviewRebuild() {
        desktopPreviewRebuildTimer.restart();
    }

    Timer {
        id: desktopPreviewRebuildTimer

        interval: 0
        onTriggered: root.rebuildDesktopPreviewTasks()
    }

    Connections {
        target: allTasksModel

        function onCountChanged() { root.scheduleDesktopPreviewRebuild(); }
        function onDataChanged() { root.scheduleDesktopPreviewRebuild(); }
        function onLayoutChanged() { root.scheduleDesktopPreviewRebuild(); }
        function onModelReset() { root.scheduleDesktopPreviewRebuild(); }
        function onRowsInserted() { root.scheduleDesktopPreviewRebuild(); }
        function onRowsMoved() { root.scheduleDesktopPreviewRebuild(); }
        function onRowsRemoved() { root.scheduleDesktopPreviewRebuild(); }
    }

    Connections {
        target: virtualDesktopInfo

        function onCurrentDesktopChanged() { root.scheduleDesktopPreviewRebuild(); }
        function onDesktopIdsChanged() { root.scheduleDesktopPreviewRebuild(); }
        function onDesktopNamesChanged() { root.scheduleDesktopPreviewRebuild(); }
        function onDesktopPositionsChanged() { root.scheduleDesktopPreviewRebuild(); }
    }

    Connections {
        target: activityInfo

        function onCurrentActivityChanged() { root.scheduleDesktopPreviewRebuild(); }
    }

    Component.onCompleted: scheduleDesktopPreviewRebuild()

    fullRepresentation: Item {
        anchors.fill: parent
        visible: root.taskCount > 0

        Rectangle {
            color: Kirigami.Theme.disabledTextColor
            opacity: 0.45
            radius: 1

            x: root.vertical ? parent.width * 0.2 : root.spacing
            y: root.vertical ? root.spacing : parent.height * 0.2
            width: root.vertical ? parent.width * 0.6 : 1
            height: root.vertical ? 1 : parent.height * 0.6
        }

        Loader {
            anchors.fill: parent
            sourceComponent: root.vertical ? verticalContent : horizontalContent
        }
    }

    Component {
        id: horizontalContent

        Row {
            x: root.separatorExtent + root.margin
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.spacing

            Repeater {
                model: tasksModel

                delegate: MinimizedThumbnail {
                    required property int index
                    required property var model

                    width: root.thumbnailLongSize
                    height: root.thumbnailCrossSize
                    taskIndex: index
                    taskModel: model
                    sourceModel: tasksModel
                }
            }

            Repeater {
                model: root.desktopPreviewTasks

                delegate: MinimizedThumbnail {
                    required property var modelData

                    width: root.thumbnailLongSize
                    height: root.thumbnailCrossSize
                    taskIndex: modelData.row
                    taskModel: modelData
                    sourceModel: allTasksModel
                    desktopId: modelData.desktopId
                    desktopName: modelData.desktopName
                    desktopPreview: true
                }
            }
        }
    }

    Component {
        id: verticalContent

        Column {
            y: root.separatorExtent + root.margin
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.spacing

            Repeater {
                model: tasksModel

                delegate: MinimizedThumbnail {
                    required property int index
                    required property var model

                    width: root.thumbnailCrossSize
                    height: root.thumbnailLongSize
                    taskIndex: index
                    taskModel: model
                    sourceModel: tasksModel
                }
            }

            Repeater {
                model: root.desktopPreviewTasks

                delegate: MinimizedThumbnail {
                    required property var modelData

                    width: root.thumbnailCrossSize
                    height: root.thumbnailLongSize
                    taskIndex: modelData.row
                    taskModel: modelData
                    sourceModel: allTasksModel
                    desktopId: modelData.desktopId
                    desktopName: modelData.desktopName
                    desktopPreview: true
                }
            }
        }
    }
}
