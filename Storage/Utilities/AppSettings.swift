import Foundation

enum AppSettings {
    private static let showCachedResultsKey = "showCachedResultsOnLaunch"

    static var showCachedResultsOnLaunch: Bool {
        get {
            if UserDefaults.standard.object(forKey: showCachedResultsKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: showCachedResultsKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: showCachedResultsKey) }
    }
}
