/**
 * Ridecell internal inference endpoint (OpenAI-compatible).
 * API key is read from env var RIDECELL_INFERENCE_API_KEY.
 *
 * Use with: /model ridecell/qwen3.6-27b
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	pi.registerProvider("ridecell", {
		name: "Ridecell Inference",
		baseUrl: "https://inference.ridecell.tech/v1",
		apiKey: "$RIDECELL_INFERENCE_API_KEY",
		api: "openai-completions",
		models: [
			{
				id: "qwen3.6-27b",
				name: "Qwen3.6 27B (Ridecell)",
				reasoning: true,
				input: ["text"],
				cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
				contextWindow: 128000,
				maxTokens: 8192,
				compat: {
					thinkingFormat: "qwen-chat-template",
				},
			},
		],
	});
}
