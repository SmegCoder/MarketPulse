import Foundation

actor ExpiringCache<Value> {
    struct Entry {
        let value: Value
        let expiresAt: Date
    }

    private let ttl: TimeInterval
    private var storage: [String: Entry] = [:]
    private var inflight: [String: Task<Value, Error>] = [:]

    init(ttl: TimeInterval) {
        self.ttl = ttl
    }

    func get(_ key: String) -> Value? {
        if let entry = storage[key], entry.expiresAt > Date() {
            return entry.value
        }
        storage[key] = nil
        return nil
    }

    func set(_ key: String, _ value: Value) {
        storage[key] = Entry(value: value, expiresAt: Date().addingTimeInterval(ttl))
    }

    /// Дедуп: если уже есть запрос "в полёте" на тот же key — ждём его, не делаем второй
    func getOrCreate(_ key: String, operation: @escaping @Sendable () async throws -> Value) async throws -> Value {
        if let cached = get(key) { return cached }

        if let task = inflight[key] {
            return try await task.value
        }

        let task = Task { try await operation() }
        inflight[key] = task

        do {
            let value = try await task.value
            set(key, value)
            inflight[key] = nil
            return value
        } catch {
            inflight[key] = nil
            throw error
        }
    }
}
