/*
    SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

Item {
    property bool animating: false
    property int flow: Grid.LeftToRight

    property int animationsRunning: 0
    onAnimationsRunningChanged: {
        animating = animationsRunning > 0;
    }

    required property int count

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    // Smallest visible task width; consumed by Task.qml's standalone-icon
    // state to clamp the icon box. Single-pass over `children` avoids the
    // intermediate filtered array of the original `.filter().reduce()`.
    readonly property real minimumWidth: {
        let min = Infinity;
        for (let i = 0; i < children.length; ++i) {
            const item = children[i];
            if (item.visible && item.width > 0 && item.width < min) {
                min = item.width;
            }
        }
        return min;
    }

    readonly property int stripeCount: 1
    readonly property int orthogonalCount: count
    readonly property int rows: vertical ? count : 1
    readonly property int columns: vertical ? 1 : count
}
