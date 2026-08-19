/*
    SPDX-FileCopyrightText: 2020 Aleix Pol Gonzalez <aleixpol@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

import QtQuick
import org.kde.pipewire as PipeWire
import org.kde.taskmanager as TaskManager

PipeWire.PipeWireSourceItem {
    id: pipeWireSourceItem

    property bool hasThumbnail: false

    anchors.fill: parent
    // Workaround: MemFd trades zero-copy for reliable NVIDIA previews; re-enable DMA-BUF when KPipeWire negotiation is fixed.
    allowDmaBuf: false
    nodeId: waylandItem.nodeId

    onReadyChanged: {
        if (ready) {
            hasThumbnail = true;
        }
    }

    TaskManager.ScreencastingRequest {
        id: waylandItem
        uuid: thumbnailSourceItem.winId
    }
}
