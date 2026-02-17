import Foundation

struct HTTPStatusError: LocalizedError {
    let statusCode: Int
    let body: String

    var errorDescription: String? {
        "HTTP \(statusCode): \(body)"
    }
}

final class NetworkService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func getData(from url: URL) async throws -> Data {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        return try await getData(request: req)
    }

    func getData(request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            return data
        }

        if !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
            throw HTTPStatusError(statusCode: http.statusCode, body: body)
        }

        return data
    }

    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(T.self, from: data)
    }
}
