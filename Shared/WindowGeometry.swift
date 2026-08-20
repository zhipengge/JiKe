import CoreGraphics
import Foundation

/// 对齐 Guake `globals.py`：ALIGN_CENTER/LEFT/RIGHT、ALIGN_TOP/BOTTOM、ALWAYS_ON_PRIMARY。
enum HorizontalAlignment: Int, Codable, Equatable, Hashable {
    case center = 0
    case left = 1
    case right = 2
}

enum VerticalAlignment: Int, Codable, Equatable, Hashable {
    case top = 0
    case bottom = 1
}

enum WindowGeometry {
    static let maxTransparency = 100

    static func clampedHeightPercent(_ value: Double) -> Double { min(100, max(10, value)) }
    static func clampedWidthPercent(_ value: Double) -> Double { min(100, max(20, value)) }
    static func clampedTransparency(_ value: Int) -> Int { min(maxTransparency, max(1, value)) }
    static func clampedFontSize(_ value: Double) -> Double { min(48, max(9, value)) }
    static func clampedAnimationDuration(_ value: Double) -> Double { min(1.0, max(0, value)) }

    /// Guake `styleBackground.transparency` 实际按 alpha 用：`bg_color.alpha = transparency / 100`。
    static func backgroundAlpha(_ transparency: Int) -> Double {
        Double(clampedTransparency(transparency)) / 100
    }

    static func frame(
        screen: CGRect,
        heightPercent: Double,
        widthPercent: Double,
        horizontalAlignment: HorizontalAlignment,
        verticalAlignment: VerticalAlignment,
        displacementX: Double,
        displacementY: Double,
        visible: Bool
    ) -> CGRect {
        let height = screen.height * clampedHeightPercent(heightPercent) / 100
        let width = screen.width * clampedWidthPercent(widthPercent) / 100
        let x: CGFloat
        switch horizontalAlignment {
        case .left: x = screen.minX + displacementX
        case .right: x = screen.maxX - width + displacementX
        case .center: x = screen.minX + (screen.width - width) / 2 + displacementX
        }
        let shownY: CGFloat
        switch verticalAlignment {
        case .top: shownY = screen.maxY - height - displacementY
        case .bottom: shownY = screen.minY + displacementY
        }
        let hiddenY: CGFloat
        switch verticalAlignment {
        case .top: hiddenY = screen.maxY + 12
        case .bottom: hiddenY = screen.minY - height - 12
        }
        return CGRect(x: x, y: visible ? shownY : hiddenY, width: width, height: height)
    }
}

enum MonitorPreference: Codable, Equatable, Hashable {
    case mouse
    case primary
    case index(Int)

    /// Guake `ALWAYS_ON_PRIMARY = -1`；`mouse_display` 优先。
    static func resolvedIndex(
        preference: MonitorPreference,
        mouseScreenIndex: Int,
        primaryIndex: Int,
        count: Int
    ) -> Int {
        guard count > 0 else { return 0 }
        let raw: Int
        switch preference {
        case .mouse: raw = mouseScreenIndex
        case .primary: raw = primaryIndex
        case .index(let value): raw = value < 0 ? primaryIndex : value
        }
        return min(max(0, raw), count - 1)
    }
}