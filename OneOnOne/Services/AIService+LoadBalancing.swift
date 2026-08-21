//
//  AIService+LoadBalancing.swift
//  OneOnOne
//
//  Extends AIService with the shared multi-model LLM load balancer: OpenRouter
//  frontier models, the optional Nova Gateway, and balanced dispatch across every
//  discovered local model (Ollama + MLX). Mirrors AIStudio's LLMBackendManager
//  balanced-dispatch, adapted to OneOnOne's AIProvider layer.
//
//  All the pure pool/parse/balancer logic lives in ModelRegistry / OpenRouterProvider
//  (network-free, unit-tested by LoadBalancerTests). This file adds the thin,
//  resilient I/O + dispatch layer — any unreachable backend simply contributes
//  nothing and the caller falls back cleanly. Nova Gateway is never required.
//
//  Created by Jordan Koch on 2026-08-21.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

extension AIService {

    // MARK: - OpenRouter API key (Keychain-backed)

    /// Store the OpenRouter API key in the Keychain (empty string clears it).
    func setOpenRouterAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            openRouterKeychain.delete()
        } else {
            openRouterKeychain.set(trimmed)
        }
    }

    /// Read the stored OpenRouter API key, if any.
    func openRouterAPIKey() -> String? {
        openRouterKeychain.get()
    }

    /// True when an OpenRouter key has been configured.
    var hasOpenRouterKey: Bool {
        openRouterKeychain.hasValue
    }

    /// Fetch the OpenRouter model list for the picker; falls back to the
    /// hardcoded popular-models list if the fetch fails.
    func fetchOpenRouterModels() async {
        guard let key = openRouterAPIKey(), !key.isEmpty,
              let url = URL(string: OpenRouterProvider.modelsURL) else {
            openRouterModels = OpenRouterProvider.fallbackModels
            return
        }

        var request = URLRequest(url: url)
        for (header, value) in OpenRouterProvider.authHeaders(apiKey: key) {
            request.setValue(value, forHTTPHeaderField: header)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                openRouterModels = OpenRouterProvider.fallbackModels
                return
            }
            let models = OpenRouterProvider.parseModels(data)
            openRouterModels = models.isEmpty ? OpenRouterProvider.fallbackModels : models
            if !openRouterModels.contains(selectedOpenRouterModel) {
                selectedOpenRouterModel = openRouterModels.contains(OpenRouterProvider.defaultModel)
                    ? OpenRouterProvider.defaultModel : (openRouterModels.first ?? selectedOpenRouterModel)
            }
        } catch {
            openRouterModels = OpenRouterProvider.fallbackModels
        }
    }

    // MARK: - Pool discovery (honors the three toggles)

    /// Discover the enabled balancer pool honoring the three toggles. Resilient:
    /// any unreachable source contributes zero models.
    func discoverEnabledPool() async -> [DiscoveredModel] {
        var ollama: [DiscoveredModel] = []
        var mlx: [DiscoveredModel] = []
        var frontier: [DiscoveredModel] = []

        if useAllLocalModels {
            ollama = await ModelRegistry.discoverOllama(baseURL: ollamaEndpoint)
            mlx = ModelRegistry.discoverMLX()
        }
        if enableAllFrontierModels {
            frontier = ModelRegistry.frontierModels(from: openRouterModels)
        }
        let nova = useNovaGateway ? ModelRegistry.novaGatewayModel(url: novaGatewayURL) : nil

        let pool = ModelRegistry.assemblePool(
            ollama: ollama,
            mlx: mlx,
            frontier: frontier,
            novaGateway: nova,
            useAllLocalModels: useAllLocalModels,
            enableAllFrontierModels: enableAllFrontierModels,
            useNovaGateway: useNovaGateway
        )
        discoveredModels = pool
        return pool
    }

    // MARK: - Health gating

    /// Quick availability probe for a single backend. Nova Gateway failing here
    /// simply marks its pool entry unhealthy — it is never required.
    private func probeBackend(_ backend: LLMBackendType) async -> Bool {
        switch backend {
        case .ollama:
            guard let url = URL(string: "\(ollamaEndpoint)/api/tags") else { return false }
            return await isReachable(url)
        case .mlx:
            guard let url = URL(string: "\(mlxEndpoint)/v1/models") else { return false }
            return await isReachable(url)
        case .openRouter:
            return hasOpenRouterKey
        case .novaGateway:
            // Health endpoint per spec is /v1/models; fall back to the base URL.
            let candidates = ["\(novaGatewayURL)/v1/models", "\(novaGatewayURL)/"].compactMap { URL(string: $0) }
            for url in candidates where await isReachable(url) { return true }
            return false
        default:
            return false
        }
    }

    private func isReachable(_ url: URL) async -> Bool {
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    /// Build a `[modelId: Bool]` health map for `pool` by probing each distinct
    /// backend once (health-gating composed with the LoadBalancer).
    private func healthMap(for pool: [DiscoveredModel]) async -> [String: Bool] {
        var backendHealth: [LLMBackendType: Bool] = [:]
        for backend in Set(pool.map { $0.backend }) {
            backendHealth[backend] = await probeBackend(backend)
        }
        var map: [String: Bool] = [:]
        for model in pool {
            map[model.id] = backendHealth[model.backend] ?? false
        }
        return map
    }

    // MARK: - Balanced dispatch

    /// Balanced dispatch: pick a model via the `LoadBalancer` over the healthy
    /// enabled pool and route it through the appropriate backend. Returns nil when
    /// no pool/healthy model can produce a result, so the caller falls back to the
    /// single-provider path (keeping plain Ollama working; Nova never required).
    func generateBalanced(prompt: String, maxTokens: Int) async -> String? {
        let pool = await discoverEnabledPool()
        guard !pool.isEmpty else { return nil }

        let health = await healthMap(for: pool)
        var remaining = pool

        // Try balancer-selected models, falling through on failure.
        while let choice = balancer.next(pool: remaining, health: health, policy: balancerPolicy) {
            balancer.checkOut(choice.id)
            do {
                let result = try await dispatchBalanced(model: choice, prompt: prompt, maxTokens: maxTokens)
                balancer.checkIn(choice.id)
                return result
            } catch {
                balancer.checkIn(choice.id)
                lastError = error.localizedDescription
                remaining.removeAll { $0.id == choice.id }
                continue
            }
        }
        // Nothing healthy produced a result — fall back to the single-provider path.
        return nil
    }

    /// Route a single balancer-selected model through the correct backend.
    private func dispatchBalanced(model: DiscoveredModel, prompt: String, maxTokens: Int) async throws -> String {
        switch model.backend {
        case .ollama:
            return try await callOllamaModel(model: model.modelName, prompt: prompt, maxTokens: maxTokens)
        case .mlx:
            // OneOnOne's MLX backend is an OpenAI-compatible HTTP server.
            return try await callOpenAICompatible(
                endpoint: "\(mlxEndpoint)/v1/chat/completions",
                model: model.modelName, headers: [:], prompt: prompt, maxTokens: maxTokens)
        case .openRouter:
            guard let key = openRouterAPIKey(), !key.isEmpty else { throw LLMError.noBackendAvailable }
            return try await callOpenAICompatible(
                endpoint: model.endpoint, model: model.modelName,
                headers: OpenRouterProvider.authHeaders(apiKey: key), prompt: prompt, maxTokens: maxTokens)
        case .novaGateway:
            return try await callOpenAICompatible(
                endpoint: model.endpoint, model: model.modelName, headers: [:], prompt: prompt, maxTokens: maxTokens)
        default:
            throw LLMError.noBackendAvailable
        }
    }

    // MARK: - Backend calls used by the balancer

    private var balancerSystemPrompt: String {
        "You are a helpful assistant for managing 1:1 meetings and team relationships."
    }

    /// Ollama generate against a specific discovered model.
    private func callOllamaModel(model: String, prompt: String, maxTokens: Int) async throws -> String {
        guard let url = URL(string: "\(ollamaEndpoint)/api/generate") else { throw LLMError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "system": balancerSystemPrompt,
            "stream": false,
            "options": ["num_predict": maxTokens, "temperature": 0.7]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw LLMError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.invalidResponse
        }
        if json["error"] is String { throw LLMError.invalidResponse }
        guard let text = json["response"] as? String else { throw LLMError.noResponse }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Generic OpenAI-compatible chat-completions call (MLX, OpenRouter, Nova).
    private func callOpenAICompatible(
        endpoint: String, model: String, headers: [String: String], prompt: String, maxTokens: Int
    ) async throws -> String {
        let messages = OpenAICompatibleRequest.chatMessages(
            prompt: prompt, systemPrompt: balancerSystemPrompt, history: [])

        var request = try OpenAICompatibleRequest.build(
            endpoint: endpoint, model: model, messages: messages,
            temperature: 0.7, maxTokens: maxTokens, stream: false, headers: headers)
        request.timeoutInterval = 120

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw LLMError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        struct OpenAIResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }
        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

// MARK: - LLM Errors (used by the OpenAI-compatible request builder + dispatch)

/// Errors thrown by the shared load-balancer request path. Mirrors AIStudio's
/// `LLMError` so the verbatim `OpenAICompatibleRequest` builder compiles unchanged.
enum LLMError: LocalizedError, Sendable {
    case noBackendAvailable
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case noResponse

    var errorDescription: String? {
        switch self {
        case .noBackendAvailable:
            return "No LLM backend is available in the balancer pool."
        case .invalidURL:
            return "Invalid backend URL configuration."
        case .invalidResponse:
            return "Received invalid response from LLM backend."
        case .httpError(let code):
            return "HTTP error \(code) from LLM backend."
        case .noResponse:
            return "No response received from LLM backend."
        }
    }
}
