//
// Copyright (c) Vatsal Manot
//

import CorePersistence
import Diagnostics
import LargeLanguageModels
import Merge
import Swallow

extension OpenAI.APIClient: DependenciesExporting {
    public var exportedDependencies: Dependencies {
        var result = Dependencies()
        
        result[\.llmServices] = self
        result[\.textEmbeddingsProvider] = self
        
        return result
    }
}

extension OpenAI.APIClient: LargeLanguageModelServices {
    public var _availableLLMs: [_MLModelIdentifier]? {
        nil
    }
    
    public func complete<Prompt: AbstractLLM.Prompt>(
        prompt: Prompt,
        parameters: Prompt.CompletionParameters,
        heuristics: AbstractLLM.CompletionHeuristics
    ) async throws -> Prompt.Completion {
        let _completion: Any
        
        switch prompt {
            case let prompt as AbstractLLM.TextPrompt:
                _completion = try await _complete(
                    prompt: prompt,
                    parameters: try cast(parameters),
                    heuristics: heuristics
                )
                
            case let prompt as AbstractLLM.ChatPrompt:
                _completion = try await _complete(
                    prompt: prompt,
                    parameters: try cast(parameters),
                    heuristics: heuristics
                )
            default:
                throw LargeLanguageModelServicesError.unsupportedPromptType(Prompt.self)
        }
        
        return try cast(_completion)
    }
    
    private func _complete(
        prompt: AbstractLLM.TextPrompt,
        parameters: AbstractLLM.TextCompletionParameters,
        heuristics: AbstractLLM.CompletionHeuristics
    ) async throws -> AbstractLLM.TextCompletion {
        let parameters = try cast(parameters, to: AbstractLLM.TextCompletionParameters.self)
        
        let model = OpenAI.Model.instructGPT(.davinci)
        
        let promptText = try prompt.prefix.promptLiteral
        let completion = try await self.createCompletion(
            model: model,
            prompt: promptText._stripToText(),
            parameters: .init(
                from: parameters,
                model: model,
                prompt: prompt.prefix
            )
        )
        
        let text = try completion.choices.toCollectionOfOne().first.text
        
        let debug = String.concatenate(separator: "\n") {
            "==="
            "Prompt:"
            prompt.debugDescription
                .delimited(by: .quotationMark)
                .delimited(by: "\n")
            "==="
            "Completion:"
            text
                .delimited(by: .quotationMark)
                .delimited(by: "\n")
            "==="
        }
        
        if _isDebugAssertConfiguration {
            print(debug)
        }
        
        return .init(prefix: promptText, text: text)
    }
    
    private func _complete(
        prompt: AbstractLLM.ChatPrompt,
        parameters: AbstractLLM.ChatCompletionParameters,
        heuristics: AbstractLLM.CompletionHeuristics
    ) async throws -> AbstractLLM.ChatCompletion {
        var prompt = prompt
        let parameters = try cast(parameters, to: AbstractLLM.ChatCompletionParameters.self)
        
        let model: OpenAI.Model
        
        let containsImage = prompt.messages.contains(where: { $0.content._containsImages })

        if containsImage {
            model = .chat(.gpt_4_vision_preview)
        } else if heuristics.wantsMaximumReasoning {
            model = .chat(.gpt_4_1106_preview)
        } else {
            model = .chat(.gpt_3_5_turbo)
        }
                
        if model == .chat(.gpt_3_5_turbo) {
            prompt.messages._forEach(mutating: {
                if $0.role == .system {
                    $0 = .init(role: .user, content: $0.content)
                }
            })
        }
        
        let completion = try await self.createChatCompletion(
            messages: prompt.messages.map({ try OpenAI.ChatMessage(from: $0) }),
            model: model,
            parameters: .init(
                from: parameters,
                model: model,
                messages: prompt.messages
            )
        )
        
        let message = try completion.choices.toCollectionOfOne().first.message
        
        let debug = String.concatenate(separator: "\n") {
            "==="
            "Prompt:"
            prompt.debugDescription
            "==="
            "Completion:"
            message.body
                .description
                .delimited(by: .quotationMark)
                .delimited(by: "\n")
            "==="
        }
        
        if _isDebugAssertConfiguration {
            print(debug)
        }
        
        return .init(message: try .init(from: message))
    }
}

extension OpenAI.APIClient: TextEmbeddingsProvider {
    public func fulfill(
        _ request: TextEmbeddingsGenerationRequest
    ) async throws -> TextEmbeddings {
        guard !request.strings.isEmpty else {
            return TextEmbeddings(
                model: .init(from: OpenAI.Model.Embedding.ada),
                data: []
            )
        }
        
        let model = _MLModelIdentifier(from: OpenAI.Model.Embedding.ada)
        
        if request.model != nil {
            try _tryAssert(request.model == model)
        }
        
        let embeddings = try await createEmbeddings(
            model: .ada,
            for: request.strings
        ).data
        
        try _tryAssert(request.strings.count == embeddings.count)
        
        return TextEmbeddings(
            model: .init(from: OpenAI.Model.Embedding.ada),
            data: request.strings.zip(embeddings).map {
                TextEmbeddings.Element(
                    text: $0,
                    embedding: $1.embedding
                )
            }
        )
    }
}

// MARK: - Auxiliary

