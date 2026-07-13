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
    readonly property int taskCount: tasksModel.count
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
        }
    }
}
