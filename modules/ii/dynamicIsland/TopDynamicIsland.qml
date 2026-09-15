pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Scope {
    id: root

    readonly property real frameThickness: (Config.options.bar.showFrame ? Config.options.bar.frameThickness : 0)
    readonly property color frameColor: Appearance.getColorFromName(Config.options.bar.frameColor)

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: islandWindow
            required property var modelData
            screen: modelData

            WlrLayershell.namespace: "quickshell:topDynamicIsland"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            anchors {
                top: true
            }

            implicitWidth: islandContainer.islandWidth + 40
            implicitHeight: islandContainer.targetHeight + 20
            visible: islandContainer.shouldDrop || islandContainer.y > -(islandContainer.targetHeight + 10)

            mask: Region {
                item: islandContainer.shouldDrop ? islandPill : null
            }

            Item {
                id: islandContainer
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top

                // MPRIS Player tracking
                readonly property MprisPlayer player: MprisController.activePlayer
                readonly property bool hasTrack: (player?.trackTitle ?? "").length > 0
                readonly property bool isPlaying: player?.isPlaying ?? false
                readonly property string trackTitle: player?.trackTitle ?? ""
                readonly property string trackArtist: player?.trackArtist ?? ""
                readonly property string artUrl: player?.trackArtUrl ?? ""

                // Cover art resolution
                property string artDownloadLocation: Directories.coverArt
                property string artFileName: Qt.md5(artUrl)
                property string artFilePath: `${artDownloadLocation}/${artFileName}`
                property bool artDownloaded: false

                readonly property string displayedArtFilePath: {
                    if (!artUrl || typeof artUrl !== "string") return "";
                    if (artUrl.startsWith("file://")) return artUrl;
                    if (artDownloaded) return Qt.resolvedUrl(artFilePath);
                    return "";
                }

                onArtUrlChanged: {
                    if (!artUrl || typeof artUrl !== "string" || artUrl.length === 0) {
                        artDownloaded = false;
                        return;
                    }
                    if (artUrl.startsWith("file://")) {
                        artDownloaded = true;
                        return;
                    }
                    artDownloader.targetFile = artUrl;
                    artDownloader.artFilePath = artFilePath;
                    artDownloaded = false;
                    artDownloader.running = true;
                }

                Process {
                    id: artDownloader
                    property string targetFile: islandContainer.artUrl
                    property string artFilePath: islandContainer.artFilePath
                    command: ["bash", "-c", `[ -f '${artFilePath}' ] || curl -sSL '${targetFile}' -o '${artFilePath}'`]
                    onExited: { islandContainer.artDownloaded = true }
                }

                // Smooth Hover Debounce (prevents flicker)
                property bool isHovered: false

                HoverHandler {
                    id: pillHoverHandler
                    target: islandPill
                    onHoveredChanged: {
                        if (hovered) {
                            hoverDebounceTimer.stop();
                            islandContainer.isHovered = true;
                        } else {
                            hoverDebounceTimer.restart();
                        }
                    }
                }

                Timer {
                    id: hoverDebounceTimer
                    interval: 280
                    repeat: false
                    onTriggered: islandContainer.isHovered = false
                }

                property bool trackChangedRecently: trackChangeTimer.running
                property bool pausedRecently: pauseGraceTimer.running

                // Dropdown visibility condition
                readonly property bool shouldDrop: GlobalStates.topDynamicIslandEnabled && (
                    GlobalStates.topDynamicIslandVisible || (hasTrack && (isPlaying || isHovered || trackChangedRecently || pausedRecently))
                )

                // Grace period when paused
                onIsPlayingChanged: {
                    if (!isPlaying && hasTrack) {
                        pauseGraceTimer.restart();
                    } else if (isPlaying) {
                        pauseGraceTimer.stop();
                    }
                }

                // Track change pulse
                onTrackTitleChanged: {
                    if (hasTrack) {
                        trackChangeTimer.restart();
                    }
                }

                Timer {
                    id: pauseGraceTimer
                    interval: 6000
                    repeat: false
                }

                Timer {
                    id: trackChangeTimer
                    interval: 4000
                    repeat: false
                }

                // Dimensions: Fixed stable width eliminates zoom distortion completely
                readonly property real islandWidth: 320
                readonly property real compactHeight: 38
                readonly property real expandedHeight: 124
                readonly property real targetHeight: isHovered ? expandedHeight : compactHeight

                width: islandWidth
                height: targetHeight

                // Dropdown height animation (extends down on hover)
                Behavior on height {
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutCubic
                    }
                }

                // Fluid Drop from Top Screen Frame
                y: shouldDrop ? root.frameThickness : -(targetHeight + 20)
                opacity: shouldDrop ? 1.0 : 0.0

                Behavior on y {
                    NumberAnimation {
                        duration: 440
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.05, 0.7, 0.1, 1.0]
                    }
                }

                Behavior on opacity {
                    NumberAnimation { duration: 250 }
                }

                // Inverted curves melting seamlessly into the top frame
                RoundCorner {
                    id: leftMeltCorner
                    anchors.right: islandPill.left
                    anchors.top: islandPill.top
                    corner: RoundCorner.CornerEnum.TopRight
                    implicitSize: 14
                    color: root.frameColor
                    visible: islandContainer.y <= root.frameThickness + 2 && islandContainer.shouldDrop
                }

                RoundCorner {
                    id: rightMeltCorner
                    anchors.left: islandPill.right
                    anchors.top: islandPill.top
                    corner: RoundCorner.CornerEnum.TopLeft
                    implicitSize: 14
                    color: root.frameColor
                    visible: islandContainer.y <= root.frameThickness + 2 && islandContainer.shouldDrop
                }

                // Main Island Body - filled with root.frameColor for seamless integration
                Rectangle {
                    id: islandPill
                    anchors.fill: parent
                    color: root.frameColor
                    topLeftRadius: 0
                    topRightRadius: 0
                    bottomLeftRadius: 18
                    bottomRightRadius: 18
                    border.width: 0
                    border.color: "transparent"
                    clip: true

                    WheelHandler {
                        orientation: Qt.Vertical
                        onWheel: (event) => {
                            if (event.angleDelta.y > 0) {
                                Audio.incrementVolume();
                            } else if (event.angleDelta.y < 0) {
                                Audio.decrementVolume();
                            }
                        }
                    }

                    // =========================================================
                    // 1. HEADER (Always at the top, constant size, never moves)
                    // =========================================================
                    Item {
                        id: headerRow
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: islandContainer.compactHeight

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 12
                            spacing: 8

                            // Mini Album Art
                            Rectangle {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                Layout.alignment: Qt.AlignVCenter
                                radius: 7
                                color: Appearance.colors.colPrimaryContainer
                                clip: true

                                Image {
                                    id: miniArtImage
                                    anchors.fill: parent
                                    source: islandContainer.displayedArtFilePath
                                    fillMode: Image.PreserveAspectCrop
                                    visible: status === Image.Ready
                                }

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    iconSize: 16
                                    text: islandContainer.hasTrack ? "music_note" : "graphic_eq"
                                    color: Appearance.colors.colOnPrimaryContainer
                                    visible: !miniArtImage.visible
                                }
                            }

                            // Track Title & Artist
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: islandContainer.hasTrack ? islandContainer.trackTitle : "No Media Playing"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colText
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: islandContainer.hasTrack ? (islandContainer.trackArtist.length > 0 ? islandContainer.trackArtist : "Unknown Artist") : "Dynamic Island"
                                    font.pixelSize: 10
                                    color: Appearance.colors.colSubtext
                                    elide: Text.ElideRight
                                }
                            }

                            // 4-Bar Mini Equalizer
                            Row {
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 18
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2

                                Repeater {
                                    model: 4

                                    Rectangle {
                                        id: miniBar
                                        required property int index
                                        width: 3
                                        radius: 1.5
                                        color: Appearance.colors.colPrimary
                                        anchors.bottom: parent.bottom

                                        property real baseHeight: 4
                                        property real animHeight: baseHeight
                                        property real targetH1: index === 0 ? 14 : index === 1 ? 8 : index === 2 ? 16 : 10
                                        property real targetH2: index === 0 ? 5 : index === 1 ? 15 : index === 2 ? 6 : 14
                                        property real targetH3: index === 0 ? 11 : index === 1 ? 4 : index === 2 ? 12 : 5
                                        property int animDur: index === 0 ? 240 : index === 1 ? 310 : index === 2 ? 190 : 270

                                        height: islandContainer.isPlaying ? animHeight : baseHeight

                                        SequentialAnimation on animHeight {
                                            running: islandContainer.isPlaying
                                            loops: Animation.Infinite
                                            NumberAnimation {
                                                to: miniBar.targetH1
                                                duration: miniBar.animDur
                                                easing.type: Easing.InOutQuad
                                            }
                                            NumberAnimation {
                                                to: miniBar.targetH2
                                                duration: miniBar.animDur
                                                easing.type: Easing.InOutQuad
                                            }
                                            NumberAnimation {
                                                to: miniBar.targetH3
                                                duration: miniBar.animDur
                                                easing.type: Easing.InOutQuad
                                            }
                                        }

                                        Behavior on height {
                                            NumberAnimation { duration: 120 }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // =========================================================
                    // 2. DROPDOWN DRAWER (Slides down beneath header on hover)
                    // =========================================================
                    Item {
                        id: dropdownDrawer
                        anchors.top: headerRow.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.bottomMargin: 8

                        opacity: islandContainer.isHovered ? 1.0 : 0.0
                        visible: opacity > 0.0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutQuad
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 6

                            // Divider line
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: ColorUtils.transparentize(Appearance.colors.colText, 0.92)
                            }

                            // Middle Scrubber / Progress Bar
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: {
                                        const pos = Math.floor(islandContainer.player?.position ?? 0);
                                        const m = Math.floor(pos / 60);
                                        const s = pos % 60;
                                        return `${m}:${s < 10 ? '0' : ''}${s}`;
                                    }
                                    font.pixelSize: 9
                                    color: Appearance.colors.colSubtext
                                }

                                Rectangle {
                                    id: progressBarTrack
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 4
                                    radius: 2
                                    color: ColorUtils.transparentize(Appearance.colors.colText, 0.8)

                                    property real progressRatio: {
                                        const len = islandContainer.player?.length ?? 0;
                                        if (len <= 0) return 0;
                                        return Math.min(1.0, Math.max(0.0, (islandContainer.player?.position ?? 0) / len));
                                    }

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: parent.width * progressBarTrack.progressRatio
                                        radius: 2
                                        color: Appearance.colors.colPrimary
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: (mouse) => {
                                            if (!islandContainer.player || !(islandContainer.player.canSeek ?? false)) return;
                                            const ratio = mouse.x / width;
                                            const total = islandContainer.player.length ?? 0;
                                            if (total > 0) {
                                                islandContainer.player.position = ratio * total;
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: {
                                        const len = Math.floor(islandContainer.player?.length ?? 0);
                                        const m = Math.floor(len / 60);
                                        const s = len % 60;
                                        return `${m}:${s < 10 ? '0' : ''}${s}`;
                                    }
                                    font.pixelSize: 9
                                    color: Appearance.colors.colSubtext
                                }
                            }

                            // Bottom Controls Row
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 14

                                Item { Layout.fillWidth: true }

                                // Previous Track
                                RippleButton {
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    colBackground: "transparent"
                                    colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colText, 0.9)
                                    colRipple: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.7)
                                    onClicked: {
                                        if (islandContainer.player?.canGoPrevious) islandContainer.player.previous();
                                    }

                                    contentItem: MaterialSymbol {
                                        anchors.centerIn: parent
                                        iconSize: 20
                                        text: "skip_previous"
                                        color: Appearance.colors.colText
                                    }
                                }

                                // Play / Pause Button
                                RippleButton {
                                    implicitWidth: 38
                                    implicitHeight: 38
                                    colBackground: Appearance.colors.colPrimary
                                    colBackgroundHover: ColorUtils.brighten(Appearance.colors.colPrimary, 0.1)
                                    colRipple: Appearance.colors.colPrimaryContainer
                                    onClicked: {
                                        if (islandContainer.player) islandContainer.player.togglePlaying();
                                    }

                                    contentItem: MaterialSymbol {
                                        anchors.centerIn: parent
                                        iconSize: 22
                                        text: islandContainer.isPlaying ? "pause" : "play_arrow"
                                        color: Appearance.colors.colOnPrimary
                                    }
                                }

                                // Next Track
                                RippleButton {
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    colBackground: "transparent"
                                    colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colText, 0.9)
                                    colRipple: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.7)
                                    onClicked: {
                                        if (islandContainer.player?.canGoNext) islandContainer.player.next();
                                    }

                                    contentItem: MaterialSymbol {
                                        anchors.centerIn: parent
                                        iconSize: 20
                                        text: "skip_next"
                                        color: Appearance.colors.colText
                                    }
                                }

                                Item { Layout.fillWidth: true }
                            }
                        }
                    }
                }
            }
        }
    }
}
