import Foundation

/// Saved progress and settings. Plain UserDefaults; there are no accounts and nothing to buy.
final class Progress {
    static let shared = Progress()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: Levels

    func stars(for levelID: Int) -> Int { defaults.integer(forKey: "stars.\(levelID)") }

    func bestScore(for levelID: Int) -> Int { defaults.integer(forKey: "best.\(levelID)") }

    func bestTime(for levelID: Int) -> Double? {
        let t = defaults.double(forKey: "time.\(levelID)")
        return t > 0 ? t : nil
    }

    func record(_ result: LevelResult, for levelID: Int) {
        if result.stars > stars(for: levelID) { defaults.set(result.stars, forKey: "stars.\(levelID)") }
        if result.score > bestScore(for: levelID) { defaults.set(result.score, forKey: "best.\(levelID)") }
        if let best = bestTime(for: levelID) {
            if result.time < best { defaults.set(result.time, forKey: "time.\(levelID)") }
        } else {
            defaults.set(result.time, forKey: "time.\(levelID)")
        }
    }

    func totalStars(levels: [Level]) -> Int {
        levels.reduce(0) { $0 + stars(for: $1.id) }
    }

    // MARK: Storm

    var stormBest: Int {
        get { defaults.integer(forKey: "storm.best") }
        set { defaults.set(newValue, forKey: "storm.best") }
    }

    /// Returns true if this was a new record.
    @discardableResult
    func recordStorm(score: Int) -> Bool {
        guard score > stormBest else { return false }
        stormBest = score
        return true
    }

    // MARK: Settings

    var soundEnabled: Bool {
        get { defaults.object(forKey: "settings.sound") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "settings.sound") }
    }

    var hapticsEnabled: Bool {
        get { defaults.object(forKey: "settings.haptics") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "settings.haptics") }
    }

    var playerCount: Int {
        get { max(1, min(2, defaults.integer(forKey: "settings.players"))) }
        set { defaults.set(newValue, forKey: "settings.players") }
    }

    var lastCity: Int {
        get { defaults.integer(forKey: "ui.lastCity") }
        set { defaults.set(newValue, forKey: "ui.lastCity") }
    }

    func resetAll() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("stars.") || key.hasPrefix("best.") || key.hasPrefix("time.") || key.hasPrefix("storm.") {
            defaults.removeObject(forKey: key)
        }
    }
}
