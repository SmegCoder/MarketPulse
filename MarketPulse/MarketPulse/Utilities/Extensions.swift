import Foundation

extension String {
    func normalizedTickerSymbol() -> String? {
        let s = self.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !s.isEmpty else { return nil }

        // разрешаем A-Z 0-9 . -
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-")
        guard s.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        return s
    }
}
