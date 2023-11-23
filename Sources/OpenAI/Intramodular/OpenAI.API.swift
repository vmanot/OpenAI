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
        
        // MARK: Embeddings

        @POST
        @Path("/v1/embeddings")
        @Body(json: \.input, keyEncodingStrategy: .convertToSnakeCase)
        public var createEmbeddings = Endpoint<RequestBodies.CreateEmbedding, ResponseBodies.CreateEmbedding, Void>()
        
        // MARK: Completions
        
        @POST
        @Path("/v1/completions")
        @Body(json: \.input, keyEncodingStrategy: .convertToSnakeCase)
        public var createCompletions = Endpoint<RequestBodies.CreateCompletion, OpenAI.TextCompletion, Void>()
        
        @POST
        @Body(json: \.input, keyEncodingStrategy: .convertToSnakeCase)
        @Path("/v1/chat/completions")
        public var createChatCompletions = Endpoint<RequestBodies.CreateChatCompletion, OpenAI.ChatCompletion, Void>()
        
        // MARK: Threads
        
        @Header(["OpenAI-Beta": "assistants=v1"])
        @POST
        @Path("/v1/threads")
        @Body(json: \.input, keyEncodingStrategy: .convertToSnakeCase)
        public var createThread = Endpoint<RequestBodies.CreateThread, OpenAI.Thread, Void>()
        
        @Header(["OpenAI-Beta": "assistants=v1"])
        @GET
        @Path({ context -> String in
            "/v1/threads/\(context.input)"
        })
        public var retrieveThread = Endpoint<String, OpenAI.Thread, Void>()
        
        @Header(["OpenAI-Beta": "assistants=v1"])
        @DELETE
        @Path({ context -> String in
            "/v1/threads/\(context.input)"
        })
        public var deleteThread = Endpoint<String, JSON, Void>()
        
        // MARK: Messages
        
        @Header(["OpenAI-Beta": "assistants=v1"])
        @POST
        @Path({ context -> String in
            "/v1/threads/\(context.input.thread)/messages"
        })
        @Body(json: \.requestBody, keyEncodingStrategy: .convertToSnakeCase)
        public var createMessageForThread = Endpoint<
            (thread: String, requestBody: OpenAI.API.RequestBodies.CreateMessage),
            OpenAI.Message,
            Void
        >()
        
        @Header(["OpenAI-Beta": "assistants=v1"])
        @GET
        @Path({ context -> String in
            "/v1/threads/\(context.input)/messages"
        })
        public var listMessagesForThread = Endpoint<String, OpenAI.List<OpenAI.Message>, Void>()
    }
}

extension OpenAI.API {
    public final class Endpoint<Input, Output, Options>: BaseHTTPEndpoint<OpenAI.API, Input, Output, Options> {
        override public func buildRequestBase(
            from input: Input,
            context: BuildRequestContext
        ) throws -> Request {
            let configuration = context.root.configuration
            
            var request = try super.buildRequestBase(
                from: input,
                context: context
            )
            
            if let apiKey = configuration.apiKey {
                request = request.header(.authorization(.bearer, apiKey))
            }
            
            return request
        }
        
        struct _ErrorWrapper: Codable, Hashable, Sendable {
            public struct Error: Codable, Hashable, LocalizedError, Sendable {
                public let type: String
                public let param: AnyCodable?
                public let message: String
                
                public var errorDescription: String? {
                    message
                }
            }
            
            public let error: Error
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
                    let errorWrapper = try? response.decode(
                        _ErrorWrapper.self,
                        keyDecodingStrategy: .convertFromSnakeCase
                    )
                    
                    if let _error: _ErrorWrapper.Error = errorWrapper?.error {
                        if _error.message.contains("You didn't provide an API key") {
                            throw Error.apiKeyMissing
                        } else if _error.message.contains("Incorrect API key provided") {
                            throw Error.incorrectAPIKeyProvided
                        } else if _error.message.contains("Invalid content type.") {
                            throw Error.invalidContentType
                        } else {
                            runtimeIssue(_error)
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
