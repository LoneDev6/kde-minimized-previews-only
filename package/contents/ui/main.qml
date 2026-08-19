/*
    SPDX-FileCopyrightText: 2012-2016 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.ksvg as KSvg
import org.kde.plasma.private.mpris as Mpris
import org.kde.kirigami as Kirigami

import org.kde.plasma.workspace.trianglemousefilter

import org.kde.taskmanager as TaskManager
import org.vicko.wavetask as TaskManagerApplet
import org.kde.plasma.workspace.dbus as DBus

import "code/LayoutMetrics.js" as LayoutMetrics
import "code/TaskTools.js" as TaskTools

PlasmoidItem {
    id: tasks

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.userBackgroundHints: PlasmaCore.Types.NoBackground

    // For making a bottom to top layout since qml flow can't do that.
    // We just hang the task manager upside down to achieve that.
    // This mirrors the tasks and group dialog as well, so we un-rotate them
    // to fix that (see Task.qml and GroupDialog.qml).
    rotation: Plasmoid.configuration.reverseMode && Plasmoid.formFactor === PlasmaCore.Types.Vertical ? 180 : 0

    readonly property bool shouldShrinkToZero: zoomItemCount === 0
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property real iconSize: Plasmoid.configuration.iconSize
    readonly property real dockCrossSize: Math.ceil(
        iconSize * (1.0 + (Plasmoid.configuration.magnification || 0) / 100)
        + Kirigami.Units.smallSpacing * 4
    )
    readonly property bool iconsOnly: Plasmoid.pluginName === "org.vicko.wavetask"
        || Plasmoid.pluginName === "beer.devs.peardock"

    property Task toolTipOpenedByClick
    property Task toolTipAreaItem

    readonly property Component contextMenuComponent: Qt.createComponent("ContextMenu.qml")
    readonly property Component pulseAudioComponent: Qt.createComponent("PulseAudio.qml")

    property alias taskList: taskList
    property alias taskRepeater: taskRepeater
    property alias minimizedPreviewRepeater: minimizedPreviewRepeater
    property alias desktopPreviewRepeater: desktopPreviewRepeater
    property var desktopPreviewTasks: []
    readonly property int previewCount: minimizedPreviewRepeater.count + desktopPreviewRepeater.count
    readonly property int zoomItemCount: taskRepeater.count + previewCount
    readonly property real previewLongSize: Math.round(tasks.iconSize * 1.55)

    function zoomItemAt(index) {
        if (index < taskRepeater.count) {
            return taskRepeater.itemAt(index);
        }
        index -= taskRepeater.count;
        if (index < minimizedPreviewRepeater.count) {
            return minimizedPreviewRepeater.itemAt(index);
        }
        return desktopPreviewRepeater.itemAt(index - minimizedPreviewRepeater.count);
    }

    function scheduleDesktopPreviewRebuild() {
        desktopPreviewRebuildTimer.restart();
    }

    readonly property bool metaKeyHeld: backend.metaKeyHeld
    readonly property bool metaFeaturesEnabled: Plasmoid.configuration.showOnMetaKey
                                                || Plasmoid.configuration.showTaskNumbersOnMeta

    // --- META KEY DOCK VISIBILITY ---
    property bool metaShowActive: false

    // Reset timer: hides dock and numbers after Meta is no longer detected
    Timer {
        id: metaResetTimer
        interval: 500
        repeat: false
        onTriggered: {
            console.log("QML: metaResetTimer fired, hiding dock/numbers");
            tasks.metaShowActive = false;
        }
    }

    // Refresh timer: while Meta is still held, keep restarting the reset timer
    Timer {
        id: metaRefreshTimer
        interval: 200
        repeat: true
        running: tasks.metaShowActive
        onTriggered: {
            if (backend.metaKeyHeld) {
                metaResetTimer.restart();
            }
        }
    }

    Connections {
        target: backend
        function onMetaKeyHeldChanged() {
            console.log("QML: onMetaKeyHeldChanged, held=" + backend.metaKeyHeld);
            if (backend.metaKeyHeld && Plasmoid.configuration.showOnMetaKey) {
                tasks.metaShowActive = true;
                metaResetTimer.restart();
            }
        }
    }

    readonly property bool isTopPanel: Plasmoid.location === PlasmaCore.Types.TopEdge
    readonly property bool isLeftPanel: Plasmoid.location === PlasmaCore.Types.LeftEdge
    readonly property Item panelViewItem: containmentItem?.parent?.parent ?? null
    readonly property bool panelOverlapped: panelViewItem?.touchingWindow ?? false
    readonly property bool panelEditing:
        (Plasmoid.containment?.userConfiguring ?? false)
        || (Plasmoid.containment?.corona?.editMode ?? false)
    readonly property real dockBodyLongSize: Math.max(1,
        taskList.baseContentSize + taskList.spacing * 2)
    readonly property real dockBodyCrossSize: Math.max(1,
        tasks.iconSize + Math.ceil(tasks.iconSize * 0.10) * 2)
    readonly property rect dockBodyGeometry: tasks.vertical
        ? Qt.rect(
            dockWindow.x + (dockWindow.width - dockBodyCrossSize) / 2,
            dockWindow.y + (dockWindow.height - dockBodyLongSize) / 2,
            dockBodyCrossSize,
            dockBodyLongSize)
        : Qt.rect(
            dockWindow.x + (dockWindow.width - dockBodyLongSize) / 2,
            dockWindow.y + (tasks.isTopPanel ? 0 : dockWindow.height - dockBodyCrossSize),
            dockBodyLongSize,
            dockBodyCrossSize)

    readonly property bool dockCovered: coveringWindowsModel.count > 0
    property bool edgeReveal: false

    preferredRepresentation: fullRepresentation

  //  Plasmoid.constraintHints: Plasmoid.CanFillArea

  // --- LÓGICA DE TRANSPARENCIA ---
  property Item containmentItem: null
  readonly property int depth: 14
  property bool isBackgroundDisabled: true

  function lookForContainer(object, tries) {
      if (tries === 0 || object === null) return;
      if (object.toString().indexOf("BasicAppletContainer") > -1 && object.background) {
          object.background.visible = false;
          object.opacity = 0;
      }
      // busca el panel
      if (object.toString().indexOf("ContainmentItem_QML") > -1) {
          tasks.containmentItem = object;
          console.log("Contenedor encontrado en el intento: " + (depth - tries));
          console.log("containment width:", tasks.containmentItem.width)
          console.log("containment height:", tasks.containmentItem.height)

      } else {
          lookForContainer(object.parent, tries - 1);
      }
  }

  function applyBackgroundHint() {
      if (tasks.containmentItem === null) lookForContainer(tasks.parent, depth);
      if (tasks.containmentItem === null) return;

      // Aplicamos el NoBackground (0) o Default (1)
      tasks.Plasmoid.backgroundHints = PlasmaCore.Types.NoBackground;
      tasks.Plasmoid.userBackgroundHints = PlasmaCore.Types.NoBackground;
  }

  // --- LÓGICA DE SKINS ---
  property int topoutimage: 0
  property var skinParams: ({
      imageTop: "", imageBottom: "", imageLeft: "", imageRight: "", imagetask: "", blur: false, blurRadius: 18, positionTaskIndicator: 9,
      left: 0, top: 0, right: 0, bottom: 0,
      outLeft: 0, outTop: 0, outRight: 0, outBottom: 0
  })

  function loadSkinConfig() {
      let skinName = Plasmoid.configuration.skinName || "Default Plasma";

      // LIMPIAR BLUR ANTES DE CAMBIAR
      if (tasks.backend && dockWindow) {
          backend.setBlurBehind(dockWindow, false, 0, 0, 0, 0, 0);
          dockWindow.requestUpdate();
          console.log("Blur limpiado antes de aplicar nuevo skin");
      }

      // Construimos la ruta al nuevo archivo Config.qml
      let configUrl = Qt.resolvedUrl("../skins/" + skinName + "/Config.qml");

      console.log("Cargando configuración de skin desde: " + configUrl);

      let component = Qt.createComponent(configUrl);

      if (tasks.iconSize <= 44) {
          tasks.topoutimage = Math.abs(tasks.iconSize - 44);
      } else {
          tasks.topoutimage = 44 - tasks.iconSize;
      }

      if (component.status === Component.Ready) {
          let config = component.createObject(tasks); // 'tasks' es el id de tu PlasmoidItem

          if (config) {
              let skinFolderUrl = Qt.resolvedUrl("../skins/" + skinName + "/").toString();

              // Actualizamos skinParams de forma reactiva
              tasks.skinParams = {
                  imageTop: skinFolderUrl + config.imageTop,
                  imageBottom: skinFolderUrl + config.imageBottom,
                  imageLeft: skinFolderUrl + config.imageLeft,
                  imageRight: skinFolderUrl + config.imageRight,
                  image: skinFolderUrl + config.image,
                  imagetask: skinFolderUrl + config.imagetask,
                  blur: config.blur,
                  blurRadius: config.blurRadius,
                  positionTaskIndicator: config.positionTaskIndicator,
                  left: config.leftMargin,
                  top: config.topMargin,
                  right: config.rightMargin,
                  bottom: config.bottomMargin,
                  outLeft: config.outsideLeftMargin,
                  outTop: config.outsideTopMargin + tasks.topoutimage,
                  outRight: config.outsideRightMargin,
                  outBottom: config.outsideBottomMargin
              };

              console.log("EXITO: Skin '" + skinName + "' cargada. Imagen: " + tasks.skinParams.image);

              // Limpiamos el objeto temporal de memoria
              config.destroy();
          }
      } else {
          console.log("ERROR al cargar Config.qml: " + component.errorString());
          // Fallback: Si no existe el .qml, podrías intentar cargar valores por defecto aquí
      }
  }

  // Detecta si entra zoom y si sale
  readonly property bool isZoomActive: {
      for (let i = 0; i < zoomItemCount; ++i) {
          let item = zoomItemAt(i);
          // Si el zoomFactor es mayor a 1.0 (o un umbral mínimo como 1.01)
          if (item && item.zoomFactor > 1.01) return true;
      }
      return false;
  }

    Plasmoid.onUserConfiguringChanged: {
        if (Plasmoid.userConfiguring && groupDialog !== null) {
            groupDialog.visible = false;
        }
    }

    Layout.fillWidth: vertical ? true : Plasmoid.configuration.fill
    Layout.fillHeight: !vertical ? true : Plasmoid.configuration.fill
    Layout.minimumWidth: {
        if (shouldShrinkToZero) {
            return Kirigami.Units.gridUnit;
        }
        return vertical ? 0 : LayoutMetrics.preferredMinWidth();
    }
    Layout.minimumHeight: {
        if (shouldShrinkToZero) {
            return Kirigami.Units.gridUnit;
        }
        return !vertical ? 0 : LayoutMetrics.preferredMinHeight();
    }
    Layout.preferredWidth: {
        if (shouldShrinkToZero) {
            return 0.01;
        }
        if (vertical) {
            return Kirigami.Units.gridUnit * 10;
        }
        return taskList.Layout.maximumWidth;
    }
    Layout.preferredHeight: {
        if (shouldShrinkToZero) {
            return 0.01;
        }
        if (vertical) {
            return taskList.Layout.maximumHeight;
        }
        return Kirigami.Units.gridUnit * 2;
    }

    property Item dragSource

    signal requestLayout

    onDragSourceChanged: {
        if (dragSource === null) {
            tasksModel.syncLaunchers();
        }
    }

    function windowsHovered(winIds: var, hovered: bool): DBus.DBusPendingReply {
        if (!Plasmoid.configuration.highlightWindows) {
            return;
        }
        return DBus.SessionBus.asyncCall({service: "org.kde.KWin.HighlightWindow", path: "/org/kde/KWin/HighlightWindow", iface: "org.kde.KWin.HighlightWindow", member: "highlightWindows", arguments: [hovered ? winIds : []], signature: "(as)"});
    }

    function cancelHighlightWindows(): DBus.DBusPendingReply {
        return DBus.SessionBus.asyncCall({service: "org.kde.KWin.HighlightWindow", path: "/org/kde/KWin/HighlightWindow", iface: "org.kde.KWin.HighlightWindow", member: "highlightWindows", arguments: [[]], signature: "(as)"});
    }

    function activateWindowView(winIds: var): DBus.DBusPendingReply {
        if (!effectWatcher.registered) {
            return;
        }
        cancelHighlightWindows();
        return DBus.SessionBus.asyncCall({service: "org.kde.KWin.Effect.WindowView1", path: "/org/kde/KWin/Effect/WindowView1", iface: "org.kde.KWin.Effect.WindowView1", member: "activate", arguments: [winIds.map(s => String(s))], signature: "(as)"});
    }

    function publishIconGeometries(taskItems: /*list<Item>*/var): void {
        if (TaskTools.taskManagerInstanceCount >= 2) {
            return;
        }
        for (let i = 0; i < taskItems.length - 1; ++i) {
            const task = taskItems[i];

            if (task.model && !task.model.IsLauncher && !task.model.IsStartup) {
                tasksModel.requestPublishDelegateGeometry(tasksModel.makeModelIndex(task.index),
                    backend.globalRect(task), task);
            }
        }
    }

    readonly property TaskManager.TasksModel tasksModel: TaskManager.TasksModel {
        id: tasksModel

        readonly property int logicalLauncherCount: {
            if (Plasmoid.configuration.separateLaunchers) {
                return launcherCount;
            }

            let startupsWithLaunchers = 0;

            for (let i = 0; i < taskRepeater.count; ++i) {
                const item = taskRepeater.itemAt(i) as Task;

                // During destruction required properties such as item.model can go null for a while,
                // so in paths that can trigger on those moments, they need to be guarded
                if (item?.model?.IsStartup && item.model.HasLauncher) {
                    ++startupsWithLaunchers;
                }
            }

            return launcherCount + startupsWithLaunchers;
        }

        virtualDesktop: virtualDesktopInfo.currentDesktop
        screenGeometry: Plasmoid.containment.screenGeometry
        activity: activityInfo.currentActivity

        filterByVirtualDesktop: Plasmoid.configuration.showOnlyCurrentDesktop
        filterByScreen: Plasmoid.configuration.showOnlyCurrentScreen
        filterByActivity: Plasmoid.configuration.showOnlyCurrentActivity
        filterNotMinimized: Plasmoid.configuration.showOnlyMinimized

        hideActivatedLaunchers: tasks.iconsOnly || Plasmoid.configuration.hideLauncherOnStart
        sortMode: sortModeEnumValue(Plasmoid.configuration.sortingStrategy)
        launchInPlace: tasks.iconsOnly && Plasmoid.configuration.sortingStrategy === 1
        separateLaunchers: {
            if (!tasks.iconsOnly && !Plasmoid.configuration.separateLaunchers
                && Plasmoid.configuration.sortingStrategy === 1) {
                return false;
            }

            return true;
        }

        groupMode: groupModeEnumValue(Plasmoid.configuration.groupingStrategy)
        groupInline: !Plasmoid.configuration.groupPopups && !tasks.iconsOnly
        groupingWindowTasksThreshold: (Plasmoid.configuration.onlyGroupWhenFull && !tasks.iconsOnly
            ? LayoutMetrics.optimumCapacity(tasks.width, tasks.height) + 1 : -1)

        onLauncherListChanged: {
            Plasmoid.configuration.launchers = launcherList;
        }

        onGroupingAppIdBlacklistChanged: {
            Plasmoid.configuration.groupingAppIdBlacklist = groupingAppIdBlacklist;
        }

        onGroupingLauncherUrlBlacklistChanged: {
            Plasmoid.configuration.groupingLauncherUrlBlacklist = groupingLauncherUrlBlacklist;
        }

        function sortModeEnumValue(index: int): /*TaskManager.TasksModel.SortMode*/ int {
            switch (index) {
            case 0:
                return TaskManager.TasksModel.SortDisabled;
            case 1:
                return TaskManager.TasksModel.SortManual;
            case 2:
                return TaskManager.TasksModel.SortAlpha;
            case 3:
                return TaskManager.TasksModel.SortVirtualDesktop;
            case 4:
                return TaskManager.TasksModel.SortActivity;
            // 5 is SortLastActivated, skipped
            case 6:
                return TaskManager.TasksModel.SortWindowPositionHorizontal;
            default:
                return TaskManager.TasksModel.SortDisabled;
            }
        }

        function groupModeEnumValue(index: int): /*TaskManager.TasksModel.GroupMode*/ int {
            switch (index) {
            case 0:
                return TaskManager.TasksModel.GroupDisabled;
            case 1:
                return TaskManager.TasksModel.GroupApplications;
            }
        }

        Component.onCompleted: {
            launcherList = Plasmoid.configuration.launchers;
            groupingAppIdBlacklist = Plasmoid.configuration.groupingAppIdBlacklist;
            groupingLauncherUrlBlacklist = Plasmoid.configuration.groupingLauncherUrlBlacklist;

            // Only hook up view only after the above churn is done.
            taskRepeater.model = tasksModel;
        }
    }

    readonly property TaskManager.TasksModel minimizedTasksModel: TaskManager.TasksModel {
        id: minimizedTasksModel

        virtualDesktop: virtualDesktopInfo.currentDesktop
        screenGeometry: Plasmoid.containment.screenGeometry
        activity: activityInfo.currentActivity
        filterByVirtualDesktop: true
        filterByScreen: true
        filterByActivity: true
        filterNotMinimized: true
        hideActivatedLaunchers: true
        launcherList: []
        separateLaunchers: true
        groupMode: TaskManager.TasksModel.GroupDisabled
        sortMode: TaskManager.TasksModel.SortLastActivated
    }

    readonly property TaskManager.TasksModel allPreviewTasksModel: TaskManager.TasksModel {
        id: allPreviewTasksModel

        filterByCurrentVirtualDesktop: false
        filterByScreen: false
        filterByActivity: false
        hideActivatedLaunchers: true
        launcherList: []
        separateLaunchers: true
        groupMode: TaskManager.TasksModel.GroupDisabled
        sortMode: TaskManager.TasksModel.SortVirtualDesktop
    }

    readonly property TaskManager.TasksModel coveringWindowsModel: TaskManager.TasksModel {
        screenGeometry: Plasmoid.containment.screenGeometry
        regionGeometry: tasks.dockBodyGeometry
        activity: activityInfo.currentActivity
        filterByCurrentVirtualDesktop: true
        filterByActivity: true
        filterByScreen: false
        filterByRegion: TaskManager.RegionFilterMode.Intersect
        filterHidden: true
        filterMinimized: true
        groupMode: TaskManager.TasksModel.GroupDisabled
    }

    function rebuildDesktopPreviewTasks() {
        const desktopIds = virtualDesktopInfo.desktopIds;
        const desktopNames = virtualDesktopInfo.desktopNames;
        const currentDesktop = virtualDesktopInfo.currentDesktop;
        const windowsByDesktop = {};

        for (let desktopIndex = 0; desktopIndex < desktopIds.length; ++desktopIndex) {
            windowsByDesktop[String(desktopIds[desktopIndex])] = [];
        }

        for (let row = 0; row < allPreviewTasksModel.count; ++row) {
            const modelIndex = allPreviewTasksModel.makeModelIndex(row);
            const isWindow = allPreviewTasksModel.data(modelIndex, TaskManager.AbstractTasksModel.IsWindow);
            const skipTaskbar = allPreviewTasksModel.data(modelIndex, TaskManager.AbstractTasksModel.SkipTaskbar);
            const onAllDesktops = allPreviewTasksModel.data(modelIndex, TaskManager.AbstractTasksModel.IsOnAllVirtualDesktops);
            const taskDesktops = allPreviewTasksModel.data(modelIndex, TaskManager.AbstractTasksModel.VirtualDesktops) || [];
            if (!isWindow || skipTaskbar || onAllDesktops) {
                continue;
            }

            const activities = allPreviewTasksModel.data(modelIndex, TaskManager.AbstractTasksModel.Activities) || [];
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
            const modelIndex = allPreviewTasksModel.makeModelIndex(row);
            const winIds = allPreviewTasksModel.data(modelIndex, TaskManager.AbstractTasksModel.WinIdList) || [];
            if (allPreviewTasksModel.data(modelIndex, TaskManager.AbstractTasksModel.IsMinimized)
                    || winIds.length !== 1) {
                continue;
            }

            nextTasks.push({
                row,
                desktopId,
                desktopName: desktopNames[desktopIndex] || String(desktopId),
                winId: winIds[0],
                title: allPreviewTasksModel.data(modelIndex, Qt.DisplayRole) || "",
                decoration: allPreviewTasksModel.data(modelIndex, Qt.DecorationRole)
            });
        }
        desktopPreviewTasks = nextTasks;
    }

    Timer {
        id: desktopPreviewRebuildTimer
        interval: 0
        onTriggered: tasks.rebuildDesktopPreviewTasks()
    }

    Connections {
        target: allPreviewTasksModel
        function onCountChanged() { tasks.scheduleDesktopPreviewRebuild(); }
        function onDataChanged() { tasks.scheduleDesktopPreviewRebuild(); }
        function onLayoutChanged() { tasks.scheduleDesktopPreviewRebuild(); }
        function onModelReset() { tasks.scheduleDesktopPreviewRebuild(); }
        function onRowsInserted() { tasks.scheduleDesktopPreviewRebuild(); }
        function onRowsMoved() { tasks.scheduleDesktopPreviewRebuild(); }
        function onRowsRemoved() { tasks.scheduleDesktopPreviewRebuild(); }
    }

    Connections {
        target: virtualDesktopInfo
        function onCurrentDesktopChanged() { tasks.scheduleDesktopPreviewRebuild(); }
        function onDesktopIdsChanged() { tasks.scheduleDesktopPreviewRebuild(); }
        function onDesktopNamesChanged() { tasks.scheduleDesktopPreviewRebuild(); }
        function onDesktopPositionsChanged() { tasks.scheduleDesktopPreviewRebuild(); }
    }

    Connections {
        target: activityInfo
        function onCurrentActivityChanged() { tasks.scheduleDesktopPreviewRebuild(); }
    }

    readonly property TaskManagerApplet.Backend backend: TaskManagerApplet.Backend {
        id: backend

        onAddLauncher: url => {
            tasks.addLauncher(url);
        }
    }

    DBus.DBusServiceWatcher {
        id: effectWatcher
        busType: DBus.BusType.Session
        watchedService: "org.kde.KWin.Effect.WindowView1"
    }

    readonly property Component taskInitComponent: Component {
        Timer {
            interval: 200
            running: true

            onTriggered: {
                const task = parent as Task;
                if (task) {
                    tasks.tasksModel.requestPublishDelegateGeometry(task.modelIndex(), tasks.backend.globalRect(task), task);
                }
                destroy();
            }
        }
    }

    Connections {
        target: Plasmoid

        function onLocationChanged(): void {
            if (TaskTools.taskManagerInstanceCount >= 2) {
                return;
            }
            // This is on a timer because the panel may not have
            // settled into position yet when the location prop-
            // erty updates.
            console.log(
                "location=", Plasmoid.location,
                "tasks.width=", tasks.width,
                "tasks.height=", tasks.height,
                "taskList.height=", taskList.height,
                "centerOffset=", taskList.centerOffset
            );
            iconGeometryTimer.start();
        }
    }

    Connections {
        target: Plasmoid.containment

        function onScreenGeometryChanged(): void {
            iconGeometryTimer.start();
        }
    }

    Mpris.Mpris2Model {
        id: mpris2Source
    }

    PlasmaCore.Dialog {
        id: dockWindow
        title: "PearDock"

        type: PlasmaCore.Dialog.AppletPopup
        flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus | Qt.NoDropShadowWindowHint
        backgroundHints: PlasmaCore.Dialog.NoBackground
        color: "transparent"
        hideOnWindowDeactivate: false
        visible: tasks.visible
            && (tasks.Window.window?.visible ?? false)
            && !tasks.panelOverlapped
            && (!tasks.dockCovered || tasks.edgeReveal || tasks.metaShowActive)
            && !tasks.panelEditing
        onVisibleChanged: dockSurface.scheduleSizeSync()

        x: {
            const dependency = tasks.x + tasks.width + (tasks.Window.window?.x || 0);
            const globalPosition = tasks.mapToGlobal(0, 0);
            if (!tasks.vertical) {
                if (Plasmoid.location === PlasmaCore.Types.Floating) {
                    const screen = Plasmoid.containment.screenGeometry;
                    return screen.x + (screen.width - width) / 2;
                }
                return globalPosition.x + (tasks.width - width) / 2;
            }
            return tasks.vertical && !tasks.isLeftPanel
                ? globalPosition.x + tasks.width - width + Kirigami.Units.smallSpacing
                : globalPosition.x;
        }
        y: {
            const dependency = tasks.y + tasks.height + (tasks.Window.window?.y || 0);
            const globalPosition = tasks.mapToGlobal(0, 0);
            if (!tasks.vertical && Plasmoid.location === PlasmaCore.Types.Floating) {
                const screen = Plasmoid.containment.screenGeometry;
                return screen.y + screen.height - height;
            }
            return !tasks.vertical && !tasks.isTopPanel
                ? globalPosition.y + tasks.height - height + Kirigami.Units.smallSpacing
                : globalPosition.y;
        }

        mainItem: Item {
            id: dockSurface

            implicitWidth: tasks.vertical ? tasks.dockCrossSize : taskList.contentSize
            implicitHeight: tasks.vertical ? taskList.contentSize : tasks.dockCrossSize
            Layout.minimumWidth: implicitWidth
            Layout.preferredWidth: implicitWidth
            Layout.maximumWidth: implicitWidth
            Layout.minimumHeight: implicitHeight
            Layout.preferredHeight: implicitHeight
            Layout.maximumHeight: implicitHeight

            function scheduleSizeSync() {
                dockSizeSyncTimer.restart();
            }

            onImplicitWidthChanged: scheduleSizeSync()
            onImplicitHeightChanged: scheduleSizeSync()
            Component.onCompleted: scheduleSizeSync()

            Timer {
                id: dockSizeSyncTimer
                interval: 20
                onTriggered: {
                    dockSurface.width = dockSurface.implicitWidth;
                    dockSurface.height = dockSurface.implicitHeight;
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: Plasmoid.containment.internalAction("configure").trigger()
            }

        TaskManager.VirtualDesktopInfo {
            id: virtualDesktopInfo
        }

        TaskManager.ActivityInfo {
            id: activityInfo
            readonly property string nullUuid: "00000000-0000-0000-0000-000000000000"
        }

        Loader {
            id: pulseAudio
            sourceComponent: tasks.pulseAudioComponent
            active: tasks.pulseAudioComponent.status === Component.Ready
        }

        Timer {
            id: iconGeometryTimer

            interval: 500
            repeat: false

            onTriggered: {
                tasks.publishIconGeometries(taskList.children, tasks);
            }
        }

        Binding {
            target: Plasmoid
            property: "status"
            value: {
                if (tasks.metaShowActive) {
                    return PlasmaCore.Types.NeedsAttentionStatus;
                }
                if (tasksModel.anyTaskDemandsAttention && Plasmoid.configuration.unhideOnAttention) {
                    return PlasmaCore.Types.NeedsAttentionStatus;
                }
                return PlasmaCore.Types.PassiveStatus;
            }
            restoreMode: Binding.RestoreBinding
        }

        Connections {
            target: Plasmoid.configuration

            function onSkinNameChanged() {
                console.log("Nueva skin detectada: " + Plasmoid.configuration.skinName);
                loadSkinConfig(); // La función que lee el .ini y carga la imagen
            }

            function onIconSizeChanged() {
                loadSkinConfig();
            }

            function onLaunchersChanged(): void {
                tasksModel.launcherList = Plasmoid.configuration.launchers
            }
            function onGroupingAppIdBlacklistChanged(): void {
                tasksModel.groupingAppIdBlacklist = Plasmoid.configuration.groupingAppIdBlacklist;
            }
            function onGroupingLauncherUrlBlacklistChanged(): void {
                tasksModel.groupingLauncherUrlBlacklist = Plasmoid.configuration.groupingLauncherUrlBlacklist;
            }
        }

        Component {
            id: busyIndicator
            PlasmaComponents3.BusyIndicator {}
        }

        // Save drag data
        Item {
            id: dragHelper

            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction | Qt.MoveAction | Qt.LinkAction
            Drag.onDragFinished: dropAction => {
                tasks.dragSource = null;
            }
        }

        KSvg.FrameSvgItem {
            id: taskFrame

            visible: false

            imagePath: tasks.skinParams.imagetask
            prefix: TaskTools.taskPrefix("normal", Plasmoid.location)
        }

        MouseHandler {
            id: mouseHandler

            anchors.fill: parent

            target: taskList

            onUrlsDropped: urls => {
                // If all dropped URLs point to application desktop files, we'll add a launcher for each of them.
                const createLaunchers = urls.every(item => tasks.backend.isApplication(item));

                if (createLaunchers) {
                    urls.forEach(item => addLauncher(item));
                    return;
                }

                if (!hoveredItem) {
                    return;
                }

                // Otherwise we'll just start a new instance of the application with the URLs as argument,
                // as you probably don't expect some of your files to open in the app and others to spawn launchers.
                tasksModel.requestOpenUrls((hoveredItem as Task).modelIndex(), urls);
            }
        }

        ToolTipDelegate {
            id: openWindowToolTipDelegate
            visible: false
        }

        ToolTipDelegate {
            id: pinnedAppToolTipDelegate
            visible: false
        }

        Loader {
            id: backgroundLoader

            anchors.fill: parent
            sourceComponent: (Plasmoid.configuration.skinName === "Default Plasma") ? defaultSkin : customSkin
        }

        // --- Componente 1: DEFAULT (SVG) ---
        Component {
            id: defaultSkin
            Item {
                id: internalCanvas

                readonly property bool vertical: tasks.vertical

                readonly property real horizontalMargins:
                shadowItem.margins.left + shadowItem.margins.right

                readonly property real verticalMargins:
                shadowItem.margins.top + shadowItem.margins.bottom

                readonly property real baseIconsSize: taskList.baseContentSize

                readonly property real verticalOffsetX: -Kirigami.Units.smallSpacing * 0.5


                readonly property real currentGrowth:
                Math.max(
                    0,
                    (taskList.iconsTotalSize + taskList.spacing * 2)
                    - baseIconsSize
                ) / 2

                readonly property real panelThickness:
                tasks.dockBodyCrossSize

                KSvg.FrameSvgItem {
                    id: shadowItem

                    visible: false

                    imagePath: "widgets/panel-background"
                    prefix: "shadow"

                    z: -2

                    width: vertical
                    ? panelThickness + verticalMargins
                    : horizontalMargins + baseIconsSize + (currentGrowth * 2) + Kirigami.Units.smallSpacing * 2


                    height: vertical
                    ? baseIconsSize + (currentGrowth * 2) + verticalMargins
                    : panelThickness + verticalMargins + Kirigami.Units.smallSpacing * 0.2

                    x: {
                        if (!vertical)
                            return (parent.width - width) / 2;

                        if (vertical && Plasmoid.location === PlasmaCore.Types.RightEdge)
                            return (taskList.width - width) - Kirigami.Units.smallSpacing * 0.8;

                        return - (verticalMargins/2 + Kirigami.Units.smallSpacing * 0.9);
                    }


                    y: {
                        if (vertical)
                            return (parent.height - height) / 2;

                        // Panel arriba
                        if (tasks.isTopPanel)
                            return - ((verticalMargins / 2) + Kirigami.Units.smallSpacing * 0.8);

                        // Panel abajo
                        return (taskList.height - height + (verticalMargins / 2)) + Kirigami.Units.smallSpacing * 0.6;
                    }
                }

                Rectangle {
                    id: backgroundItem

                    z: -1
                    radius: Math.min(width, height) * 0.28
                    color: Qt.rgba(
                        Kirigami.Theme.backgroundColor.r,
                        Kirigami.Theme.backgroundColor.g,
                        Kirigami.Theme.backgroundColor.b,
                        0.72)
                    border.width: 1
                    border.color: Qt.rgba(
                        Kirigami.Theme.textColor.r,
                        Kirigami.Theme.textColor.g,
                        Kirigami.Theme.textColor.b,
                        0.16)

                    width: vertical
                    ? panelThickness
                    : baseIconsSize + (currentGrowth * 2) + Kirigami.Units.smallSpacing * 2

                    height: vertical
                    ? baseIconsSize + (currentGrowth * 2)
                    : panelThickness

                    x: {
                        if (!vertical)
                            return (parent.width - width) / 2;

                        if (vertical && Plasmoid.location === PlasmaCore.Types.RightEdge)
                            return taskList.width - width;

                        return 0;
                    }

                    y: {
                        if (vertical)
                            return (parent.height - height) / 2;

                        // Panel arriba
                        if (tasks.isTopPanel)
                            return 0;

                       return taskList.height - height;
                    }

                }
            }
        }

        // --- Componente 2: CUSTOM SKIN ---
        Component {
            id: customSkin
            BorderImage {
                id: dockBackground
                cache: true
                smooth: true
                asynchronous: true
                visible: source.toString() !== ""
                opacity: 1.0
                readonly property real spacing: Kirigami.Units.largeSpacing
                readonly property real topMarginSkin: tasks.containmentItem.height - 76
                readonly property real leftMarginSkin: tasks.containmentItem.width - 76

                property real rightPanelOffset:(tasks.vertical && !tasks.isLeftPanel) ? ((tasks.containmentItem.width / 2) + Kirigami.Units.smallSpacing * 3) : 0

                // Cuánto crecieron los iconos con zoom respecto al base
                readonly property real currentGrowth: Math.max(0, taskList.maxZoom + spacing * 8
                ) / 2

                property real dynamicLeftMargin: tasks.skinParams.outLeft
                + taskList.centerOffset
                - currentGrowth

                property real dynamicRightMargin: tasks.skinParams.outRight
                + taskList.centerOffset
                - currentGrowth

                anchors {
                    fill: parent

                    leftMargin: tasks.vertical
                    ? (tasks.isLeftPanel
                    ? (tasks.skinParams.outBottom || 0)
                    : (tasks.skinParams.outTop + leftMarginSkin || 0)) // <-- CORREGIDO: Se añade aquí para el panel derecho
                    : (dockBackground.dynamicLeftMargin || 0)

                    rightMargin: tasks.vertical
                    ? (tasks.isLeftPanel
                    ? (tasks.skinParams.outTop + leftMarginSkin || 0)
                    : (tasks.skinParams.outBottom || 0)) // <-- CORREGIDO: Se quita de aquí para el panel derecho
                    : (dockBackground.dynamicRightMargin || 0)

                    topMargin: tasks.vertical
                    ? ((tasks.skinParams.outRight || 0)
                    + taskList.centerOffset
                    - currentGrowth)
                    : (tasks.isTopPanel
                    ? (tasks.skinParams.outBottom || 0)
                    : (tasks.skinParams.outTop + topMarginSkin || 0))

                    bottomMargin: tasks.vertical
                    ? ((tasks.skinParams.outLeft || 0)
                    + taskList.centerOffset
                    - currentGrowth)
                    : (tasks.isTopPanel
                    ? (tasks.skinParams.outTop + topMarginSkin || 0)
                    : (tasks.skinParams.outBottom || 0))
                }

              source: {
                  if (tasks.vertical) {
                      return tasks.isLeftPanel
                      ? tasks.skinParams.imageLeft
                      : tasks.skinParams.imageRight;
                  }

                  return tasks.isTopPanel
                  ? tasks.skinParams.imageTop
                  : tasks.skinParams.imageBottom;
              }

                border {
                    left: tasks.vertical
                    ? (tasks.isLeftPanel
                    ? tasks.skinParams.bottom
                    : tasks.skinParams.top)
                    : tasks.skinParams.left

                    top: tasks.vertical
                    ? tasks.skinParams.right
                    : tasks.skinParams.top

                    right: tasks.vertical
                    ? (tasks.isLeftPanel
                    ? tasks.skinParams.top
                    : tasks.skinParams.bottom)
                    : tasks.skinParams.right

                    bottom: tasks.vertical
                    ? tasks.skinParams.left
                    : tasks.skinParams.bottom
                }

                horizontalTileMode: BorderImage.Stretch
                verticalTileMode: BorderImage.Stretch
                z: -1


                // --- INTEGRACIÓN DEL BLUR ---

                // Radio de blur
                readonly property int blurRadius: tasks.skinParams.blurRadius || 24

                // Función centralizada para actualizar el blur
                function updateBlur() {
                    if (!tasks.skinParams.blur) {
                        return;
                    }

                    const win = dockBackground?.Window?.window;

                    if (!win) {
                        return;
                    }

                    // opcional: proteger también visible
                    if (typeof win.visible !== "undefined" && !win.visible) {
                        return;
                    }

                    var pos = mapToItem(null, 0, 0);

                /*    if (tasks.vertical && !tasks.isLeftPanel) {
                        pos = mapToItem(null, - Kirigami.Units.smallSpacing * 3, 0);
                    } */

                    backend.setBlurBehind(
                        win,
                        true,
                        pos.x,
                        pos.y,
                        width,
                        height,
                        blurRadius
                    );

                    if (win.requestUpdate) {
                        win.requestUpdate();
                    }
                }

                // --- CONEXIONES PARA ACTUALIZACIÓN DINÁMICA ---

                // Cuando el componente termina de cargar
                function scheduleBlurUpdate() {
                    Qt.callLater(updateBlur)
                }

                onWidthChanged: scheduleBlurUpdate()
                onHeightChanged: scheduleBlurUpdate()
                onXChanged: scheduleBlurUpdate()
                onYChanged: scheduleBlurUpdate()

                onWindowChanged: scheduleBlurUpdate()

                onVisibleChanged: {
                    if (visible) {
                        scheduleBlurUpdate()
                    }
                }
            }
        }

        TriangleMouseFilter {
            id: tmf
            filterTimeOut: 300
            active: false
            blockFirstEnter: false

            edge: {
                switch (Plasmoid.location) {
                case PlasmaCore.Types.BottomEdge:
                    return Qt.TopEdge;
                case PlasmaCore.Types.TopEdge:
                    return Qt.BottomEdge;
                case PlasmaCore.Types.LeftEdge:
                    return Qt.RightEdge;
                case PlasmaCore.Types.RightEdge:
                    return Qt.LeftEdge;
                default:
                    return Qt.TopEdge;
                }
            }

            LayoutMirroring.enabled: tasks.shouldBeMirrored(Plasmoid.configuration.reverseMode, Application.layoutDirection, tasks.vertical)

            anchors {
                left: parent.left
                top: parent.top
            }

            height: taskList.height
            width: taskList.width

            TaskList {
                id: taskList
                count: tasks.zoomItemCount

                property real smoothMouse: -1
                property real previousWidth: 0
                property bool insideDock: false
                onWidthChanged: {
                    if (!tasks.vertical && insideDock && previousWidth > 0) {
                        smoothMouse += (width - previousWidth) / 2;
                    }
                    previousWidth = width;
                }
                onInsideDockChanged: {
                    if (insideDock) {
                        edgeHideTimer.stop();
                    } else if (tasks.edgeReveal) {
                        edgeHideTimer.restart();
                    }
                }
                property alias animating: taskList.animating
                readonly property real spacing: Kirigami.Units.smallSpacing
                readonly property real _baseSize: tasks.iconSize
                readonly property real _radius: _baseSize * Plasmoid.configuration.amplitud

                readonly property real totalWidth: baseContentSize

                readonly property real _zoom: (Plasmoid.configuration.magnification || 0) / 100
                readonly property real maxZoom: 1.0 + (Plasmoid.configuration.magnification || 0) / 100

                readonly property real baseContentSize:
                    taskRepeater.count * _baseSize
                    + tasks.previewCount * tasks.previewLongSize
                    + Math.max(0, tasks.zoomItemCount - 1) * spacing

                readonly property real zoomExtraSize: _zoom * _radius
                    * (tasks.previewCount > 0 ? tasks.previewLongSize / _baseSize : 1)

                property real contentSize: Math.ceil(baseContentSize + zoomExtraSize + spacing * 4)

               function baseLongSizeAt(index) {
                   return index < taskRepeater.count ? _baseSize : tasks.previewLongSize;
               }

               function baseItemCenter(index) {
                   let position = ((tasks.vertical ? height : width) - baseContentSize) / 2;
                   for (let i = 0; i < index; ++i) {
                       position += baseLongSizeAt(i) + spacing;
                   }
                   return position + baseLongSizeAt(index) / 2;
               }

               readonly property real iconsTotalSize: {
                   let total = 0;

                   for (let i = 0; i < tasks.zoomItemCount; ++i) {
                       let item = tasks.zoomItemAt(i);

                       if (item) {

                           total += tasks.vertical
                           ? item.height
                           : item.width;

                           if (i > 0)
                               total += spacing;
                       }
                   }

                   return total;
               }

               function itemPosition(index) {
                   let position = centerOffset;
                   for (let i = 0; i < index; ++i) {
                       const item = tasks.zoomItemAt(i);
                       position += (item
                           ? (tasks.vertical ? item.height : item.width)
                           : baseLongSizeAt(i)) + spacing;
                   }
                   return position;
               }

               readonly property real centerOffset: {
                   let availableSize = tasks.vertical
                   ? height
                   : width;

                   return (availableSize - iconsTotalSize) / 2;
               }

                Layout.maximumWidth: contentSize
                Layout.maximumHeight: contentSize

                width: {
                    if (tasks.vertical) {
                        return Math.ceil(
                            tasks.iconSize *
                            taskList.maxZoom +
                            spacing * 4
                        );
                    }

                    return contentSize;
                }

                height: {
                    if (tasks.vertical) {
                        return contentSize;
                    }

                    return tasks.dockCrossSize;
                }

                flow: {
                    if (tasks.vertical) {
                        return Plasmoid.configuration.forceStripes ? Grid.LeftToRight : Grid.TopToBottom
                    }
                    return Plasmoid.configuration.forceStripes ? Grid.TopToBottom : Grid.LeftToRight
                }

                onAnimatingChanged: {
                    if (!animating) {
                        tasks.publishIconGeometries(children, tasks);
                    }
                }

                HoverHandler {
                    id: dockHoverHandler

                    onPointChanged: {
                        taskList.smoothMouse = tasks.vertical
                            ? point.position.y
                            : point.position.x

                        taskList.insideDock = true
                    }

                    onHoveredChanged: {
                        if (hovered) {
                            taskList.smoothMouse = tasks.vertical
                                ? point.position.y
                                : point.position.x
                            taskList.insideDock = true;
                        } else {
                            exitTimer.restart();
                        }
                    }
                }

                Timer {
                    id: exitTimer
                    interval: 40
                    repeat: false
                    onTriggered: {
                        if (!dockHoverHandler.hovered) {
                            taskList.insideDock = false;
                        }
                    }
                }

                Repeater {
                    id: taskRepeater
                    model: tasksModel

                    delegate: Task {
                        id: taskItem
                        tasksRoot: tasks
                        dockRef: taskList

                        x: {
                            if (tasks.vertical && tasks.isLeftPanel)
                                return 0;

                            if (tasks.vertical)
                                return (parent.width / 2) - (taskList.spacing * 3);

                            return itemPos;
                        }

                        y: {
                            if (isTopPanel)
                                return  0;

                            if (tasks.vertical)
                                return itemPos;

                            return 0;
                        }

                        property real itemPos: taskList.itemPosition(index)

                        width: tasks.vertical
                        ? tasks.iconSize
                        : (tasks.iconSize * zoomFactor)

                        height: tasks.vertical
                        ? (tasks.iconSize * zoomFactor)
                        : undefined
                    }
                }

                Repeater {
                    id: minimizedPreviewRepeater
                    model: minimizedTasksModel

                    delegate: PreviewTask {
                        required property int index
                        required property var model

                        taskIndex: index
                        taskModel: model
                        sourceModel: minimizedTasksModel
                        zoomIndex: taskRepeater.count + index
                        tasksRoot: tasks
                        dockRef: taskList
                    }
                }

                Repeater {
                    id: desktopPreviewRepeater
                    model: tasks.desktopPreviewTasks

                    delegate: PreviewTask {
                        required property int index
                        required property var modelData

                        taskIndex: modelData.row
                        taskModel: modelData
                        sourceModel: allPreviewTasksModel
                        zoomIndex: taskRepeater.count + minimizedPreviewRepeater.count + index
                        tasksRoot: tasks
                        dockRef: taskList
                        desktopId: modelData.desktopId
                        desktopName: modelData.desktopName
                        desktopPreview: true
                    }
                }
            }
        }

            readonly property Component groupDialogComponent: Qt.createComponent("GroupDialog.qml")
            property GroupDialog groupDialog
        }
    }

    Timer {
        id: edgeHideTimer
        interval: 350
        onTriggered: {
            if (!edgeHoverHandler.hovered && !taskList.insideDock) {
                tasks.edgeReveal = false;
            }
        }
    }

    PlasmaCore.Dialog {
        id: edgeTriggerWindow

        type: PlasmaCore.Dialog.Tooltip
        flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
        backgroundHints: PlasmaCore.Dialog.NoBackground
        color: "transparent"
        hideOnWindowDeactivate: false
        visible: tasks.dockCovered && !tasks.panelEditing
        x: {
            const screen = Plasmoid.containment.screenGeometry;
            return screen.x + (screen.width - width) / 2;
        }
        y: {
            const screen = Plasmoid.containment.screenGeometry;
            return screen.y + screen.height - height;
        }

        mainItem: Item {
            width: tasks.dockBodyLongSize
            height: 3

            HoverHandler {
                id: edgeHoverHandler
                onHoveredChanged: {
                    if (hovered) {
                        edgeHideTimer.stop();
                        tasks.edgeReveal = true;
                    } else {
                        edgeHideTimer.restart();
                    }
                }
            }
        }
    }

    readonly property Component groupDialogComponent: Qt.createComponent("GroupDialog.qml")
    property GroupDialog groupDialog

    readonly property bool supportsLaunchers: true

    function hasLauncher(url: url): bool {
        return tasksModel.launcherPosition(url) !== -1;
    }

    function addLauncher(url: url): void {
        if (Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable) {
            tasksModel.requestAddLauncher(url);
        }
    }

    function removeLauncher(url: url): void {
        if (Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable) {
            tasksModel.requestRemoveLauncher(url);
        }
    }

    // This is called by plasmashell in response to a Meta+number shortcut.
    // TODO: Change type to int
    function activateTaskAtIndex(index: var): void {
        if (typeof index !== "number") {
            return;
        }

        const task = taskRepeater.itemAt(index) as Task;
        if (task) {
            TaskTools.activateTask(task.modelIndex(), task.model, null, task, Plasmoid, this, effectWatcher.registered);
        }
    }

    function createContextMenu(rootTask, modelIndex, args = {}) {
        const initialArgs = Object.assign(args, {
            visualParent: rootTask,
            modelIndex,
            mpris2Source,
            backend,
        });
        return contextMenuComponent.createObject(rootTask, initialArgs);
    }

    function shouldBeMirrored(reverseMode, layoutDirection, vertical): bool {
        // LayoutMirroring is only horizontal
        if (vertical) {
            return layoutDirection === Qt.RightToLeft;
        }

        if (layoutDirection === Qt.LeftToRight) {
            return reverseMode;
        }
        return !reverseMode;
    }

    Component.onCompleted: {
        TaskTools.taskManagerInstanceCount += 1;
        requestLayout.connect(iconGeometryTimer.restart);
        applyBackgroundHint();
        // --- CARGAR SKIN AL INICIAR ---
        loadSkinConfig();
        scheduleDesktopPreviewRebuild();
    }

    Component.onDestruction: {
        TaskTools.taskManagerInstanceCount -= 1;
    }

    // para hacer panel transparente
    Timer {
        id: initializeAppletTimer
        interval: 1200
        repeat: false // Lo hacemos repetir hasta que encuentre el contenedor
        running: true

        property int step: 0
        readonly property int maxStep: 5

        onTriggered: {
            console.log("Intento de transparencia número: " + (step + 1));
            applyBackgroundHint();

            if (tasks.containmentItem !== null || step >= maxStep) {
                stop(); // Se detiene cuando lo logra o alcanza el límite
            }
            step++;
        }
    }
}
