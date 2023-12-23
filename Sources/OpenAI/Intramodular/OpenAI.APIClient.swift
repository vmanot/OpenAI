//
// Copyright (c) Vatsal Manot
//

import LargeLanguageModels
import NetworkKit
import Swift

extension OpenAI {
    public final class APIClient: HTTPClient, PersistentlyRepresentableType {
        public static var persistentTypeRepresentation: some IdentityRepresentation {
            _GMLModelServiceTypeIdentifier._OpenAI
        }

        public let interface: API
        public let session: HTTPSession
        
        public init(interface: API, session: HTTPSession) {
            self.interface = interface
            self.session = session
        }
        
        public convenience init(apiKey: String?) {
            self.init(
                interface: .init(configuration: .init(apiKey: apiKey)),
                session: .shared
            )
        }
    }
}

extension OpenAI.APIClient {
    public func createEmbeddings(
        model: OpenAI.Model.Embedding,
        for input: [String]
    ) async throws -> OpenAI.API.ResponseBodies.CreateEmbedding {
        try await run(\.createEmbeddings, with: .init(model: model, input: input))
    }
}

extension OpenAI.APIClient {
    public func createCompletion(
        model: OpenAI.Model,
        prompt: String,
        parameters: OpenAI.APIClient.TextCompletionParameters
    ) async throws -> OpenAI.TextCompletion {
        let requestBody = OpenAI.API.RequestBodies.CreateCompletion(
            prompt: .left(prompt),
            model: model,
            parameters: parameters,
            stream: false
        )
        
        return try await run(\.createCompletions, with: requestBody)
    }
    
    public func createCompletion(
        model: OpenAI.Model,
        prompts: [String],
        parameters: OpenAI.APIClient.TextCompletionParameters
    ) async throws -> OpenAI.TextCompletion {
        let requestBody = OpenAI.API.RequestBodies.CreateCompletion(
            prompt: .right(prompts),
            model: model,
            parameters: parameters,
            stream: false
        )
        
        return try await run(\.createCompletions, with: requestBody)
    }
    
    public func createChatCompletion(
        messages: [OpenAI.ChatMessage],
        model: OpenAI.Model,
        parameters: OpenAI.APIClient.ChatCompletionParameters
    ) async throws -> OpenAI.ChatCompletion {
        let requestBody = OpenAI.API.RequestBodies.CreateChatCompletion(
            messages: messages,
            model: model,
            parameters: parameters,
            stream: false
        )
        
        return try await run(\.createChatCompletions, with: requestBody)
    }
    
    public func createChatCompletion(
        messages: [OpenAI.ChatMessage],
        model: OpenAI.Model.Chat,
        parameters: OpenAI.APIClient.ChatCompletionParameters
    ) async throws -> OpenAI.ChatCompletion {
        try await createChatCompletion(
            messages: messages,
            model: .chat(model),
            parameters: parameters
        )
    }
    
    public func createTextOrChatCompletion(
        prompt: String,
        system: String?,
        model: OpenAI.Model,
        temperature: Double?,
        topProbabilityMass: Double?,
        maxTokens: Int?
    ) async throws -> Either<OpenAI.TextCompletion, OpenAI.ChatCompletion> {
        switch model {
            case .chat(let model): do {
                let messages: [OpenAI.ChatMessage] = system.map({ [.system($0), .user(prompt)] }) ?? [.user(prompt)]
                
                let result = try await createChatCompletion(
                    messages: messages,
                    model: model,
                    parameters: .init(temperature: temperature, topProbabilityMass: topProbabilityMass, maxTokens: maxTokens)
                )
                
                return .right(result)
            }
            case .instructGPT: do {
                let result = try await createCompletion(
                    model: model,
                    prompt: prompt,
                    parameters: .init(maxTokens: maxTokens, temperature: temperature, topProbabilityMass: topProbabilityMass)
                )
                
                return .left(result)
            }
            default:
                throw _PlaceholderError()
        }
    }
}

extension OpenAI.APIClient {
    @discardableResult
    public func createRun(
        threadID: OpenAI.Thread.ID,
        assistantID: String,
        model: OpenAI.Model? = nil,
        instructions: String? = nil,
        tools: [OpenAI.Tool]?,
        metadata: [String: String]? = nil
    ) async throws -> OpenAI.Run {
        let result = try await run(
            \.createRun,
             with: (
                thread: threadID,
                requestBody: .init(
                    assistantID: assistantID,
                    model: model,
                    instructions: instructions,
                    tools: tools,
                    metadata: metadata
                )
             )
        )
        
        return result
    }
    
    public func retrieve(
        run: OpenAI.Run.ID,
        thread: OpenAI.Thread.ID
    ) async throws -> OpenAI.Run {
        try await self.run(\.retrieveRunForThread, with: (thread, run))
    }
}

// MARK: - Auxiliary

extension OpenAI.APIClient {
    public struct TextCompletionParameters: Codable, Hashable {
        public var suffix: String?
        public var maxTokens: Int?
        public var temperature: Double?
        public var topProbabilityMass: Double?
        public var n: Int
        public var logprobs: Int?
        public var stop: Either<String, [String]>?
        public var presencePenalty: Double?
        public var frequencyPenalty: Double?
        public var bestOf: Int?
        public var logitBias: [String: Int]?
        public var user: String?
        
        public init(
            suffix: String? = nil,
            maxTokens: Int? = 16,
            temperature: Double? = 1,
            topProbabilityMass: Double? = 1,
            n: Int = 1,
            logprobs: Int? = nil,
            echo: Bool? = false,
            stop: Either<String, [String]>? = nil,
            presencePenalty: Double? = 0,
            frequencyPenalty: Double? = 0,
            bestOf: Int? = 1,
            logitBias: [String: Int]? = nil,
            user: String? = nil
        ) {
            self.suffix = suffix
            self.maxTokens = maxTokens
            self.temperature = temperature
            self.topProbabilityMass = topProbabilityMass
            self.n = n
            self.logprobs = logprobs
            self.stop = stop?.nilIfEmpty()
            self.presencePenalty = presencePenalty
            self.frequencyPenalty = frequencyPenalty
            self.bestOf = bestOf
            self.logitBias = logitBias
            self.user = user
        }
    }
    
    public struct ChatCompletionParameters: Codable, Hashable, Sendable {
        public let user: String?
        public let temperature: Double?
        public let topProbabilityMass: Double?
        public let choices: Int?
        public let stop: [String]?
        public let maxTokens: Int?
        public let presencePenalty: Double?
        public let frequencyPenalty: Double?
        public let functions: [OpenAI.ChatFunctionDefinition]?
        public let functionCallingStrategy: OpenAI.FunctionCallingStrategy?
        
        public init(
            user: String? = nil,
            temperature: Double? = nil,
            topProbabilityMass: Double? = nil,
            choices: Int? = nil,
            stop: [String]? = nil,
            maxTokens: Int? = nil,
            presencePenalty: Double? = nil,
            frequencyPenalty: Double? = nil,
            functions: [OpenAI.ChatFunctionDefinition]? = nil,
            functionCallingStrategy: OpenAI.FunctionCallingStrategy? = nil
        ) {
            self.user = user
            self.temperature = temperature
            self.topProbabilityMass = topProbabilityMass
            self.choices = choices
            self.stop = stop.nilIfEmpty()
            self.maxTokens = maxTokens
            self.presencePenalty = presencePenalty
            self.frequencyPenalty = frequencyPenalty
            self.functions = functions
            self.functionCallingStrategy = functionCallingStrategy
        }
    }
}
