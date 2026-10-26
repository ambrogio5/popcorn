import UIKit

enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notify = UINotificationFeedbackGenerator()

    private static var enabled: Bool { Progress.shared.hapticsEnabled }

    static func prepare() {
        light.prepare()
        medium.prepare()
        heavy.prepare()
    }

    static func pop(_ size: BubbleSize) {
        guard enabled else { return }
        switch size {
        case .tiny, .small: light.impactOccurred()
        case .medium: medium.impactOccurred()
        case .large: heavy.impactOccurred()
        }
    }

    static func tap() {
        guard enabled else { return }
        light.impactOccurred(intensity: 0.6)
    }

    static func hit() {
        guard enabled else { return }
        heavy.impactOccurred()
    }

    static func success() {
        guard enabled else { return }
        notify.notificationOccurred(.success)
    }

    static func failure() {
        guard enabled else { return }
        notify.notificationOccurred(.error)
    }
}
