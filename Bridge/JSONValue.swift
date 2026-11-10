import Foundation

/// 웹에서 전달되는 임의 타입의 JSON 인수를 디코딩하는 타입
enum JSONValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    var string: String? { if case .string(let value) = self { return value }; return nil }
    var number: Double? { if case .number(let value) = self { return value }; return nil }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Bool 먼저 체크 (Double로 잘못 디코딩되는 것 방지)
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.typeMismatch(
                JSONValue.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Unknown JSON type")
            )
        }
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
