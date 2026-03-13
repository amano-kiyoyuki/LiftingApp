import Foundation
import Observation

@Observable
class GoalManager {
    var dailyGoal: Int {
        get { UserDefaults.standard.integer(forKey: "dailyGoal") }
        set { UserDefaults.standard.set(newValue, forKey: "dailyGoal") }
    }

    var hasGoal: Bool {
        dailyGoal > 0
    }

    func progress(for count: Int) -> Double {
        guard dailyGoal > 0 else { return 0 }
        return min(Double(count) / Double(dailyGoal), 1.0)
    }

    func isAchieved(count: Int) -> Bool {
        hasGoal && count >= dailyGoal
    }
}
