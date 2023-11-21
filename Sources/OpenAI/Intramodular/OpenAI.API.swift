//
// Copyright (c) Vatsal Manot
//

import CorePersistence
import Diagnostics
import NetworkKit
import Swift
import SwiftAPI

extension OpenAI {
    public enum APIError: APIErrorProtocol {
        public typealias API = OpenAI.API
        
        case apiKeyMissing
        case incorrectAPIKeyProvided
        case rateLimitExceeded
        case invalidContentType
        case badRequest(API.Request.Error)
        case runtime(AnyError)
        
        public var traits: ErrorTraits {
            [.domain(.networking)]
        }
    }
    
    public struct API: RESTAPISpecification {
        public typealias Error = APIError

        public struct Configuration: Codable, Hashable {
            public var apiKey: String?
        }

        public var host: URL = URL(string: "https://api.openai.com")!
        
        public let configuration: Configuration
        
        public var id: some Hashable {
            configuration
        }
        
        public init(configuration: Configuration) {
            self.configuration = configuration
        }
        
        @POST
        @Path("/v1/embeddings")
        public var createEmbeddings = Endpoint<RequestBodies.CreateEmbedding, ResponseBodies.CreateEmbedding, Void>()
        
        @POST
        @Path("/v1/completions")
        public var createCompletions = Endpoint<RequestBodies.CreateCompletion, OpenAI.TextCompletion, Void>()
        
        @POST
        @Path("/v1/chat/completions")
        public var createChatCompletions = Endpoint<RequestBodies.CreateChatCompletion, OpenAI.ChatCompletion, Void>()
    }
}

extension OpenAI.API {
    public final class Endpoint<Input, Output, Options>: BaseHTTPEndpoint<OpenAI.API, Input, Output, Options> {
        override public func buildRequestBase(
            from input: Input,
            context: BuildRequestContext
        ) throws -> Request {
            let configuration = context.root.configuration
            
            var request = try super.buildRequestBase(from: input, context: context)
                .jsonBody(input, keyEncodingStrategy: .convertToSnakeCase)
            
            if let apiKey = configuration.apiKey {
                request = request.header(.authorization(.bearer, apiKey))
            }
            
            return request
        }
        
        struct _ErrorWrapper: Codable, Hashable, Sendable {
            struct Error: Codable, Hashable, Sendable {
                let type: String
                let param: AnyCodable?
                let message: String
            }
            
            let error: Error
        }
        
        override public func decodeOutputBase(
            from response: Request.Response,
            context: DecodeOutputContext
        ) throws -> Output {
            do {
                try response.validate()
            } catch {
                let apiError: Error
                
                if let error = error as? Request.Error {
                    if let error = try? response.decode(
                        _ErrorWrapper.self,
                        keyDecodingStrategy: .convertFromSnakeCase
                    ).error {
                        if error.message.contains("You didn't provide an API key") {
                            throw Error.apiKeyMissing
                        } else if error.message.contains("Incorrect API key provided") {
                            throw Error.incorrectAPIKeyProvided
                        } else if error.message.contains("Invalid content type.") {
                            throw Error.invalidContentType
                        }
                    }

                    if response.statusCode.rawValue == 429 {
                        apiError = .rateLimitExceeded
                    } else {
                        apiError = .badRequest(error)
                    }
                } else {
                    apiError = .runtime(error)
                }
                
                throw apiError
            }
            
            return try response.decode(
                Output.self,
                keyDecodingStrategy: .convertFromSnakeCase
            )
        }
    }
}

// MARK: - Request & Response Bodies -

extension OpenAI.API {
    public enum RequestBodies {
        
    }
}

extension OpenAI.API {
    public enum ResponseBodies {
        
    }
}

extension OpenAI.API.RequestBodies {
    public struct CreateCompletion: Codable, Hashable {
        public let prompt: Either<String, [String]>
        public let model: OpenAI.Model
        public let suffix: String?
        public let maxTokens: Int?
        public let temperature: Double?
        public let topP: Double?
        public let n: Int?
        public let stream: Bool?
        public let logprobs: Int?
        public let stop: Either<String, [String]>?
        public let presencePenalty: Double?
        public let frequencyPenalty: Double?
        public let bestOf: Int?
        public let logitBias: [String: Int]?
        public let user: String?
        
