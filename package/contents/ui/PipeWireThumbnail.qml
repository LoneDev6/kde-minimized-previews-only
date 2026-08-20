/*
    SPDX-FileCopyrightText: 2020 Aleix Pol Gonzalez <aleixpol@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import org.kde.pipewire as PipeWire
import org.kde.taskmanager as TaskManager

PipeWire.PipeWireSourceItem {
    id: pipeWireSourceItem

    readonly property alias hasThumbnail: pipeWireSourceItem.ready

    anchors.fill: parent
    nodeId: waylandItem.nodeId
    layer.enabled: ready && width > 0 && height > 0
    layer.smooth: true
    layer.mipmap: true
    layer.textureSize: Qt.size(Math.max(1, Math.ceil(width * 3)),
        Math.max(1, Math.ceil(height * 3)))

    TaskManager.ScreencastingRequest {
        id: waylandItem
        uuid: thumbnailSourceItem.winId
    }
}