extension _MLModelIdentifier {
    public init(from model: OpenAI.Model.InstructGPT) {
        self.init(provider: .openAI, name: model.rawValue, revision: nil)
    }
    
    public init(from model: OpenAI.Model.Chat) {
        self.init(provider: .openAI, name: model.rawValue, revision: nil)
    }
    
    public init(from model: OpenAI.Model.Embedding) {
        self.init(provider: .openAI, name: model.rawValue, revision: nil)
    }
}

extension OpenAI.APIClient.TextCompletionParameters {
    public init(
        from parameters: AbstractLLM.TextCompletionParameters,
        model: OpenAI.Model,
        prompt _: any PromptLiteralConvertible
    ) throws {
        self.init(
            maxTokens: try model.contextSize / 2, // FIXME!!!
            temperature: parameters.temperatureOrTopP?.temperature,
            topProbabilityMass: parameters.temperatureOrTopP?.topProbabilityMass,
            stop: parameters.stops.map(Either.right)
        )
    }
}

extension OpenAI.APIClient.ChatCompletionParameters {
    public init(
        from parameters: AbstractLLM.ChatCompletionParameters,
        model: OpenAI.Model,
        messages _: [AbstractLLM.ChatMessage]
    ) throws {
        self.init(
            temperature: parameters.temperatureOrTopP?.temperature,
            topProbabilityMass: parameters.temperatureOrTopP?.topProbabilityMass,
            stop: parameters.stops,
            maxTokens: try model.contextSize / 2, // FIXME!!!
            functions: parameters.functions?.map {
                OpenAI.ChatFunctionDefinition(from: $0)
            }
        )
    }
}

extension OpenAI.ChatMessage {
    public init(from message: AbstractLLM.ChatMessage) throws {
        let role: OpenAI.ChatRole
        
        switch message.role {
            case .system:
                role = .system
            case .user:
                role = .user
            case .assistant:
                role = .assistant
            case .other(.function):
                role = .function
        }
        
        let _content = try message.content._degenerate()
        
        if _content.components.contains(where: { $0.payload.type == .functionCall || $0.payload.type == .functionInvocation }) {
            switch try _content.components.toCollectionOfOne().value.payload {
                case .functionCall(let call):
                    self.init(
                        role: role,
                        body: .functionCall(.init(name: call.name, arguments: call.arguments))
                    )
                case .functionInvocation(let invocation):
                    self.init(
                        role: role,
                        body: .functionInvocation(.init(name: invocation.name, response: invocation.result.rawValue))
                    )
                default:
                    assertionFailure("Unsupported prompt literal.")
                    
                    throw Never.Reason.illegal
            }
        } else {
            var _temp = Self(role: role, body: .content([]))
            
            try message.content._encode(to: &_temp)
            
            self = _temp
        }
    }
}
 
extension OpenAI.ChatMessage: _PromptLiteralEncodingContainer {
    public mutating func encode(_ component: PromptLiteral._Degenerate.Component) throws {
        var content: [OpenAI.ChatMessageBody._Content] = []
        
        switch self.body {
            case .text(let _content):
                content.append(.text(_content))
            case .content(let _content):
                content = _content
            case .functionCall(_):
                throw Never.Reason.unsupported
            case .functionInvocation(_):
                throw Never.Reason.unsupported
        }
        
        switch component.payload {
            case .string(let string):
                content.append(.text(string))
            case .image(let image):
                switch image {
                    case .url(let url):
                        content.append(
                            .imageURL(
                                .init(
                                    url: url,
                                    detail: .auto // FIXME
                                )
                            )
                        )

                }
            case .dynamicVariable:
                throw Never.Reason.unsupported
            case .functionCall:
                throw Never.Reason.unsupported
            case .functionInvocation:
                throw Never.Reason.unsupported
        }
        
        self = .init(role: role, body: .content(content))
    }
}

extension AbstractLLM.ChatMessage {
    public init(from message: OpenAI.ChatMessage) throws {
        let role: AbstractLLM.ChatRole
        
        switch message.role {
            case .system:
                role = .system
            case .user:
                role = .user
            case .assistant:
                role = .assistant
            case .function:
                role = .other(.function)
        }
        
        switch message.body {
            case .text(let content):
                self.init(role: role, content: PromptLiteral(content, role: .chat(role)))
            case .content(let content):
                self.init(role: role, content: PromptLiteral(content, role: .chat(role)))
            case .functionCall(let call):
                self.init(
                    role: role,
                    content: try PromptLiteral(functionCall: .init(name: call.name, arguments: call.arguments), role: .chat(role))
                )
            case .functionInvocation(let invocation):
                self.init(
                    role: role,
                    content: try .init(
                        functionInvocation: .init(
                            name: invocation.name,
                            result: .init(rawValue: invocation.response)
                        ),
                        role: .chat(role)
                    )
                )
        }
    }
}

extension OpenAI.ChatFunctionDefinition {
    public init(from function: AbstractLLM.ChatFunctionDefinition) {
        self.init(
            name: function.name,
            description: function.context,
            parameters: function.parameters
        )
    }
}

extension PromptLiteral {
    public init(
        _ content: [OpenAI.ChatMessageBody._Content],
        role: PromptMatterRole
    ) {
        
        fatalError()
       // self.init("", role: role)
    }
}
