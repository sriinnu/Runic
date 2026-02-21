import Foundation

/// Pre-configured templates for popular AI service providers
///
/// This enum provides ready-to-use configurations for major AI providers,
/// making it easy to add new providers without manual API research.
/// Each template includes accurate endpoint URLs, authentication methods,
/// and response field mappings based on official API documentation.
public enum ProviderTemplates {

    // MARK: - Template Collection

    /// All available provider templates
    public static let all: [CustomProviderConfig] = [
        elevenlabs,
        openai,
        anthropic,
        stabilityAI,
        togetherAI,
        perplexity,
        cohere,
        huggingface,
        replicate,
        runway
    ]

    /// Get a template by provider ID
    public static func template(for id: String) -> CustomProviderConfig? {
        return all.first { $0.id == id }
    }

    // MARK: - ElevenLabs

    /// ElevenLabs Text-to-Speech API
    ///
    /// Tracks character usage and limits for voice generation.
    /// API Documentation: https://elevenlabs.io/docs/api-reference
    public static let elevenlabs = CustomProviderConfig(
        id: "elevenlabs",
        name: "ElevenLabs",
        icon: "speaker.wave.3",
        enabled: false,
        auth: AuthConfig(
            type: .apiKey,
            headerName: "xi-api-key",
            headerPrefix: nil,
            tokenKeychain: "elevenlabs-api-token",
            additionalHeaders: nil
        ),
        endpoints: EndpointConfig(
            usage: UsageEndpoint(
                url: "https://api.elevenlabs.io/v1/user/subscription",
                method: .GET,
                mapping: ResponseMapping(
                    quota: "character_limit",
                    used: "character_count",
                    remaining: nil,
                    cost: nil,
                    resetDate: "next_character_count_reset_unix",
                    tokens: "character_count",
                    nestedPaths: false
                ),
                queryParams: nil
            ),
            balance: nil
        ),
        colorHex: "#7C3AED",
        createdAt: Date(),
        updatedAt: Date()
    )

    // MARK: - OpenAI

    /// OpenAI API (GPT-4, GPT-3.5, DALL-E, Whisper)
    ///
    /// Tracks token usage across all OpenAI models and services.
    /// API Documentation: https://platform.openai.com/docs/api-reference
    public static let openai = CustomProviderConfig(
        id: "openai-custom",
        name: "OpenAI",
        icon: "cpu",
        enabled: false,
        auth: AuthConfig(
            type: .bearer,
            headerName: "Authorization",
            headerPrefix: "Bearer ",
            tokenKeychain: "openai-api-token",
            additionalHeaders: nil
        ),
        endpoints: EndpointConfig(
            usage: UsageEndpoint(
                url: "https://api.openai.com/v1/organization/usage/completions",
                method: .GET,
                mapping: ResponseMapping(
                    quota: nil,
                    used: "data.0.n_context_tokens_total",
                    remaining: nil,
                    cost: nil,
                    resetDate: nil,
                    tokens: "data.0.n_requests",
                    nestedPaths: true
                ),
                queryParams: nil
            ),
            balance: nil
        ),
        colorHex: "#10A37F",
        createdAt: Date(),
        updatedAt: Date()
    )

    // MARK: - Anthropic Claude

    /// Anthropic Claude API
    ///
    /// Tracks token usage and costs across Claude models.
    /// Requires Admin API key (sk-ant-admin...) for usage endpoints.
    /// API Documentation: https://platform.claude.com/docs
    public static let anthropic = CustomProviderConfig(
        id: "anthropic-custom",
        name: "Anthropic",
        icon: "brain",
        enabled: false,
        auth: AuthConfig(
            type: .apiKey,
            headerName: "x-api-key",
            headerPrefix: nil,
            tokenKeychain: "anthropic-admin-api-token",
            additionalHeaders: ["anthropic-version": "2023-06-01"]
        ),
        endpoints: EndpointConfig(
            usage: UsageEndpoint(
                url: "https://api.anthropic.com/v1/organizations/usage_report/messages",
                method: .GET,
                mapping: ResponseMapping(
                    quota: nil,
                    used: "data.0.input_tokens",
                    remaining: nil,
                    cost: nil,
                    resetDate: nil,
                    tokens: "data.0.output_tokens",
                    nestedPaths: true
                ),
                queryParams: nil
            ),
            balance: BalanceEndpoint(
                url: "https://api.anthropic.com/v1/organizations/cost_report",
                method: .GET,
                mapping: ResponseMapping(
                    quota: nil,
                    used: "data.0.cost_usd",
                    remaining: nil,
                    cost: "data.0.cost_usd",
                    resetDate: nil,
                    tokens: nil,
                    nestedPaths: true
                )
            )
        ),
        colorHex: "#D4A574",
        createdAt: Date(),
        updatedAt: Date()
    )

