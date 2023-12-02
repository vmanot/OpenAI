//
// Copyright (c) Vatsal Manot
//

import CorePersistence
import Diagnostics
@_spi(Internal) import LargeLanguageModels
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
    public var _availableLargeLanguageModels: [_MLModelIdentifier]? {
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
        
        _debugPrint(
            prompt: prompt.debugDescription
                .delimited(by: .quotationMark)
                .delimited(by: "\n")
            ,
            completion: text
                .delimited(by: .quotationMark)
                .delimited(by: "\n")
        )

        
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
        
        let containsImage = try prompt.messages.contains(where: { try $0.content._containsImages })
        
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
        
        _debugPrint(
            prompt: prompt.debugDescription,
            completion: message.body
                .description
                .delimited(by: .quotationMark)
                .delimited(by: "\n")
        )
            
        return .init(message: try .init(from: message))
    }
    
    private func _debugPrint(prompt: String, completion: String) {
        guard _isDebugAssertConfiguration else {
            return
        }
        
        let description = String.concatenate(separator: "\n") {
            "=== [PROMPT START] ==="
            prompt.debugDescription
                .delimited(by: .quotationMark)
                .delimited(by: "\n")
            "==== [COMPLETION] ===="
            completion
                .delimited(by: .quotationMark)
                .delimited(by: "\n")
            "==== [PROMPT END] ===="
        }
        
        print(description)
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
    public init(
        from model: OpenAI.Model.InstructGPT
    ) {
        self.init(provider: .openAI, name: model.rawValue, revision: nil)
    }
    
    public init(
        from model: OpenAI.Model.Chat
    ) {
        self.init(provider: .openAI, name: model.rawValue, revision: nil)
    }
    
    public init(
        from model: OpenAI.Model.Embedding
    ) {
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

extension OpenAI.ChatFunctionDefinition {
    public init(
        from function: AbstractLLM.ChatFunctionDefinition
    ) {
        self.init(
            name: function.name,
            description: function.context,
            parameters: function.parameters
        )
    }
}
