import Foundation

enum DeletionRisk: Int, Comparable, Sendable {
    case safe = 0
    case caution = 1
    case critical = 2

    static func < (lhs: DeletionRisk, rhs: DeletionRisk) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .safe: return "Safe to remove"
        case .caution: return "Use caution"
        case .critical: return "High risk"
        }
    }

    var icon: String {
        switch self {
        case .safe: return "checkmark.shield"
        case .caution: return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }
}

struct DeletionRiskAssessment: Sendable {
    let risk: DeletionRisk
    let reason: String
}

struct DeletionRiskSummary: Sendable {
    let highest: DeletionRisk
    let safeCount: Int
    let cautionCount: Int
    let criticalCount: Int
    let assessments: [String: DeletionRiskAssessment]

    var hasWarnings: Bool { highest >= .caution }
    var requiresAcknowledgment: Bool { criticalCount > 0 }

    static let empty = DeletionRiskSummary(
        highest: .safe,
        safeCount: 0,
        cautionCount: 0,
        criticalCount: 0,
        assessments: [:]
    )
}

enum DeletionRiskService {
    /// Paths that must never be deleted, even if they appear writable.
    nonisolated static func isSystemProtected(path: String) -> Bool {
        let normalized = normalize(path)

        if KnownPaths.neverDeletableExactPaths.contains(path) {
            return true
        }

        for prefix in KnownPaths.neverDeletablePrefixes where normalized.hasPrefix(prefix) {
            return true
        }

        let protectedFragments = [
            "/Library/Containers/com.apple.",
            "/Library/Application Support/com.apple.",
            "/Library/Preferences/",
            "/Library/Keychains/",
            "/.ssh/",
            "/.gnupg/",
            "/.aws/credentials",
            "/.config/gcloud/",
        ]

        return protectedFragments.contains { normalized.contains($0) }
            || path.hasSuffix("/.ssh")
            || path.hasSuffix("/.gnupg")
    }

    nonisolated static func assess(path: String) -> DeletionRiskAssessment {
        if isSystemProtected(path: path) {
            return DeletionRiskAssessment(
                risk: .critical,
                reason: "Protected system or security data — cannot be deleted."
            )
        }

        let normalized = normalize(path)
        let name = URL(fileURLWithPath: path).lastPathComponent
        let home = KnownPaths.home.path

        if matchesCriticalExactPaths(normalized, home: home) {
            return DeletionRiskAssessment(
                risk: .critical,
                reason: "Deleting this folder can break macOS, Xcode, or many apps at once."
            )
        }

        if isAppContainerRoot(normalized, home: home) {
            return DeletionRiskAssessment(
                risk: .critical,
                reason: "This is an app's entire sandbox container — the app may stop working or lose all data."
            )
        }

        if normalized.contains("/com.docker.") || normalized.contains("/docker/") {
            return DeletionRiskAssessment(
                risk: .critical,
                reason: "Docker images, containers, or volumes — you may lose containers and downloaded images."
            )
        }

        if isDeveloperProjectRoot(normalized, home: home) {
            return DeletionRiskAssessment(
                risk: .critical,
                reason: "This looks like an entire project folder — source code and git history would be lost."
            )
        }

        if matchesCautionPatterns(normalized, name: name, home: home) {
            return cautionReason(for: normalized, name: name)
        }

        return DeletionRiskAssessment(
            risk: .safe,
            reason: "Caches and logs are usually safe — apps can rebuild them."
        )
    }

    nonisolated static func summarize(items: [StorageItem]) -> DeletionRiskSummary {
        guard !items.isEmpty else { return .empty }

        var safe = 0
        var caution = 0
        var critical = 0
        var highest = DeletionRisk.safe
        var assessments: [String: DeletionRiskAssessment] = [:]

        for item in items {
            let assessment = assess(path: item.path)
            assessments[item.path] = assessment
            if assessment.risk > highest {
                highest = assessment.risk
            }
            switch assessment.risk {
            case .safe: safe += 1
            case .caution: caution += 1
            case .critical: critical += 1
            }
        }

        return DeletionRiskSummary(
            highest: highest,
            safeCount: safe,
            cautionCount: caution,
            criticalCount: critical,
            assessments: assessments
        )
    }

    // MARK: - Rules

    private nonisolated static func normalize(_ path: String) -> String {
        var p = path
        if !p.hasSuffix("/") { p += "/" }
        return p
    }

    private nonisolated static func matchesCriticalExactPaths(_ normalized: String, home: String) -> Bool {
        let criticalPaths = [
            home + "/",
            home + "/Library/",
            home + "/Library/Developer/",
            home + "/Library/Application Support/",
            home + "/Library/Containers/",
            home + "/Library/Group Containers/",
            home + "/Library/Mail/",
            home + "/Library/Messages/",
            home + "/Documents/",
            home + "/Downloads/",
            home + "/Desktop/",
            home + "/Developer/",
            home + "/.nvm/",
            home + "/.fnm/",
            home + "/Library/Android/",
            home + "/.android/",
        ]
        return criticalPaths.contains { normalized == $0 }
    }

    private nonisolated static func isAppContainerRoot(_ normalized: String, home: String) -> Bool {
        let prefix = home + "/Library/Containers/"
        guard normalized.hasPrefix(prefix) else { return false }
        let remainder = normalized.dropFirst(prefix.count)
        let parts = remainder.split(separator: "/", omittingEmptySubsequences: true)
        return parts.count == 1
    }

    private nonisolated static func isDeveloperProjectRoot(_ normalized: String, home: String) -> Bool {
        let prefix = home + "/Developer/"
        guard normalized.hasPrefix(prefix) else { return false }
        let remainder = normalized.dropFirst(prefix.count)
        let parts = remainder.split(separator: "/", omittingEmptySubsequences: true)
        return parts.count == 1
    }

    private nonisolated static func matchesCautionPatterns(_ normalized: String, name: String, home: String) -> Bool {
        let cautionNames: Set<String> = [
            "node_modules", "DerivedData", "Pods", "Carthage", "vendor",
            ".git", "build", "dist", ".next", ".turbo", "target",
        ]

        if cautionNames.contains(name) { return true }

        if normalized.contains("/Library/Application Support/") { return true }
        if normalized.contains("/Library/Group Containers/") { return true }
        if normalized.contains("/Library/Mobile Documents/") { return true }
        if normalized.contains("/.gradle/") && !normalized.contains("/.gradle/caches/") { return true }

        return false
    }

    private nonisolated static func cautionReason(for normalized: String, name: String) -> DeletionRiskAssessment {
        if name == "node_modules" {
            return DeletionRiskAssessment(
                risk: .caution,
                reason: "Dependencies folder — run your package manager to reinstall after deleting."
            )
        }
        if name == "DerivedData" {
            return DeletionRiskAssessment(
                risk: .caution,
                reason: "Xcode build cache — next builds will be slower until it rebuilds."
            )
        }
        if name == ".git" {
            return DeletionRiskAssessment(
                risk: .caution,
                reason: "Git repository — you will lose version history for this project."
            )
        }
        if normalized.contains("/Library/Application Support/") {
            return DeletionRiskAssessment(
                risk: .caution,
                reason: "Application data — the app may forget settings, accounts, or local files."
            )
        }
        return DeletionRiskAssessment(
            risk: .caution,
            reason: "May require reinstalling dependencies or rebuilding projects."
        )
    }
}
