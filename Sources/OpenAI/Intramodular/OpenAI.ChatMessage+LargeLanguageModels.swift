//
// Copyright (c) Vatsal Manot
//

@_spi(Internal) import LargeLanguageModels

extension OpenAI.ChatMessage: _PromptLiteralEncodingContainer {
    public mutating func encode(
        _ component: PromptLiteral._Degenerate.Component
    ) throws {
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
            case .functionCall:
                throw Never.Reason.unsupported
            case .functionInvocation:
                throw Never.Reason.unsupported
        }
        
        self = .init(role: role, body: .content(content))
    }
}

extension OpenAI.ChatMessage {
    public init(
        from message: AbstractLLM.ChatMessage
    ) throws {
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

extension AbstractLLM.ChatMessage {
    public init(
        from message: OpenAI.ChatMessage
    ) throws {
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
                self.init(
                    role: role,
                    content: PromptLiteral(
                        content,
                        role: .chat(role)
                    )
                )
            case .content(let content):
                self.init(
                    role: role,
                    content: PromptLiteral(
                        from: content,
                        role: .chat(role)
                    )
                )
            case .functionCall(let call):
                self.init(
                    role: role,
                    content: try PromptLiteral(
                        functionCall: .init(name: call.name, arguments: call.arguments),
                        role: .chat(role)
                    )
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

extension PromptLiteral {
    init(
        from contents: [OpenAI.ChatMessageBody._Content],
        role: PromptMatterRole
    ) {
        var components: [PromptLiteral.StringInterpolation.Component] = []
                
        for content in contents {
            switch content {
                case .text(let content):
                    components.append(PromptLiteral.StringInterpolation.Component(payload: .stringLiteral(content), role: role))
                case .imageURL(let image):
                    assert(image.detail == .auto) // FIXME
                    
                    components.append(PromptLiteral.StringInterpolation.Component(payload: .image(.url(image.url)), role: role))
            }
        }
        
        self.init(stringInterpolation: .init(components: components))
    }
}
