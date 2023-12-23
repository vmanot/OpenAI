//
// Copyright (c) Vatsal Manot
//

import CoreGML
import LargeLanguageModels
import NetworkKit
import Swift

public protocol _OpenAI_ModelType: Codable, Hashable, RawRepresentable, Sendable where RawValue == String {
    var contextSize: Int { get throws }
}

extension OpenAI {
    public typealias _ModelType = _OpenAI_ModelType
}

extension OpenAI {
    public enum Model: CaseIterable, OpenAI._ModelType, Hashable {
        public private(set) static var allCases: [Model] = {
            var result: [Model] = []
            
            result += InstructGPT.allCases.map({ Self.instructGPT($0) })
            result += Embedding.allCases.map({ Self.embedding($0 )})
            result += Chat.allCases.map({ Self.chat($0) })
            
            return result
        }()
        
        case instructGPT(InstructGPT)
        case embedding(Embedding)
        case chat(Chat)
        
        /// Deprecated by OpenAI.
        case feature(Feature)
        /// Deprecated by OpenAI.
        case codex(Codex)
        
        case unknown(String)
        
        public var name: String {
            if let base = (base as? any Named) {
                return base.name.description
            } else {
                return base.rawValue
            }
        }
        
        private var base: any OpenAI._ModelType {
            switch self {
                case .instructGPT(let value):
                    return value
                case .codex(let value):
                    return value
                case .feature(let value):
                    return value
                case .embedding(let value):
                    return value
                case .chat(let value):
                    return value
                case .unknown:
                    assertionFailure(.unimplemented)
                    
                    return self
            }
        }
        
        public var contextSize: Int {
            get throws {
                try base.contextSize
            }
        }
    }
}

extension OpenAI.Model {
    public enum InstructGPT: String, OpenAI._ModelType, CaseIterable, CustomDebugStringConvertible {
        case ada = "text-ada-001"
        case babbage = "text-babbage-001"
        case curie = "text-curie-001"
        case davinci = "text-davinci-003"
        
        public var debugDescription: String {
            rawValue
        }
        
        public var contextSize: Int {
            get throws {
                switch self {
                    case .ada:
                        return 2048
                    case .babbage:
                        return 2048
                    case .curie:
                        return 2048
                    case .davinci:
                        return 4096
                }
            }
        }
    }
}

extension OpenAI.Model {
    public enum Codex: String, OpenAI._ModelType, CaseIterable {
        case davinci = "code-davinci-002"
        case cushman = "code-cushman-001"
        
        public var contextSize: Int {
            switch self {
                case .davinci:
                    return 8000
                case .cushman:
                    return 2048
            }
        }
    }
}

extension OpenAI.Model {
    public enum Feature: String, OpenAI._ModelType, CaseIterable {
        case davinci = "text-davinci-edit-001"
        
        public var contextSize: Int {
            switch self {
                case .davinci:
                    return 2048
            }
        }
    }
}

extension OpenAI.Model {
    public enum Embedding: String, OpenAI._ModelType, CaseIterable {
        /// https://openai.com/blog/new-and-improved-embedding-model/
        case ada = "text-embedding-ada-002"
        
        public var dimensionCount: Int {
            switch self {
                case .ada:
                    return 1536
            }
        }
        
        public var contextSize: Int {
            switch self {
                case .ada:
                    return 8192
            }
        }
        
        public init?(rawValue: String) {
            switch rawValue {
                case Embedding.ada.rawValue:
                    self = .ada
                case "text-embedding-ada-002-v2":
                    self = .ada
                default:
                    return nil
            }
        }
    }
}

extension OpenAI.Model {
    public enum Chat: String, Named, OpenAI._ModelType, CaseIterable {
        case gpt_3_5_turbo = "gpt-3.5-turbo"
        case gpt_3_5_turbo_16k = "gpt-3.5-turbo-16k"
        
        case gpt_4 = "gpt-4"
        case gpt_4_32k = "gpt-4-32k"
        case gpt_4_1106_preview = "gpt-4-1106-preview"
        case gpt_4_vision_preview = "gpt-4-vision-preview"
        
