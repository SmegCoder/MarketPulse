import Foundation

enum AppFormatter {
    static func price(_ value: Double?) -> String {
        guard let v = value else { return "—" }
        return String(format: "%.2f", v)
    }

    static func percent(_ value: Double?) -> String {
        guard let v = value else { return "" }
        return String(format: "%@%.2f%%", v >= 0 ? "+" : "", v)
    }

    static func shortDateTime(_ date: Date?) -> String {
        guard let d = date else { return "—" }
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: d)
    }
}
