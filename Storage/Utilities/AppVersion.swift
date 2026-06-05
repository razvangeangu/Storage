import Foundation

enum AppVersion {
    static var marketing: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    static var displayString: String {
        if build.isEmpty || build == marketing {
            return marketing
        }
        return "\(marketing) (\(build))"
    }
}
