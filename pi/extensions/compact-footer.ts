/**
 * Compact Footer Extension
 *
 * Merges extension statuses (e.g. TPS from token-rate) onto the same line
 * as the current path, reducing the footer from 3 lines to 2.
 *
 * Layout:
 *   Line 1: <path (branch)>          <extension statuses>
 *   Line 2: <token stats>            <model + thinking>
 */

import type { AssistantMessage } from "@mariozechner/pi-ai";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";

function fmt(n: number): string {
	if (n < 1000) return n.toString();
	if (n < 10000) return `${(n / 1000).toFixed(1)}k`;
	if (n < 1000000) return `${Math.round(n / 1000)}k`;
	return `${(n / 1000000).toFixed(1)}M`;
}

function sanitize(text: string): string {
	return text.replace(/[\r\n\t]/g, " ").replace(/ +/g, " ").trim();
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		ctx.ui.setFooter((tui, theme, footerData) => {
			const unsub = footerData.onBranchChange(() => tui.requestRender());

			return {
				dispose: unsub,
				invalidate() {},
				render(width: number): string[] {
					// --- Compute token/cost stats ---
					let totalInput = 0, totalOutput = 0;
					let totalCacheRead = 0, totalCacheWrite = 0;
					let totalCost = 0;

					for (const entry of ctx.sessionManager.getEntries()) {
						if (entry.type === "message" && entry.message.role === "assistant") {
							const m = entry.message as AssistantMessage;
							totalInput += m.usage.input;
							totalOutput += m.usage.output;
							totalCacheRead += m.usage.cacheRead;
							totalCacheWrite += m.usage.cacheWrite;
							totalCost += m.usage.cost.total;
						}
					}

					// --- Path + git branch ---
					let pwd = process.cwd();
					const home = process.env.HOME || process.env.USERPROFILE;
					if (home && pwd.startsWith(home)) pwd = `~${pwd.slice(home.length)}`;
					const branch = footerData.getGitBranch();
					if (branch) pwd = `${pwd} (${branch})`;
					const sessionName = ctx.sessionManager.getSessionName();
					if (sessionName) pwd = `${pwd} • ${sessionName}`;

					// --- Extension statuses (right side of line 1) ---
					const extensionStatuses = footerData.getExtensionStatuses();
					let statusStr = "";
					if (extensionStatuses.size > 0) {
						statusStr = Array.from(extensionStatuses.entries())
							.sort(([a], [b]) => a.localeCompare(b))
							.map(([, text]) => sanitize(text))
							.join(" ");
					}

					// --- LINE 1: path (left) + statuses (right) ---
					const pwdDim = theme.fg("dim", pwd);
					let line1: string;
					if (statusStr) {
						const pwdW = visibleWidth(pwdDim);
						const statusW = visibleWidth(statusStr);
						if (pwdW + 2 + statusW <= width) {
							line1 = pwdDim + " ".repeat(width - pwdW - statusW) + statusStr;
						} else {
							const availForPwd = width - statusW - 4;
							if (availForPwd > 10) {
								const truncPwd = truncateToWidth(pwdDim, availForPwd, theme.fg("dim", "…"));
								const truncPwdW = visibleWidth(truncPwd);
								line1 = truncPwd + " ".repeat(Math.max(1, width - truncPwdW - statusW)) + statusStr;
							} else {
								line1 = truncateToWidth(pwdDim + "  " + statusStr, width, theme.fg("dim", "…"));
							}
						}
					} else {
						line1 = truncateToWidth(pwdDim, width, theme.fg("dim", "…"));
					}

					// --- LINE 2: stats (left) + model (right) ---
					const statsParts: string[] = [];
					if (totalInput) statsParts.push(`↑${fmt(totalInput)}`);
					if (totalOutput) statsParts.push(`↓${fmt(totalOutput)}`);
					if (totalCacheRead) statsParts.push(`R${fmt(totalCacheRead)}`);
					if (totalCacheWrite) statsParts.push(`W${fmt(totalCacheWrite)}`);

					const usingSubscription = ctx.model
						? (ctx as any).modelRegistry?.isUsingOAuth?.(ctx.model) ?? false
						: false;
					if (totalCost || usingSubscription) {
						statsParts.push(`$${totalCost.toFixed(3)}${usingSubscription ? " (sub)" : ""}`);
					}

					// Context usage
					const contextUsage = ctx.getContextUsage();
					const contextWindow = contextUsage?.contextWindow ?? ctx.model?.contextWindow ?? 0;
					if (contextWindow) {
						const pct = contextUsage?.percent;
						const pctDisplay = pct != null ? `${pct.toFixed(1)}%` : "?";
						const ctxStr = `${pctDisplay}/${fmt(contextWindow)}`;
						if (pct != null && pct > 90) statsParts.push(theme.fg("error", ctxStr));
						else if (pct != null && pct > 70) statsParts.push(theme.fg("warning", ctxStr));
						else statsParts.push(ctxStr);
					}

					const statsLeft = statsParts.join(" ");
					const statsLeftW = visibleWidth(statsLeft);

					// Model + thinking level
					const modelName = ctx.model?.id || "no-model";
					let rightSide = modelName;
					if ((ctx.model as any)?.reasoning) {
						const thinking = (ctx as any).thinkingLevel || "off";
						rightSide = thinking === "off" ? `${modelName} • thinking off` : `${modelName} • ${thinking}`;
					}

					// Provider prefix if multiple
					if (footerData.getAvailableProviderCount() > 1 && ctx.model) {
						const withProvider = `(${ctx.model.provider}) ${rightSide}`;
						if (statsLeftW + 2 + visibleWidth(withProvider) <= width) {
							rightSide = withProvider;
						}
					}

					const rightW = visibleWidth(rightSide);
					let line2: string;
					if (statsLeftW + 2 + rightW <= width) {
						line2 = statsLeft + " ".repeat(width - statsLeftW - rightW) + rightSide;
					} else {
						const avail = width - statsLeftW - 2;
						if (avail > 0) {
							const truncRight = truncateToWidth(rightSide, avail, "");
							const truncRightW = visibleWidth(truncRight);
							line2 = statsLeft + " ".repeat(Math.max(1, width - statsLeftW - truncRightW)) + truncRight;
						} else {
							line2 = truncateToWidth(statsLeft, width);
						}
					}

					// Dim line 2 parts separately to preserve colored context %
					const dimStats = theme.fg("dim", statsLeft);
					const remainder = line2.slice(statsLeft.length);
					const dimRemainder = theme.fg("dim", remainder);

					return [line1, dimStats + dimRemainder];
				},
			};
		});
	});
}
