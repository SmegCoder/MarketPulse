import Foundation

actor SlidingWindowRateLimiter {
    private let maxRequests: Int
    private let window: TimeInterval
    private var timestamps: [Date] = []

    init(maxRequests: Int, windowSeconds: TimeInterval) {
        self.maxRequests = maxRequests
        self.window = windowSeconds
    }

    func acquire() async {
        while true {
            let now = Date()
            timestamps = timestamps.filter { now.timeIntervalSince($0) < window }

            if timestamps.count < maxRequests {
                timestamps.append(now)
                return
            }

            // ждём, пока самый старый запрос выйдет из окна
            let oldest = timestamps[0]
            let wait = window - now.timeIntervalSince(oldest) + 0.05
            if wait > 0 {
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            } else {
                // на всякий случай
                timestamps.removeFirst()
            }
        }
    }
}
