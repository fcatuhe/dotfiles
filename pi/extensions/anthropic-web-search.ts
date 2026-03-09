import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	pi.on("before_provider_request", (event) => {
		const payload = event.payload as any;
		if (!payload?.model?.startsWith?.("claude")) return;
		const tools = payload.tools ?? [];
		tools.push({ type: "web_search_20250305", name: "web_search" });
		return { ...payload, tools };
	});
}
