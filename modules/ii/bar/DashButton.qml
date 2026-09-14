pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

RippleButton {
    id: root

    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: Config.options.bar.cornerStyle === 3

    implicitWidth: isMaterial ? 32 : 24
    implicitHeight: implicitWidth

    buttonRadius: Appearance.rounding.full
    colBackground: isMaterial
        ? (toggled ? Appearance.colors.colSecondaryContainer : Appearance.colors.colPrimaryContainer)
        : (toggled ? Appearance.colors.colSecondaryContainer : "transparent")
    colBackgroundHover: isMaterial
        ? (toggled ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colPrimaryContainerHover)
        : Appearance.colors.colLayer1Hover
    colRipple: Appearance.colors.colLayer1Active
    colBackgroundToggled: Appearance.colors.colSecondaryContainer
    colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
    colRippleToggled: Appearance.colors.colSecondaryContainerActive

    toggled: GlobalStates.dockPinned

    onPressed: {
        GlobalStates.dockPinned = !GlobalStates.dockPinned;
    }

    MaterialSymbol {
        anchors.centerIn: parent
        iconSize: isMaterial ? 18 : 17
        fill: root.toggled ? 1 : 0
        text: "dock_to_bottom"
        color: root.toggled
            ? Appearance.colors.colPrimary
            : Appearance.colors.colOnLayer0

        Behavior on color {
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
    }

    StyledToolTip {
        extraVisibleCondition: root.hovered
        text: GlobalStates.dockPinned
            ? Translation.tr("Dash: Pinned (Click to unpin)")
            : Translation.tr("Dash: Auto-hidden (Click to pin)")
    }
}