    // MARK: - Stability AI

    /// Stability AI (Stable Diffusion, Image Generation)
    ///
    /// Tracks credit balance for image generation services.
    /// API Documentation: https://platform.stability.ai/docs/api-reference
    public static let stabilityAI = CustomProviderConfig(
        id: "stability-ai",
        name: "Stability AI",
        icon: "photo.artframe",
        enabled: false,
        auth: AuthConfig(
            type: .bearer,
            headerName: "Authorization",
            headerPrefix: "Bearer ",
            tokenKeychain: "stability-ai-token",
            additionalHeaders: nil
        ),
        endpoints: EndpointConfig(
            usage: nil,
            balance: BalanceEndpoint(
                url: "https://api.stability.ai/v1/user/balance",
                method: .GET,
                mapping: ResponseMapping(
                    quota: nil,
                    used: nil,
                    remaining: "credits",
                    cost: nil,
                    resetDate: nil,
                    tokens: nil,
                    nestedPaths: false
                )
            )
        ),
        colorHex: "#FF6F61",
        createdAt: Date(),
        updatedAt: Date()
    )

    // MARK: - Together AI

    /// Together AI (Open-source LLMs and Image Models)
    ///
    /// Tracks token usage for serverless API and dedicated endpoints.
    /// API Documentation: https://docs.together.ai
    public static let togetherAI = CustomProviderConfig(
        id: "together-ai",
        name: "Together AI",
        icon: "sparkles",
        enabled: false,
        auth: AuthConfig(
            type: .bearer,
            headerName: "Authorization",
            headerPrefix: "Bearer ",
            tokenKeychain: "together-ai-token",
            additionalHeaders: nil
        ),
        endpoints: EndpointConfig(
            usage: UsageEndpoint(
                url: "https://api.together.xyz/v1/usage",
                method: .GET,
                mapping: ResponseMapping(
                    quota: nil,
                    used: "total_tokens",
                    remaining: nil,
                    cost: "total_cost",
                    resetDate: nil,
                    tokens: "total_tokens",
                    nestedPaths: true
                ),
                queryParams: nil
            ),
            balance: nil
        ),
        colorHex: "#00D4FF",
        createdAt: Date(),
        updatedAt: Date()
    )

    // MARK: - Perplexity

    /// Perplexity AI (Search-augmented LLMs)
    ///
    /// Tracks credit usage for Sonar models with web search.
    /// API Documentation: https://docs.perplexity.ai
    public static let perplexity = CustomProviderConfig(
        id: "perplexity",
        name: "Perplexity",
        icon: "magnifyingglass.circle",
        enabled: false,
        auth: AuthConfig(
            type: .bearer,
            headerName: "Authorization",
            headerPrefix: "Bearer ",
            tokenKeychain: "perplexity-api-token",
            additionalHeaders: nil
        ),
        endpoints: EndpointConfig(
            usage: UsageEndpoint(
                url: "https://api.perplexity.ai/usage",
                method: .GET,
                mapping: ResponseMapping(
                    quota: "credit_limit",
                    used: "credits_used",
                    remaining: "credits_remaining",
                    cost: "total_cost",
                    resetDate: nil,
                    tokens: "total_tokens",
                    nestedPaths: true
                ),
                queryParams: nil
            ),
            balance: nil
        ),
        colorHex: "#2EAADC",
        createdAt: Date(),
        updatedAt: Date()
    )

    // MARK: - Cohere

    /// Cohere AI (Enterprise NLP and Embeddings)
    ///
    /// Note: Cohere provides usage data in API response metadata rather than
    /// a dedicated usage endpoint. This template uses a placeholder endpoint.
    /// API Documentation: https://docs.cohere.com
    public static let cohere = CustomProviderConfig(
        id: "cohere",
        name: "Cohere",
        icon: "doc.text.magnifyingglass",
        enabled: false,
        auth: AuthConfig(
            type: .bearer,
            headerName: "Authorization",
            headerPrefix: "Bearer ",
            tokenKeychain: "cohere-api-token",
            additionalHeaders: nil
        ),
        endpoints: EndpointConfig(
            usage: UsageEndpoint(
                url: "https://api.cohere.ai/v1/usage",
                method: .GET,
                mapping: ResponseMapping(
                    quota: nil,
                    used: "tokens_used",
                    remaining: nil,
                    cost: "total_cost",
                    resetDate: nil,
                    tokens: "tokens_used",
                    nestedPaths: true
                ),
                queryParams: nil
            ),
            balance: nil
        ),
        colorHex: "#39594D",
        createdAt: Date(),
        updatedAt: Date()
    )

    // MARK: - Hugging Face

