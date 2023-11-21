//
// Copyright (c) Vatsal Manot
//

import NetworkKit
import Swift

extension OpenAI {
    public enum ObjectType: String, Codable, TypeDiscriminator, Sendable {
        case list
        case embedding
        case textCompletion = "text_completion"
        case chatCompletion = "chat.completion"
        case chatCompletionChunk = "chat.completion.chunk"
        
        public func resolveType() -> Any.Type {
            switch self {
                case .list:
                    return OpenAI.List<Object>.self
                case .embedding:
                    return OpenAI.Embedding.self
                case .textCompletion:
                    return OpenAI.TextCompletion.self
                case .chatCompletion:
                    return OpenAI.ChatCompletion.self
                case .chatCompletionChunk:
                    return OpenAI.ChatCompletionChunk.self
            }
        }
    }
    
    public class Object: Codable, PolymorphicDecodable, TypeDiscriminable, @unchecked Sendable {
        private enum CodingKeys: String, CodingKey {
            case type = "object"
        }
        
        public let type: ObjectType
        
        public var typeDiscriminator: ObjectType {
            type
        }

        public required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.type = try container.decode(ObjectType.self, forKey: .type)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(type, forKey: .type)
        }
    }
    
    public class List<T: Object & Sendable>: Object {
        private enum CodingKeys: String, CodingKey {
            case data
        }
        
        public let data: [T]
        
        public required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.data = try container.decode(forKey: .data)
            
            try super.init(from: decoder)
        }
        
        public override func encode(to encoder: Encoder) throws {
            try super.encode(to: encoder)
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(data, forKey: .data)
        }
    }
    
    public final class File: OpenAI.Object {
        private enum CodingKeys: String, CodingKey {
            case id
            case bytes
            case createdAt
            case filename
            case purpose
        }
        
        public let id: String
        public let bytes: Int
        public let createdAt: Date // FIXME?
        public let filename: String
        public let purpose: String
        
        public required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.id = try container.decode(forKey: .id)
            self.bytes = try container.decode(forKey: .bytes)
            self.createdAt = try container.decode(forKey: .createdAt)
            self.filename = try container.decode(forKey: .filename)
            self.purpose = try container.decode(forKey: .purpose)
            
            try super.init(from: decoder)
        }
        
        public override func encode(to encoder: Encoder) throws {
            try super.encode(to: encoder)
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(id, forKey: .id)
            try container.encode(bytes, forKey: .bytes)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encode(filename, forKey: .filename)
            try container.encode(purpose, forKey: .purpose)
        }
    }
}

extension OpenAI {
    public struct Usage: Codable, Hashable, Sendable {
        public let promptTokens: Int
        public let completionTokens: Int?
        public let totalTokens: Int
    }
}

extension OpenAI {
    public final class Embedding: OpenAI.Object, Hashable, Sendable {
        private enum CodingKeys: String, CodingKey {
            case embedding
            case index
        }
        
        public let embedding: [Double]
        public let index: Int
        
        public required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.embedding = try container.decode(forKey: .embedding)
            self.index = try container.decode(forKey: .index)
            
            try super.init(from: decoder)
        }
                
        public override func encode(to encoder: Encoder) throws {
            try super.encode(to: encoder)
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(embedding, forKey: .embedding)
            try container.encode(index, forKey: .index)
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(embedding)
            hasher.combine(index)
        }
        
        public static func == (lhs: Embedding, rhs: Embedding) -> Bool {
            lhs.embedding == rhs.embedding && lhs.index == rhs.index
        }
    }
    
    public final class TextCompletion: OpenAI.Object {
        private enum CodingKeys: String, CodingKey {
            case id
            case model
            case createdAt = "created"
            case choices
            case usage
        }
        
        public struct Choice: Codable, Hashable, Sendable {
            public enum FinishReason: String, Codable, Hashable, Sendable {
                case length = "length"
                case stop = "stop"
            }
            
            public let text: String
            public let index: Int
            public let logprobs: Int?
            public let finishReason: FinishReason?
        }

        public let id: String
        public let model: OpenAI.Model
        public let createdAt: Date
        public let choices: [Choice]
        public let usage: Usage
        
        public required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.id = try container.decode(forKey: .id)
            self.model = try container.decode(forKey: .model)
            self.createdAt = try container.decode(forKey: .createdAt)
            self.choices = try container.decode(forKey: .choices)
            self.usage = try container.decode(forKey: .usage)
            
            try super.init(from: decoder)
        }
        
        public override func encode(to encoder: Encoder) throws {
            try super.encode(to: encoder)
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(id, forKey: .id)
            try container.encode(model, forKey: .model)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encode(choices, forKey: .choices)
            try container.encode(usage, forKey: .usage)
        }
    }
    
    public final class ChatCompletion: OpenAI.Object {
        private enum CodingKeys: String, CodingKey {
            case id
            case model
            case createdAt = "created"
            case choices
            case usage
        }
        
        public struct Choice: Codable, Hashable, Sendable {
            public enum FinishReason: String, Codable, Hashable, Sendable {
                case length = "length"
                case stop = "stop"
                case functionCall = "function_call"
            }

            public let message: ChatMessage
            public let index: Int
            public let finishReason: FinishReason?
        }

        public let id: String
        public let model: OpenAI.Model
        public let createdAt: Date
        public let choices: [Choice]
        public let usage: Usage
        
        public required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.id = try container.decode(forKey: .id)
            self.model = try container.decode(forKey: .model)
            self.createdAt = try container.decode(forKey: .createdAt)
            self.choices = try container.decode(forKey: .choices)
            self.usage = try container.decode(forKey: .usage)
            
            try super.init(from: decoder)
        }
        
        public override func encode(to encoder: Encoder) throws {
            try super.encode(to: encoder)
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(id, forKey: .id)
            try container.encode(model, forKey: .model)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encode(choices, forKey: .choices)
            try container.encode(usage, forKey: .usage)
        }
    }
    
    public final class ChatCompletionChunk: OpenAI.Object {
        private enum CodingKeys: String, CodingKey {
            case id
            case model
            case createdAt = "created"
            case choices
        }
        
        public struct Choice: Codable, Hashable, Sendable {
            public struct Delta: Codable, Hashable, Sendable {
                public let role: ChatRole?
                public let content: String?
            }

            public enum FinishReason: String, Codable, Hashable, Sendable {
                case length = "length"
                case stop = "stop"
            }
            
            public var delta: Delta
            public let index: Int
            public let finishReason: FinishReason?
        }
        
        public let id: String
        public let model: OpenAI.Model
        public let createdAt: Date
        public let choices: [Choice]
        
        public required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.id = try container.decode(forKey: .id)
            self.model = try container.decode(forKey: .model)
            self.createdAt = try container.decode(forKey: .createdAt)
            self.choices = try container.decode(forKey: .choices)
            
            try super.init(from: decoder)
        }
        
        public override func encode(to encoder: Encoder) throws {
            try super.encode(to: encoder)
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(id, forKey: .id)
            try container.encode(model, forKey: .model)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encode(choices, forKey: .choices)
        }
    }
}