        case gpt_3_5_turbo_0301 = "gpt-3.5-turbo-0301"
        case gpt_3_5_turbo_0613 = "gpt-3.5-turbo-0613"
        case gpt_3_5_turbo_16k_0613 = "gpt-3.5-turbo-16k-0613"
        
        case gpt_4_0314 = "gpt-4-0314"
        case gpt_4_0613 = "gpt-4-0613"
        case gpt_4_32k_0314 = "gpt-4-32k-0314"
        case gpt_4_32k_0613 = "gpt-4-32k-0613"
        
        public var name: String {
            switch self {
                case .gpt_3_5_turbo:
                    return "ChatGPT 3.5"
                case .gpt_3_5_turbo_16k:
                    return "ChatGPT 3.5"
                case .gpt_4:
                    return "ChatGPT 4"
                case .gpt_4_32k:
                    return "ChatGPT 4"
                case .gpt_4_1106_preview:
                    return "GPT-4 Turbo"
                case .gpt_4_vision_preview:
                    return "GPT-4V"
                case .gpt_3_5_turbo_0301:
                    return "GPT-3.5"
                case .gpt_3_5_turbo_0613:
                    return "GPT-3.5"
                case .gpt_3_5_turbo_16k_0613:
                    return "GPT-3.5"
                case .gpt_4_0314:
                    return "GPT-4"
                case .gpt_4_0613:
                    return "GPT-4"
                case .gpt_4_32k_0314:
                    return "GPT-4"
                case .gpt_4_32k_0613:
                    return "GPT-4"
            }
        }
        
        public var contextSize: Int {
            let _4k = 4096
            let _8k = 8192
            let _16k = 16384
            let _32k = 16384
            
            // let _128k = 131072
            
            switch self {
                case .gpt_3_5_turbo:
                    return _4k
                case .gpt_3_5_turbo_16k:
                    return _16k
                case .gpt_4:
                    return _8k
                case .gpt_4_32k:
                    return _32k
                case .gpt_3_5_turbo_0301:
                    return _4k
                case .gpt_3_5_turbo_0613:
                    return _4k
                case .gpt_3_5_turbo_16k_0613:
                    return _16k
                case .gpt_4_0314:
                    return _8k
                case .gpt_4_0613:
                    return _8k
                case .gpt_4_32k_0314:
                    return _32k
                case .gpt_4_32k_0613:
                    return _32k
                case .gpt_4_1106_preview:
                    return 4096 // FIXME!!!
                case .gpt_4_vision_preview:
                    return 4096 // FIXME!!!
            }
        }
    }
}

// MARK: - Conformances

extension OpenAI.Model: Codable {
    public init(from decoder: Decoder) throws {
        self = try Self(rawValue: try String(from: decoder)).unwrap()
    }
    
    public func encode(to encoder: Encoder) throws {
        try rawValue.encode(to: encoder)
    }
}

extension OpenAI.Model: _GMLModelIdentifierRepresentable {
    private enum _DecodingError: Error {
        case invalidModelProvider
    }
    
    public init(from model: _GMLModelIdentifier) throws {
        guard model.provider == .openAI else {
            throw _DecodingError.invalidModelProvider
        }
        
        self = try Self(rawValue: model.name).unwrap()
    }
    
    public func __conversion() -> _GMLModelIdentifier {
        _GMLModelIdentifier(
            provider: .openAI,
            name: rawValue,
            revision: nil
        )
    }
}

extension OpenAI.Model: RawRepresentable {
    public var rawValue: String {
        switch self {
            case .instructGPT(let model):
                return model.rawValue
            case .codex(let model):
                return model.rawValue
            case .feature(let model):
                return model.rawValue
            case .embedding(let model):
                return model.rawValue
            case .chat(let model):
                return model.rawValue
            case .unknown(let rawValue):
                return rawValue
        }
    }
    
    public init?(rawValue: String) {
        if let model = InstructGPT(rawValue: rawValue) {
            self = .instructGPT(model)
        } else if let model = Codex(rawValue: rawValue) {
            self = .codex(model)
        } else if let model = Feature(rawValue: rawValue) {
            self = .feature(model)
        } else if let model = Embedding(rawValue: rawValue) {
            self = .embedding(model)
        } else if let model = Chat(rawValue: rawValue) {
            self = .chat(model)
        } else {
            self = .unknown(rawValue)
        }
    }
}