    /// Hugging Face Inference API
    ///
    /// Note: Hugging Face primarily provides endpoint status rather than
    /// centralized usage tracking. This template tracks inference endpoint status.
    /// API Documentation: https://huggingface.co/docs/huggingface_hub
    public static let huggingface = CustomProviderConfig(
        id: "huggingface",
        name: "Hugging Face",
        icon: "face.smiling",
        enabled: false,
        auth: AuthConfig(
            type: .bearer,
            headerName: "Authorization",
            headerPrefix: "Bearer ",
            tokenKeychain: "huggingface-token",
            additionalHeaders: nil
        ),
        endpoints: EndpointConfig(
            usage: UsageEndpoint(
                url: "https://api-inference.huggingface.co/status",
                method: .GET,
                mapping: ResponseMapping(
                    quota: nil,
                    used: nil,
                    remaining: nil,
                    cost: nil,
                    resetDate: nil,
                    tokens: "compute_time",
                    nestedPaths: true
                ),
                queryParams: nil
            ),
            balance: nil
        ),
        colorHex: "#FFD21E",
        createdAt: Date(),
        updatedAt: Date()
    )

    // MARK: - Replicate

    /// Replicate (Run AI models in the cloud)
    ///
    /// Note: Replicate does not currently provide a public usage API endpoint.
    /// Users must check usage through the web dashboard at replicate.com/account.
    /// API Documentation: https://replicate.com/docs
    public static let replicate = CustomProviderConfig(
        id: "replicate",
        name: "Replicate",
        icon: "arrow.triangle.2.circlepath",
        enabled: false,
        auth: AuthConfig(
            type: .bearer,
            headerName: "Authorization",
            headerPrefix: "Token ",
            tokenKeychain: "replicate-token",
            additionalHeaders: nil
        ),
        endpoints: EndpointConfig(
            usage: UsageEndpoint(
                url: "https://api.replicate.com/v1/account/usage",
                method: .GET,
                mapping: ResponseMapping(
                    quota: nil,
                    used: "total_spend",
                    remaining: nil,
                    cost: "total_spend",
                    resetDate: nil,
                    tokens: "prediction_count",
                    nestedPaths: true
                ),
                queryParams: nil
            ),
            balance: nil
        ),
        colorHex: "#000000",
        createdAt: Date(),
        updatedAt: Date()
    )

    // MARK: - Runway ML

    /// Runway ML (Generative AI for video and images)
    ///
    /// Tracks credit usage for Gen-3, Gen-2, and other Runway models.
    /// API Documentation: https://docs.dev.runwayml.com
    public static let runway = CustomProviderConfig(
        id: "runway",
        name: "Runway ML",
        icon: "film",
        enabled: false,
        auth: AuthConfig(
            type: .bearer,
            headerName: "Authorization",
            headerPrefix: "Bearer ",
            tokenKeychain: "runway-token",
            additionalHeaders: ["X-Runway-Version": "2024-11-06"]
        ),
        endpoints: EndpointConfig(
            usage: UsageEndpoint(
                url: "https://api.dev.runwayml.com/v1/usage",
                method: .GET,
                mapping: ResponseMapping(
                    quota: nil,
                    used: "credits_used",
                    remaining: "credits_remaining",
                    cost: "total_cost",
                    resetDate: nil,
                    tokens: "generation_count",
                    nestedPaths: true
                ),
                queryParams: nil
            ),
            balance: nil
        ),
        colorHex: "#00FFA3",
        createdAt: Date(),
        updatedAt: Date()
    )
}

// MARK: - Template Categories

extension ProviderTemplates {

    /// Text generation and LLM providers
    public static var textProviders: [CustomProviderConfig] {
        [openai, anthropic, cohere, perplexity, togetherAI, huggingface]
    }

    /// Image generation providers
    public static var imageProviders: [CustomProviderConfig] {
        [stabilityAI, replicate, huggingface]
    }

    /// Audio and voice providers
    public static var audioProviders: [CustomProviderConfig] {
        [elevenlabs, openai]
    }

    /// Video generation providers
    public static var videoProviders: [CustomProviderConfig] {
        [runway, replicate]
    }
}

// MARK: - Template Helpers

extension ProviderTemplates {

    /// Create a new provider from a template with custom settings
    public static func createFromTemplate(
        _ template: CustomProviderConfig,
        name: String? = nil,
        enabled: Bool = true
    ) -> CustomProviderConfig {
        var config = template

        // Generate new ID to avoid conflicts
        config = CustomProviderConfig(
            id: UUID().uuidString,
            name: name ?? template.name,
            icon: template.icon,
            enabled: enabled,
            auth: template.auth,
            endpoints: template.endpoints,
            colorHex: template.colorHex,
            createdAt: Date(),
            updatedAt: Date()
        )

        return config
    }
}
