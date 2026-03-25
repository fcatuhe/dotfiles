// Adds Anthropic server-side web search to Claude requests.
//
// Wraps streamSimpleAnthropic, patches the outbound payload to:
//   1. Restore signed thinking text after pi-ai's sanitizeSurrogates corrupts it.
//   2. Inject the web_search_20250305 server tool.
//
// When pi fixes sanitizeSurrogates to skip signed blocks, (1) becomes a no-op.
// server_tool_use / web_search_tool_result blocks are dropped by pi-ai's
// streaming parser — search results only appear in Claude's text response.

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
