// JSONRPC.swift (afterglow-mcp MC-1 contract, MC-4 body): JSON-RPC 2.0
// framing, one message per line (https://www.jsonrpc.org/specification).
// `parse` reads a line as one request or notification: bad JSON is -32700,
// JSON that isn't a request object (a batch, a wrong `jsonrpc`, an id that is
// neither an integer nor a string, params that aren't an object, a line over
// the cap) is -32600. `reply` writes the envelope.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A request id: JSON-RPC allows a number or a string.
public enum RPCID: Hashable, Sendable, Codable {
    case number(Int), string(String)

    public init(from decoder: any Decoder) throws {
        let box = try decoder.singleValueContainer()
        if let value = try? box.decode(Int.self) { self = .number(value) } else { self = .string(try box.decode(String.self)) }
    }
    public func encode(to encoder: any Encoder) throws { try json.encode(to: encoder) }

    /// The id as a JSON value.
    public var json: JSONValue {
        switch self { case .number(let value): .number(Double(value)); case .string(let value): .string(value) }
    }
}

/// One parsed message. A nil `id` is a notification, which gets no reply.
public struct RPCRequest: Hashable, Sendable {
    public var id: RPCID?; public var method: String; public var params: JSONValue?
    public init(id: RPCID?, method: String, params: JSONValue? = nil) { (self.id, self.method, self.params) = (id, method, params) }
}

/// A JSON-RPC error object.
public struct RPCError: Error, Hashable, Sendable {
    public var code: Int; public var message: String; public var data: JSONValue?
    public init(code: Int, message: String, data: JSONValue? = nil) { (self.code, self.message, self.data) = (code, message, data) }

    /// The standard codes.
    public static let parseError = -32700, invalidRequest = -32600, methodNotFound = -32601,
        invalidParams = -32602, internalError = -32603

    /// The error a stub answers with: `what` is not built yet, naming the task that builds it.
    public static func notBuilt(_ what: String, task: String) -> RPCError {
        RPCError(code: internalError, message: "\(what) is not built yet (afterglow-mcp \(task))")
    }
}

/// Reading and writing JSON-RPC 2.0 lines.
public enum JSONRPC {
    /// The longest line the server reads; a longer one is an invalid request.
    public static let maxLineBytes = 16 << 20

    /// Reads one line as a request: -32700 for bad JSON, -32600 for JSON that isn't a request.
    public static func parse(_ line: Data) -> Result<RPCRequest, RPCError> {
        guard line.count <= maxLineBytes else { return .failure(invalid("the line is over \(maxLineBytes) bytes")) }
        guard let value = try? JSONValue(json: line) else {
            return .failure(RPCError(code: RPCError.parseError, message: "Parse error: the line is not one JSON value"))
        }
        guard case .object(let body) = value else { return .failure(invalid("a message is one JSON object (batches are not read)")) }
        guard body["jsonrpc"] == .string("2.0") else { return .failure(invalid("jsonrpc must be \"2.0\"")) }
        guard case .string(let method)? = body["method"] else { return .failure(invalid("method must be a string")) }
        var id: RPCID?
        switch body["id"] {
        case nil: id = nil
        case .string(let text)?: id = .string(text)
        case .number(let number)?:
            guard let whole = Int(exactly: number) else { return .failure(invalid("id must be an integer or a string")) }
            id = .number(whole)
        default: return .failure(invalid("id must be an integer or a string"))
        }
        switch body["params"] {
        case nil, .object?: return .success(RPCRequest(id: id, method: method, params: body["params"]))
        default: return .failure(invalid("params must be an object"))
        }
    }

    /// The -32600 error saying why a message isn't a request.
    static func invalid(_ why: String) -> RPCError { RPCError(code: RPCError.invalidRequest, message: "Invalid Request: \(why)") }

    /// The success reply to `id`, one line without its newline.
    public static func reply(_ id: RPCID, result: JSONValue) -> Data {
        encode(["jsonrpc": .string("2.0"), "id": id.json, "result": result])
    }

    /// The error reply to `id` (null when the request's id couldn't be read), one line without its newline.
    public static func reply(_ id: RPCID?, error: RPCError) -> Data {
        var body: [String: JSONValue] = ["code": .number(Double(error.code)), "message": .string(error.message)]
        if let data = error.data { body["data"] = data }
        return encode(["jsonrpc": .string("2.0"), "id": id?.json ?? .null, "error": .object(body)])
    }

    /// `object` as sorted JSON; an envelope of JSON values always encodes, so the empty fallback never shows.
    static func encode(_ object: [String: JSONValue]) -> Data { (try? JSONValue.object(object).json()) ?? Data() }
}
