/**
 * Model Shortcuts Extension
 *
 * Reads aliases from models.json and registers slash commands
 * for quick model/thinking switching.
 *
 *   /off  /minimal  /low  /medium  /high  /xhigh   Set thinking level
 *   /glm  /kimi  /codex  /sonnet                    Switch model
 *   /glm:high  /kimi:off  /codex:low                Switch model + thinking
 *
 * Type /glm: to see all thinking combos. Enter submits immediately.
 *
 * models.json supports two alias sources:
 *   1. Top-level "aliases" map — works for any model (built-in + custom):
 *        "aliases": { "codex": "openai-codex:o4-mini" }
 *   2. "alias" field on custom model definitions — convenience shortcut.
 */

import { readFileSync } from "node:fs";
import { join } from "node:path";

import { getAgentDir } from "@mariozechner/pi-coding-agent";
import type { ExtensionAPI, ExtensionCommandContext, ExtensionContext } from "@mariozechner/pi-coding-agent";
import type { ThinkingLevel } from "@mariozechner/pi-agent-core";
import { type Model, supportsXhigh } from "@mariozechner/pi-ai";

const BASE_LEVELS: ThinkingLevel[] = ["off", "minimal", "low", "medium", "high"];
const LEVELS: ThinkingLevel[] = [...BASE_LEVELS, "xhigh"];
const LEVEL_SET = new Set<string>(LEVELS);
const MODELS_JSON_PATH = join(getAgentDir(), "models.json");

type AliasTarget = {
	provider: string;
	modelId: string;
};

type AliasEntry = AliasTarget & {
	alias: string;
};

function isRecord(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null;
}

function parseAliasRef(ref: string): AliasTarget | undefined {
	const index = ref.indexOf(":");
	if (index <= 0 || index === ref.length - 1) return undefined;

	return {
		provider: ref.slice(0, index),
		modelId: ref.slice(index + 1),
	};
}

function readAliases(): AliasEntry[] {
	let content: string;
	try {
		content = readFileSync(MODELS_JSON_PATH, "utf-8");
	} catch {
		return [];
	}

	let parsed: unknown;
	try {
		parsed = JSON.parse(content);
	} catch {
		return [];
	}

	if (!isRecord(parsed)) return [];

	const seen = new Set<string>();
	const aliases: AliasEntry[] = [];
	const topLevelAliases = isRecord(parsed.aliases) ? parsed.aliases : undefined;
	const providers = isRecord(parsed.providers) ? parsed.providers : undefined;

	if (topLevelAliases) {
		for (const [rawAlias, rawRef] of Object.entries(topLevelAliases)) {
			const alias = rawAlias.trim();
			if (!alias || typeof rawRef !== "string" || seen.has(alias)) continue;

			const target = parseAliasRef(rawRef);
			if (!target) continue;

			seen.add(alias);
			aliases.push({ alias, ...target });
		}
	}

	if (!providers) return aliases;

	for (const [provider, providerConfig] of Object.entries(providers)) {
		if (!isRecord(providerConfig) || !Array.isArray(providerConfig.models)) continue;

		for (const model of providerConfig.models) {
			if (!isRecord(model) || typeof model.id !== "string" || typeof model.alias !== "string") continue;

			const alias = model.alias.trim();
			if (!alias || seen.has(alias)) continue;

			seen.add(alias);
			aliases.push({ alias, provider, modelId: model.id });
		}
	}

	return aliases;
}

function getAliasTarget(alias: string): AliasTarget | undefined {
	return readAliases().find((entry) => entry.alias === alias);
}

function getAliasedModel(ctx: ExtensionContext, alias: string): Model<any> | undefined {
	const target = getAliasTarget(alias);
	if (!target) return undefined;
	return ctx.modelRegistry.find(target.provider, target.modelId);
}

function getAvailableLevels(model: Model<any> | undefined): ThinkingLevel[] {
	return model && supportsXhigh(model) ? LEVELS : BASE_LEVELS;
}

function notifyThinking(pi: ExtensionAPI, ctx: ExtensionContext): void {
	ctx.ui.notify(`Thinking: ${pi.getThinkingLevel()}`, "info");
}

function notifyModelSwitch(pi: ExtensionAPI, ctx: ExtensionContext, model: Model<any>, previousThinking: ThinkingLevel): void {
	const thinkingLevel = pi.getThinkingLevel();
	if (thinkingLevel !== previousThinking) {
		ctx.ui.notify(`Model: ${model.id} • Thinking: ${thinkingLevel}`, "info");
		return;
	}

	ctx.ui.notify(`Model: ${model.id}`, "info");
}

async function switchAliasedModel(
	pi: ExtensionAPI,
	ctx: ExtensionCommandContext,
	alias: string,
): Promise<Model<any> | undefined> {
	const model = getAliasedModel(ctx, alias);
	if (!model) return undefined;
	if (!(await pi.setModel(model))) return undefined;
	return model;
}

function registerThinkingCommands(pi: ExtensionAPI): void {
	for (const level of LEVELS) {
		pi.registerCommand(level, {
			description: `Thinking ${level}`,
			handler: async (_args, ctx) => {
				pi.setThinkingLevel(level);
				notifyThinking(pi, ctx);
			},
		});
	}
}

function registerAliasCommands(pi: ExtensionAPI, ctx: ExtensionContext, registeredCommands: Set<string>): void {
	for (const { alias } of readAliases()) {
		if (LEVEL_SET.has(alias)) continue;

		const model = getAliasedModel(ctx, alias);
		const target = getAliasTarget(alias);
		const levels = getAvailableLevels(model);
		const description = target ? `(${target.provider}) ${target.modelId}` : alias;

		if (!registeredCommands.has(alias)) {
			registeredCommands.add(alias);
			pi.registerCommand(alias, {
				description,
				handler: async (_args, commandCtx) => {
					const previousThinking = pi.getThinkingLevel();
					const nextModel = await switchAliasedModel(pi, commandCtx, alias);
					if (nextModel) notifyModelSwitch(pi, commandCtx, nextModel, previousThinking);
				},
			});
		}

		for (const level of levels) {
			const commandName = `${alias}:${level}`;
			if (registeredCommands.has(commandName)) continue;

			registeredCommands.add(commandName);
			pi.registerCommand(commandName, {
				description: `${description} • ${level === "off" ? "thinking off" : level}`,
				handler: async (_args, commandCtx) => {
					const previousThinking = pi.getThinkingLevel();
					const nextModel = await switchAliasedModel(pi, commandCtx, alias);
					if (!nextModel) return;
					pi.setThinkingLevel(level);
					notifyModelSwitch(pi, commandCtx, nextModel, previousThinking);
				},
			});
		}
	}
}

export default function modelShortcutsExtension(pi: ExtensionAPI): void {
	registerThinkingCommands(pi);

	const registeredCommands = new Set<string>(LEVELS);
	pi.on("session_start", (_event, ctx) => {
		registerAliasCommands(pi, ctx, registeredCommands);
	});
}
