import GameKit
import UIKit

/// Optional Game Center: leaderboards for Storm and total stars, achievements for three-starring
/// a city. Every call is a no-op until the player is authenticated, and errors are swallowed, so
/// the game plays exactly the same without a Game Center account, without the capability, or
/// without a network. See README → "Game Center".
final class GameCenter: NSObject {
    static let shared = GameCenter()

    enum Leaderboard {
        static let stormBest = "storm.best"
        static let totalStars = "levels.totalstars"
    }

    enum Achievement {
        static let storm1000 = "storm.1000"
        static let storm10000 = "storm.10000"
        static func cityThreeStars(_ cityIndex: Int) -> String { "city.\(cityIndex).threestars" }
    }

    /// Set by scenes that show Game Center UI (the menu's Leaderboards button); called on the main
    /// thread whenever the player signs in or out.
    var onAuthenticationChange: (() -> Void)?

    var isAuthenticated: Bool { GKLocalPlayer.local.isAuthenticated }

    /// Achievements already reported as complete this launch; Game Center ignores repeats anyway,
    /// this just saves the round trips.
    private var completed: Set<String> = []

    private override init() {}

    // MARK: Authentication

    /// Starts Game Center sign-in. If GameKit hands back a view controller (first launch, or the
    /// player is signed out) it is presented from `presenter`; otherwise nothing is shown. Never
    /// blocks gameplay: the handler is asynchronous and a failure just leaves us unauthenticated.
    func authenticate(presentingFrom presenter: UIViewController) {
        GKLocalPlayer.local.authenticateHandler = { [weak self, weak presenter] viewController, _ in
            DispatchQueue.main.async {
                if let viewController = viewController, let presenter = presenter, presenter.presentedViewController == nil {
                    presenter.present(viewController, animated: true)
                }
                self?.onAuthenticationChange?()
            }
        }
    }

    // MARK: Scores and achievements

    func submit(score: Int, to leaderboardID: String) {
        guard isAuthenticated else { return }
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [leaderboardID]) { _ in }
    }

    func report(achievementID: String, percent: Double = 100) {
        guard isAuthenticated, percent > 0, !completed.contains(achievementID) else { return }
        let achievement = GKAchievement(identifier: achievementID)
        achievement.percentComplete = min(percent, 100)
        achievement.showsCompletionBanner = true
        if achievement.percentComplete >= 100 { completed.insert(achievementID) }
        GKAchievement.report([achievement]) { _ in }
    }

    // MARK: Game hooks

    /// Called when a Storm run ends.
    func stormFinished(score: Int) {
        submit(score: score, to: Leaderboard.stormBest)
        report(achievementID: Achievement.storm1000, percent: Double(score) / 10)
        report(achievementID: Achievement.storm10000, percent: Double(score) / 100)
    }

    /// Called after a level result has been recorded in `Progress`.
    func levelFinished(in cityIndex: Int) {
        let content = GameContent.shared
        submit(score: Progress.shared.totalStars(levels: content.levels), to: Leaderboard.totalStars)
        let cityLevels = content.levels(inCity: cityIndex)
        if !cityLevels.isEmpty, cityLevels.allSatisfy({ Progress.shared.stars(for: $0.id) >= 3 }) {
            report(achievementID: Achievement.cityThreeStars(cityIndex))
        }
    }

    // MARK: UI

    /// Presents the Game Center leaderboards sheet. The menu only shows its button when
    /// authenticated, but the guard keeps a stale button harmless.
    func showLeaderboards(from presenter: UIViewController?) {
        guard isAuthenticated, let presenter = presenter, presenter.presentedViewController == nil else { return }
        let viewController = GKGameCenterViewController(state: .leaderboards)
        viewController.gameCenterDelegate = self
        presenter.present(viewController, animated: true)
    }
}

extension GameCenter: GKGameCenterControllerDelegate {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
