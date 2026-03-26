// Adds Anthropic server-side web search to Claude requests.
//
// Wraps streamSimpleAnthropic, patches the outbound payload to:
//   1. Restore signed thinking text after pi-ai's sanitizeSurrogates corrupts it.
//   2. Inject the web_search_20250305 server tool.
//
// BROKEN: pi-ai's streaming parser only handles text, thinking, redacted_thinking,
// and tool_use content blocks. When Claude uses web search, the API returns
// server_tool_use and web_search_tool_result blocks which are silently dropped.
// On the next turn, the truncated assistant message is sent back, and the API
// rejects it with "thinking blocks in the latest assistant message cannot be
// modified" because the content array no longer matches the original response.
// This needs an upstream fix in pi-ai to preserve server tool blocks.

import { type Context, type SimpleStreamOptions, streamSimpleAnthropic } from "@mariozechner/pi-ai";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

function restoreSignedThinking(payload: any, context: Context): void {
	if (!Array.isArray(payload?.messages)) return;

	const originals = new Map<string, string>();
	for (const msg of context.messages) {
		if (msg.role !== "assistant" || !Array.isArray(msg.content)) continue;
		for (const block of msg.content) {
			if (block.type === "thinking" && !block.redacted && block.thinkingSignature?.trim() && block.thinking?.trim()) {
				originals.set(block.thinkingSignature, block.thinking);
			}
		}
	}
	if (originals.size === 0) return;

	for (const msg of payload.messages) {
		if (msg.role !== "assistant" || !Array.isArray(msg.content)) continue;
		for (const block of msg.content) {
			if (block.type === "thinking" && block.signature) {
				const original = originals.get(block.signature);
				if (original !== undefined) block.thinking = original;
			}
		}
	}
}

function addWebSearchTool(payload: any, model: { provider: string }): void {
	if (model.provider !== "anthropic") return;
	const tools: any[] = payload.tools ?? [];
	if (tools.some((t: any) => t.type === "web_search_20250305")) return;
	tools.push({ type: "web_search_20250305", name: "web_search" });
	payload.tools = tools;
}

export default function (pi: ExtensionAPI) {
	pi.registerProvider("anthropic-websearch", {
		api: "anthropic-messages",
		streamSimple: (model, context, options?: SimpleStreamOptions) => {
			const outerOnPayload = options?.onPayload;
			return streamSimpleAnthropic(model, context, {
				...options,
				onPayload: async (payload, payloadModel) => {
					let next = payload;
					if (outerOnPayload) {
						const modified = await outerOnPayload(next, payloadModel);
						if (modified !== undefined) next = modified;
					}
					restoreSignedThinking(next, context);
					addWebSearchTool(next, payloadModel);
					return next;
				},
			});
		},
	});
}