        public init(
            prompt: Either<String, [String]>,
            model: OpenAI.Model,
            suffix: String?,
            maxTokens: Int?,
            temperature: Double? = 1,
            topP: Double? = 1,
            n: Int? = 1,
            stream: Bool?,
            logprobs: Int?,
            stop: Either<String, [String]>?,
            presencePenalty: Double?,
            frequencyPenalty: Double?,
            bestOf: Int?,
            logitBias: [String: Int]?,
            user: String?
        ) {
            if let bestOf = bestOf {
                if let n = n, n != 1, bestOf != 1 {
                    assert(bestOf > n)
                }
            }
            
            self.prompt = prompt
            self.model = model
            self.suffix = suffix
            self.maxTokens = maxTokens
            self.temperature = temperature
            self.topP = topP
            self.n = n
            self.stream = stream
            self.logprobs = logprobs
            self.stop = stop?.nilIfEmpty()
            self.presencePenalty = presencePenalty
            self.frequencyPenalty = frequencyPenalty
            self.bestOf = bestOf
            self.logitBias = logitBias
            self.user = user
        }
        
        public init(
            prompt: Either<String, [String]>,
            model: OpenAI.Model,
            parameters: OpenAI.APIClient.TextCompletionParameters,
            stream: Bool
        ) {
            self.init(
                prompt: prompt,
                model: model,
                suffix: parameters.suffix,
                maxTokens: parameters.maxTokens,
                temperature: parameters.temperature,
                topP: parameters.topProbabilityMass,
                n: parameters.n,
                stream: stream,
                logprobs: parameters.logprobs,
                stop: parameters.stop?.nilIfEmpty(),
                presencePenalty: parameters.presencePenalty,
                frequencyPenalty: parameters.frequencyPenalty,
                bestOf: parameters.bestOf,
                logitBias: parameters.logitBias,
                user: parameters.user
            )
        }
    }
}

extension OpenAI.API.RequestBodies {
    public struct CreateEmbedding: Codable, Hashable {
        public let model: OpenAI.Model.Embedding
        public let input: [String]
    }
}

extension OpenAI.API.RequestBodies {
    public struct CreateChatCompletion: Codable, Hashable {
        private enum CodingKeys: String, CodingKey {
            case user
            case messages
            case functions = "functions"
            case functionCallingStrategy = "function_call"
            case model
            case temperature
            case topProbabilityMass = "top_p"
            case choices = "n"
            case stream
            case stop
            case maxTokens = "max_tokens"
            case presencePenalty = "presence_penalty"
            case frequencyPenalty = "frequency_penalty"
        }
        
        public let user: String?
        public let messages: [OpenAI.ChatMessage]
        public let functions: [OpenAI.ChatFunctionDefinition]?
        public let functionCallingStrategy: OpenAI.FunctionCallingStrategy?
        public let model: OpenAI.Model
        public let temperature: Double?
        public let topProbabilityMass: Double?
        public let choices: Int?
        public let stream: Bool?
        public let stop: [String]?
        public let maxTokens: Int?
        public let presencePenalty: Double?
        public let frequencyPenalty: Double?
        
        public init(
            user: String?,
            messages: [OpenAI.ChatMessage],
            functions: [OpenAI.ChatFunctionDefinition]?,
            functionCallingStrategy: OpenAI.FunctionCallingStrategy?,
            model: OpenAI.Model,
            temperature: Double?,
            topProbabilityMass: Double?,
            choices: Int?,
            stream: Bool?,
            stop: [String]?,
            maxTokens: Int?,
            presencePenalty: Double?,
            frequencyPenalty: Double?
        ) {
            self.user = user
            self.messages = messages
            self.functions = functions.nilIfEmpty()
            self.functionCallingStrategy = functions == nil ? nil : functionCallingStrategy
            self.model = model
            self.temperature = temperature
            self.topProbabilityMass = topProbabilityMass
            self.choices = choices
            self.stream = stream
            self.stop = stop
            self.maxTokens = maxTokens
            self.presencePenalty = presencePenalty
            self.frequencyPenalty = frequencyPenalty
        }
    }
}

extension OpenAI.API.RequestBodies.CreateChatCompletion {
    public struct ChatFunctionDefinition: Codable, Hashable {
        public let name: String
        public let description: String
        public let parameters: JSONSchema
        
        public init(name: String, description: String, parameters: JSONSchema) {
            self.name = name
            self.description = description
            self.parameters = parameters
        }
    }
}

extension OpenAI.API.ResponseBodies {
    public final class CreateEmbedding: OpenAI.List<OpenAI.Embedding> {
        private enum CodingKeys: String, CodingKey {
            case model
            case usage
        }
        
        public let model: OpenAI.Model.Embedding
        public let usage: OpenAI.Usage
        
        public required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.model = try container.decode(forKey: .model)
            self.usage = try container.decode(forKey: .usage)
            
            try super.init(from: decoder)
        }
        
        public override func encode(to encoder: Encoder) throws {
            try super.encode(to: encoder)
            
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(model, forKey: .model)
            try container.encode(usage, forKey: .usage)
        }
    }
    
    public struct CreateChatCompletion: Codable, Hashable {
        public let message: OpenAI.ChatMessage
    }
}
