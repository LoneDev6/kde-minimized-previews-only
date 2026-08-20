/*
    SPDX-FileCopyrightText: 2013 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2

import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import QtQuick.Layouts

KCMUtils.SimpleKCM {
    id: root

    readonly property list<string> previewKeys: [
        "skinName",
        "iconSize",
        "magnification"
    ]
    property var appliedPreview: ({})
    property bool previewReady: false
    property bool unsavedChanges: false

    function capturePreview(): void {
        const snapshot = {};
        previewKeys.forEach(key => snapshot[key] = root["cfg_" + key]);
        appliedPreview = snapshot;
        unsavedChanges = false;
    }

    function updatePreview(key: string): void {
        if (!previewReady) {
            return;
        }
        Plasmoid.configuration[key] = root["cfg_" + key];
        unsavedChanges = previewKeys.some(previewKey =>
            String(root["cfg_" + previewKey]) !== String(appliedPreview[previewKey]));
    }

    function saveConfig(): void {
        capturePreview();
    }

    function restorePreview(): void {
        if (!previewReady) {
            return;
        }
        previewKeys.forEach(key => Plasmoid.configuration[key] = appliedPreview[key]);
    }

    // Probes whether PulseAudio.qml (which imports org.kde.plasma.private.volume)
    // can load; controls whether the audio-stream config options are enabled.
    Component {
        id: pulseAudioProbe
        PulseAudio {}
    }
    readonly property bool plasmaPaAvailable: pulseAudioProbe.status === Component.Ready
    readonly property bool plasmoidVertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool iconOnly: Plasmoid.pluginName === "org.vicko.wavetask"

    property alias cfg_showToolTips: showToolTips.checked
    property alias cfg_highlightWindows: highlightWindows.checked
    property bool cfg_indicateAudioStreams
    property bool cfg_interactiveMute
    property bool cfg_tooltipControls
    property alias cfg_taskMaxWidth: taskMaxWidth.currentIndex
    property int cfg_iconSpacing: 0
    // wavetask
    property alias cfg_iconSize: iconSizeSlider.value
    property alias cfg_magnification: magnificationSlider.value
    property string cfg_skinName: Plasmoid.configuration.skinName === "Light" ? "Light" : "Dark"

    Component.onCompleted: {
        capturePreview();
        previewKeys.forEach(key =>
            root["cfg_" + key + "Changed"].connect(() => updatePreview(key)));
        previewReady = true;
    }
    Component.onDestruction: restorePreview()
    Kirigami.FormLayout {

        QQC2.ComboBox {
            id: skinChooser
            Kirigami.FormData.label: "Skin:"
            model: ["Dark", "Light"]
            currentIndex: cfg_skinName === "Light" ? 1 : 0
            onActivated: index => cfg_skinName = model[index]
        }
        // --- Selector de Tamaño de Iconos ---
        RowLayout {
            Kirigami.FormData.label: "Size:"
            spacing: Kirigami.Units.smallSpacing

            QQC2.Slider {
                id: iconSizeSlider
                Layout.fillWidth: true

                from: 32
                to: 64
                stepSize: 2
                snapMode: QQC2.Slider.SnapOnRelease

                // El valor inicial vendrá de la configuración de Plasma
                value: Plasmoid.configuration.iconSize || 44
            }

            QQC2.Label {
                text: Math.floor(iconSizeSlider.value) + "px"
                font.family: "Monospace"
                color: Kirigami.Theme.disabledTextColor
                Layout.preferredWidth: Kirigami.Units.gridUnit * 2
            }
        }
        // --- Selector de Tamaño de Zoom ---
        RowLayout {
            Kirigami.FormData.label: "Zoom Percentage:"
            spacing: Kirigami.Units.smallSpacing

            QQC2.Slider {
                id: magnificationSlider
                Layout.fillWidth: true
                from: 0
                to: 100
                stepSize: 5
                snapMode: QQC2.Slider.SnapOnRelease
                // El valor inicial viene de la configuración (ej: 90% -> 0.9)
                value: Plasmoid.configuration.magnification || 50
            }
            QQC2.Label {
                text: Math.floor(magnificationSlider.value) + "%"
                font.family: "Monospace"
                color: Kirigami.Theme.disabledTextColor
                Layout.preferredWidth: Kirigami.Units.gridUnit * 2
            }
        }

        QQC2.CheckBox {
            id: showToolTips
            Kirigami.FormData.label: i18nc("@label for several checkboxes", "General:")
            text: i18nc("@option:check section General", "Show small window previews when hovering over tasks")
        }

        QQC2.CheckBox {
            id: highlightWindows
            text: showToolTips.checked ? i18nc("@option:check section General", "Hide other windows when hovering over previews") : i18nc("@option:check section General", "Hide other windows when hovering over tooltips")
        }

        QQC2.CheckBox {
            id: indicateAudioStreams
            text: i18nc("@option:check section General", "Show an indicator when a task is playing audio")
            checked: root.cfg_indicateAudioStreams && root.plasmaPaAvailable
            onToggled: root.cfg_indicateAudioStreams = checked
            enabled: root.plasmaPaAvailable
        }

        QQC2.CheckBox {
            id: interactiveMute
            leftPadding: mirrored ? 0 : (indicateAudioStreams.indicator.width + indicateAudioStreams.spacing)
            rightPadding: mirrored ? (indicateAudioStreams.indicator.width + indicateAudioStreams.spacing) : 0
            text: i18nc("@option:check section General", "Mute task when clicking indicator")
            checked: root.cfg_interactiveMute && root.plasmaPaAvailable
            onToggled: root.cfg_interactiveMute = checked
            enabled: indicateAudioStreams.checked && root.plasmaPaAvailable
        }

        QQC2.CheckBox {
            id: tooltipControls
            text: i18nc("@option:check section General", "Show media and volume controls in tooltip")
            checked: root.cfg_tooltipControls && root.plasmaPaAvailable
            onToggled: root.cfg_tooltipControls = checked
            enabled: root.plasmaPaAvailable
        }

        Item {
            Kirigami.FormData.isSection: true
            visible: !root.iconOnly
        }

        QQC2.ComboBox {
            id: taskMaxWidth
            visible: !root.iconOnly && !root.plasmoidVertical

            Kirigami.FormData.label: i18nc("@label:listbox", "Maximum task width:")

            model: [
                i18nc("@item:inlistbox how wide a task item should be", "Narrow"),
                i18nc("@item:inlistbox how wide a task item should be", "Medium"),
                i18nc("@item:inlistbox how wide a task item should be", "Wide")
            ]
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.ComboBox {
            visible: root.iconOnly
            Kirigami.FormData.label: i18nc("@label:listbox", "Spacing between icons:")

            model: [
                {
                    "label": i18nc("@item:inlistbox Icon spacing", "Small"),
                    "spacing": 0
                },
                {
                    "label": i18nc("@item:inlistbox Icon spacing", "Normal"),
                    "spacing": 1
                },
                {
                    "label": i18nc("@item:inlistbox Icon spacing", "Large"),
                    "spacing": 3
                },
            ]

            textRole: "label"
            enabled: !Kirigami.Settings.tabletMode

            currentIndex: {
                if (Kirigami.Settings.tabletMode) {
                    return 2; // Large
                }

                switch (root.cfg_iconSpacing) {
                    case 0: return 0; // Small
                    case 1: return 1; // Normal
                    case 3: return 2; // Large
                }
            }
            onActivated: index => {
                root.cfg_iconSpacing = model[currentIndex]["spacing"];
            }
        }

        QQC2.Label {
            visible: Kirigami.Settings.tabletMode
            text: i18nc("@info:usagetip under a set of radio buttons when Touch Mode is on", "Automatically set to Large when in Touch mode")
            font: Kirigami.Theme.smallFont
        }

    }
}
