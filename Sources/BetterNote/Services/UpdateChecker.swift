import AppKit
import Observation

/// Checks GitHub releases for a newer version. Runs silently once a day after
/// launch and always reports a result when invoked manually from the menu.
@MainActor @Observable
final class UpdateChecker {
    static let repository = "silkyland/better-note"

    private(set) var isChecking = false
    private let lastCheckKey = "update.lastCheck"
    private let notifiedTagKey = "update.notifiedTag"

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Silent scheduled check: at most once a day, alerts once per new release.
    func checkIfNeeded() async {
        let last = UserDefaults.standard.object(forKey: lastCheckKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) > 86_400 else { return }
        UserDefaults.standard.set(Date(), forKey: lastCheckKey)
        guard let release = try? await latestRelease(),
              Self.isNewer(release.tag, than: currentVersion),
              UserDefaults.standard.string(forKey: notifiedTagKey) != release.tag else { return }
        UserDefaults.standard.set(release.tag, forKey: notifiedTagKey)
        presentUpdateAlert(release)
    }

    /// Manual check from the application menu — always shows a result.
    func checkNow() async {
        isChecking = true
        defer { isChecking = false }
        do {
            let release = try await latestRelease()
            if Self.isNewer(release.tag, than: currentVersion) {
                presentUpdateAlert(release)
            } else {
                let alert = NSAlert()
                alert.messageText = "You're up to date."
                alert.informativeText = "BetterNote \(currentVersion) is the latest version."
                alert.runModal()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not check for updates."
            alert.informativeText = "Check your connection and try again."
            alert.runModal()
        }
    }

    struct Release: Decodable {
        let tag: String
        let url: String
        let isDraft: Bool

        enum CodingKeys: String, CodingKey {
            case tag = "tag_name"
            case url = "html_url"
            case isDraft = "draft"
        }
    }

    /// Returns the newest non-draft release. The list endpoint is used instead
    /// of /releases/latest because prereleases (betas) are excluded there.
    private func latestRelease() async throws -> Release {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repository)/releases")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("BetterNote/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        guard let release = try JSONDecoder().decode([Release].self, from: data).first(where: { !$0.isDraft }) else {
            throw URLError(.cannotParseResponse)
        }
        return release
    }

    private func presentUpdateAlert(_ release: Release) {
        let alert = NSAlert()
        alert.messageText = "BetterNote \(release.tag) is available."
        alert.informativeText = "You're running \(currentVersion). Download the new version from GitHub."
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn, let url = URL(string: release.url) {
            NSWorkspace.shared.open(url)
        }
    }

    /// Semver-ish comparison: numeric components first, then prerelease
    /// suffix (a release without a suffix ranks above one with it).
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = parse(candidate), b = parse(current)
        for index in 0..<max(a.numbers.count, b.numbers.count) {
            let x = index < a.numbers.count ? a.numbers[index] : 0
            let y = index < b.numbers.count ? b.numbers[index] : 0
            if x != y { return x > y }
        }
        switch (a.pre, b.pre) {
        case (.none, .some): return true
        case (.some, .none), (.none, .none): return false
        case let (.some(x), .some(y)):
            let xs = x.split(separator: ".").map(String.init)
            let ys = y.split(separator: ".").map(String.init)
            for index in 0..<max(xs.count, ys.count) {
                let p = index < xs.count ? xs[index] : ""
                let q = index < ys.count ? ys[index] : ""
                if p == q { continue }
                if let pi = Int(p), let qi = Int(q) { return pi > qi }
                return p > q
            }
            return false
        }
    }

    private static func parse(_ version: String) -> (numbers: [Int], pre: String?) {
        var text = version
        if text.hasPrefix("v") { text.removeFirst() }
        let parts = text.split(separator: "-", maxSplits: 1)
        let numbers = parts[0].split(separator: ".").map { Int($0) ?? 0 }
        return (numbers, parts.count > 1 ? String(parts[1]) : nil)
    }
}
