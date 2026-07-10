/**
 * NVIDIA NIM inference endpoint (OpenAI-compatible).
 * API key is read from env var NVIDIA_API_KEY.
 *
 * Kept separate from the Fireworks GLM so both are usable.
 * Use with: /model nvidia/z-ai/glm-5.2
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	pi.registerProvider("nvidia", {
		name: "NVIDIA NIM",
		baseUrl: "https://integrate.api.nvidia.com/v1",
		apiKey: "$NVIDIA_API_KEY",
		api: "openai-completions",
		models: [
			{
				id: "z-ai/glm-5.2",
				name: "GLM-5.2 (NVIDIA)",
				reasoning: true,
				input: ["text"],
				cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
				contextWindow: 200000,
				maxTokens: 8192,
				compat: {
					thinkingFormat: "zai",
				},
			},
		],
	});
}
