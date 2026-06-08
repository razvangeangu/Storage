import Foundation

enum AppSettings {
    private static let showCachedResultsKey = "showCachedResultsOnLaunch"
    private static let includeAppDataInScanKey = "includeAppDataInScan"

    /// When false (default), skips Containers and per-app Library folders that trigger macOS privacy prompts.
    static var includeAppDataInScan: Bool {
        get { UserDefaults.standard.bool(forKey: includeAppDataInScanKey) }
        set { UserDefaults.standard.set(newValue, forKey: includeAppDataInScanKey) }
    }

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
