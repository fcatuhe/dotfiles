// Adds Anthropic's server-side web_search tool to Claude requests.
//
// 2026-03-11: pi-ai's convertMessages runs sanitizeSurrogates on thinking
// block text, which breaks the cryptographic signature. Anthropic returns 400:
//   "thinking or redacted_thinking blocks in the latest assistant message
//    cannot be modified."
// Workaround: strip thinking blocks from history in the `context` event
// (before convertMessages touches them). Claude loses prior reasoning chain
// in context, but the reasoning is already reflected in the text responses.
//
// This also busts Anthropic's prompt cache — the message prefix changes every
// turn since thinking blocks are missing, so the API can never match a cached
// prefix. The proper fix is in pi-ai: don't run sanitizeSurrogates on signed
// thinking blocks (the text + signature are a cryptographic pair).

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	// Strip thinking blocks from assistant message history so convertMessages
	// never runs sanitizeSurrogates on signed content.
	pi.on("context", async (event) => {
		const messages = event.messages.map((msg: any) => {
			if (msg.role === "assistant" && Array.isArray(msg.content)) {
				return {
					...msg,
					content: msg.content.filter((block: any) => block.type !== "thinking"),
				};
			}
			return msg;
		});
		return { messages };
	});

	// Add Anthropic's server-side web search tool to the API payload.
	pi.on("before_provider_request", (event) => {
		const payload = event.payload as any;
		if (!payload?.model?.startsWith?.("claude")) return;
		const tools = payload.tools ?? [];
		tools.push({ type: "web_search_20250305", name: "web_search" });
		return { ...payload, tools };
	});
}
