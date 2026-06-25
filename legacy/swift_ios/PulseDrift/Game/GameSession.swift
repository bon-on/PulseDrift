import Combine
import Foundation

@MainActor
final class GameSession: ObservableObject {
    private enum StorageKey {
        static let bestScore = "PulseDrift.bestScore"
    }

    @Published private(set) var score = 0
    @Published private(set) var bestScore = UserDefaults.standard.integer(forKey: StorageKey.bestScore)
    @Published private(set) var multiplier = 1.0
    @Published private(set) var currentSpeed = Balance.baseSpeed
    @Published private(set) var isGameOver = false
    @Published private(set) var restartToken = UUID()

    private var cleanDodges = 0

    func registerDodge() {
        guard !isGameOver else { return }

        cleanDodges += 1
        multiplier = Balance.multiplier(for: cleanDodges)
        currentSpeed = Balance.speed(for: cleanDodges)
        score += Int(Double(Balance.baseScorePerGate) * multiplier)
        syncBestScore()
    }

    func collectSpark() {
        guard !isGameOver else { return }

        score += Balance.sparkBonus
        syncBestScore()
    }

    func endRun() {
        isGameOver = true
    }

    func restartRequested() {
        score = 0
        multiplier = 1.0
        currentSpeed = Balance.baseSpeed
        cleanDodges = 0
        isGameOver = false
        restartToken = UUID()
    }

    private func syncBestScore() {
        guard score > bestScore else { return }
        bestScore = score
        UserDefaults.standard.set(bestScore, forKey: StorageKey.bestScore)
    }
}

enum Balance {
    static let baseScorePerGate = 10
    static let sparkBonus = 25
    static let baseSpeed = 300.0
    private static let maxSpeed = 820.0

    static func multiplier(for cleanDodges: Int) -> Double {
        let rawValue = 1.0 + (Double(cleanDodges) * 0.12)
        return min(rawValue, 3.5)
    }

    static func speed(for cleanDodges: Int) -> Double {
        let progress = min(Double(cleanDodges) / 22.0, 1.0)
        let easedProgress = 1.0 - pow(1.0 - progress, 2.0)
        let rawValue = baseSpeed + ((maxSpeed - baseSpeed) * easedProgress)
        return min(rawValue, maxSpeed)
    }

    static func gateSpawnDelay(for cleanDodges: Int) -> TimeInterval {
        let rawValue = 1.28 - (Double(cleanDodges) * 0.025)
        return max(rawValue, 0.42)
    }

    static func sparkSpawnDelay(for cleanDodges: Int) -> TimeInterval {
        let rawValue = 3.4 - (Double(cleanDodges) * 0.04)
        return max(rawValue, 1.8)
    }
}
