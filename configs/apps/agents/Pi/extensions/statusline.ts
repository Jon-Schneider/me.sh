/**
 * pi statusline — a fully configurable footer status line.
 *
 * Ported from a Claude Code statusline script and reimagined as a pi extension:
 *   - all derivation logic lives in small functions
 *   - segments are registered in a builder table
 *   - the rendered line is just a fold over the configured `segments` array
 *     joined by a separator — reorder / remove / duplicate at will
 *
 * Configuration (JSONC — comments & trailing commas allowed), merged in order:
 *   built-in defaults → ~/.pi/agent/statusline.json → <project>/.pi/statusline.json
 *
 * Commands:
 *   /statusline          edit the global config (creates a commented template)
 *   /statusline project  edit the project-local config
 *   /statusline reset    delete both override files
 *
 * Every option is documented in the generated config template.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import { execFile } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, unlinkSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";

// ============================================================
// Constants / types
// ============================================================

const STATUS_KEY = "statusline";
const RESET = "\x1b[0m";

/** Every valid `theme.fg()` token (docs/themes.md). Anything else falls back to uncolored. */
const THEME_COLORS = new Set([
	"accent", "border", "borderAccent", "borderMuted", "success", "error", "warning",
	"muted", "dim", "text", "thinkingText", "searchMatchText", "userMessageText",
	"customMessageText", "customMessageLabel", "toolTitle", "toolOutput", "mdHeading",
	"mdLink", "mdLinkUrl", "mdCode", "mdCodeBlock", "mdCodeBlockBorder", "mdQuote",
	"mdQuoteBorder", "mdHr", "mdListBullet", "toolDiffAdded", "toolDiffRemoved",
	"toolDiffContext", "syntaxComment", "syntaxKeyword", "syntaxFunction",
	"syntaxVariable", "syntaxString", "syntaxNumber", "syntaxType", "syntaxOperator",
	"syntaxPunctuation", "thinkingOff", "thinkingMinimal", "thinkingLow",
	"thinkingMedium", "thinkingHigh", "thinkingXhigh", "thinkingMax", "bashMode",
]);

interface Threshold { at: number; color: string }

interface StatuslineConfig {
	segments: (string | Record<string, any>)[];
	separator: string;
	separatorColor: string;
	maxWidth: number;
	/** "keep": render below pi's built-in footer. "own": replace the built-in footer. */
	footer: "keep" | "own";
	/** Right-aligned zone when footer is "own" (same syntax as segments). */
	footerRight: (string | Record<string, any>)[];
	thresholds: Threshold[];
	colors: Record<string, string>;
	model: { icon: string; showProvider: boolean; showThinking: boolean; showSandbox: boolean; aliases: Record<string, string>; color?: string; sandbox?: Record<string, any> };
	thinking: { labels: Record<string, string>; color?: string };
	sandbox: { icons: Record<string, string>; labels: Record<string, string> };
	context: { style: string; barWidth: number; barFilled: string; barEmpty: string; tokenFormat: string; colors?: Record<string, string> };
	session: { parts: string[]; tokenFormat: string; costSymbol: string; costPrecision: number; icons: Record<string, string>; colors?: Record<string, string> };
	project: { parts: string[]; dirStyle: string; branchPrefix: string; colors?: Record<string, string> };
	time: { format: string; color?: string };
	git: { includeStaged: boolean; cacheMs: number };
}

const DEFAULT_CONFIG: StatuslineConfig = {
	segments: ["model", "session", { segment: "project", align: "right" }],
	separator: " | ",
	separatorColor: "dim",
	maxWidth: 0,
	footer: "keep",
	footerRight: [],
	thresholds: [
		{ at: 0, color: "success" },
		{ at: 50, color: "warning" },
		{ at: 75, color: "error" },
	],
	colors: {
		model: "accent",
		thinking: "muted",
		sandboxYes: "success",
		sandboxNo: "error",
		contextBarFilled: "auto",
		contextBarEmpty: "dim",
		contextTokens: "auto",
		contextPct: "auto",
		sessionIn: "dim",
		sessionOut: "dim",
		sessionCacheRead: "dim",
		sessionCacheWrite: "dim",
		sessionCost: "muted",
		sessionTurns: "dim",
		dir: "accent",
		branch: "success",
		diffAdded: "toolDiffAdded",
		diffRemoved: "toolDiffRemoved",
		ahead: "success",
		behind: "error",
		time: "dim",
		text: "text",
	},
	model: { icon: "", showProvider: false, showThinking: true, showSandbox: true, aliases: {} },
	thinking: {
		labels: { off: "", minimal: "min", low: "low", medium: "med", high: "high", xhigh: "xhigh", max: "max" },
	},
	sandbox: { icons: { yes: "🔒", no: "⚠" }, labels: { yes: "", no: "" } },
	context: { style: "bar+tokens+pct", barWidth: 10, barFilled: "█", barEmpty: "░", tokenFormat: "compact" },
	session: {
		parts: ["in", "out", "cost"],
		tokenFormat: "compact",
		costSymbol: "$",
		costPrecision: 2,
		icons: { in: "↑", out: "↓", cacheRead: "⟲", cacheWrite: "✎", cost: "", turns: "⟳" },
	},
	project: { parts: ["dir", "branch", "diff"], dirStyle: "basename", branchPrefix: "@" },
	time: { format: "%H:%M" },
	git: { includeStaged: false, cacheMs: 1500 },
};

// ============================================================
// JSONC + config loading
// ============================================================

/** Strip // and /* *​/ comments (string-aware) plus trailing commas. */
function stripJsonComments(src: string): string {
	let out = "";
	let inStr = false;
	let inLine = false;
	let inBlock = false;
	for (let i = 0; i < src.length; i++) {
		const c = src[i]!;
		const n = src[i + 1];
		if (inLine) {
			if (c === "\n") { inLine = false; out += c; }
			continue;
		}
		if (inBlock) {
			if (c === "*" && n === "/") { inBlock = false; i++; }
			continue;
		}
		if (inStr) {
			out += c;
			if (c === "\\") { out += n ?? ""; i++; }
			else if (c === '"') inStr = false;
			continue;
		}
		if (c === '"') { inStr = true; out += c; continue; }
		if (c === "/" && n === "/") { inLine = true; i++; continue; }
		if (c === "/" && n === "*") { inBlock = true; i++; continue; }
		if ((c === "}" || c === "]")) out = out.replace(/[ \t\r\n]*,(?=[ \t\r\n]*$)/, "");
		out += c;
	}
	return out;
}

function isPlainObject(v: any): boolean {
	return v !== null && typeof v === "object" && !Array.isArray(v);
}

/** Objects merge recursively; arrays and scalars replace. */
function deepMerge(base: any, over: any): any {
	if (!isPlainObject(base) || !isPlainObject(over)) return over === undefined ? base : over;
	const out: any = { ...base };
	for (const k of Object.keys(over)) out[k] = deepMerge(base[k], over[k]);
	return out;
}

export function globalConfigPath(): string {
	return join(homedir(), ".pi", "agent", "statusline.json");
}

export function projectConfigPath(cwd: string): string {
	return join(cwd ?? process.cwd(), ".pi", "statusline.json");
}

function loadConfigLayer(path: string): any | undefined {
	try {
		if (!existsSync(path)) return undefined;
		const raw = readFileSync(path, "utf8");
		if (!raw.trim()) return undefined;
		return JSON.parse(stripJsonComments(raw));
	} catch {
		return undefined;
	}
}

function loadConfig(cwd: string): StatuslineConfig {
	let cfg: any = DEFAULT_CONFIG;
	const global = loadConfigLayer(globalConfigPath());
	if (global) cfg = deepMerge(cfg, global);
	const project = loadConfigLayer(projectConfigPath(cwd));
	if (project) cfg = deepMerge(cfg, project);
	return cfg as StatuslineConfig;
}

// ============================================================
// Formatting helpers
// ============================================================

function formatTokens(n: number, fmt: string): string {
	const num = Math.round(n);
	if (fmt === "raw") return String(num);
	if (fmt === "commas") return num.toLocaleString("en-US");
	if (num >= 1_000_000) return (num / 1_000_000).toFixed(1) + "m";
	if (num >= 1000) return Math.round(num / 1000) + "k";
	return String(num);
}

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const MONTHS_FULL = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
const DAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const DAYS_FULL = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

/** Small strftime subset: %Y %m %d %e %H %I %M %S %p %b %B %a %A %% (pad with %-). */
function strftime(d: Date, fmt: string): string {
	const pad = (n: number) => String(n).padStart(2, "0");
	return fmt.replace(/%-?([A-Za-z%])/g, (m, ch: string) => {
		const unpadded = m.startsWith("%-");
		const p = (v: number) => (unpadded ? String(v) : pad(v));
		switch (ch) {
			case "%": return "%";
			case "Y": return String(d.getFullYear());
			case "m": return p(d.getMonth() + 1);
			case "d": return p(d.getDate());
			case "e": return String(d.getDate());
			case "H": return p(d.getHours());
			case "I": return p(d.getHours() % 12 || 12);
			case "M": return p(d.getMinutes());
			case "S": return p(d.getSeconds());
			case "p": return d.getHours() < 12 ? "AM" : "PM";
			case "b": return MONTHS[d.getMonth()]!;
			case "B": return MONTHS_FULL[d.getMonth()]!;
			case "a": return DAYS[d.getDay()]!;
			case "A": return DAYS_FULL[d.getDay()]!;
			default: return m;
		}
	});
}

function displayDir(cwd: string | undefined, style: string): string {
	if (!cwd) return "";
	if (style === "full") return cwd;
	if (style === "tilde") {
		const home = homedir();
		if (cwd === home) return "~";
		if (cwd.startsWith(home + "/")) return "~" + cwd.slice(home.length);
		return cwd;
	}
	return cwd.replace(/\/+$/, "").split("/").pop() || cwd;
}

// ============================================================
// Color resolution
// ============================================================

/**
 * Resolve a color spec to an ANSI escape prefix.
 *   "auto"    → first matching entry in cfg.thresholds (needs `percent`)
 *   "#rrggbb" → raw truecolor escape
 *   token     → theme token name (docs/themes.md)
 *   "none"/"" → no color
 */
function ansiFor(theme: any, spec: string | undefined, thresholds: Threshold[], percent: number | null | undefined): string {
	const s = (spec ?? "auto").trim();
	if (s === "" || s === "none") return "";
	if (s === "auto") {
		const p = percent ?? 0;
		let chosen: string | undefined;
		for (const t of [...(thresholds ?? [])].sort((a, b) => a.at - b.at)) {
			if (p >= t.at) chosen = t.color;
		}
		return chosen ? ansiFor(theme, chosen, thresholds, percent) : "";
	}
	if (s.startsWith("#")) {
		let hex = s.slice(1);
		if (hex.length === 3) hex = hex.split("").map((c) => c + c).join("");
		if (hex.length !== 6) return "";
		const r = parseInt(hex.slice(0, 2), 16);
		const g = parseInt(hex.slice(2, 4), 16);
		const b = parseInt(hex.slice(4, 6), 16);
		if (![r, g, b].every(Number.isFinite)) return "";
		return `\x1b[38;2;${r};${g};${b}m`;
	}
	if (theme && THEME_COLORS.has(s)) {
		try { return theme.getFgAnsi(s); } catch { return ""; }
	}
	return "";
}

interface Painter {
	/** ANSI prefix for a spec (threshold-aware). */
	ansi(spec: string | undefined, percent?: number | null): string;
	/** Wrap text in a color. */
	P(spec: string | undefined, text: string, percent?: number | null): string;
}

function makePainter(theme: any, cfg: StatuslineConfig): Painter {
	return {
		ansi: (spec, percent) => ansiFor(theme, spec, cfg.thresholds, percent),
		P: (spec, text, percent) => {
			if (!text) return "";
			const a = ansiFor(theme, spec, cfg.thresholds, percent);
			return a ? a + text + RESET : text;
		},
	};
}

// ============================================================
// Sandbox probe (ported from the Claude statusline)
// ------------------------------------------------------------
// An externally-imposed sandbox (e.g. a safehouse-style wrapper) that
// restricts process access makes /bin/ps fail with "operation not
// permitted", whereas an unsandboxed process runs it fine. The probe
// runs in pi's own process context, so it directly reflects the
// session's sandbox state. Sandbox state cannot change mid-process,
// so the result is probed once and cached for the lifetime of the
// extension (equivalent to the per-session /tmp cache in bash).
// ============================================================

let sandboxProbe: Promise<boolean> | undefined;

function isSandboxed(): Promise<boolean> {
	sandboxProbe ??= new Promise<boolean>((resolve) => {
		execFile("/bin/ps", ["-p", String(process.pid)], { timeout: 2000 }, (err: any) => {
			if (!err) return resolve(false);
			// No ps binary at all → undetectable; assume unsandboxed (the
			// annoying-but-safe direction rather than a false 🔒).
			resolve(err.code !== "ENOENT");
		});
	});
	return sandboxProbe;
}

// ============================================================
// Git (cached per cwd)
// ============================================================

interface GitInfo {
	repo: boolean;
	branch?: string;
	added?: number;
	removed?: number;
	ahead?: number;
	behind?: number;
	at: number;
}

const gitCache = new Map<string, GitInfo>();

function gitExec(cwd: string, args: string[]): Promise<string | null> {
	return new Promise((resolve) => {
		execFile("git", args, { cwd, timeout: 3000 }, (err, stdout) => resolve(err ? null : stdout));
	});
}

async function getGitInfo(cwd: string, cfg: StatuslineConfig): Promise<GitInfo | null> {
	const cached = gitCache.get(cwd);
	if (cached && Date.now() - cached.at < (cfg.git.cacheMs || 0)) {
		return cached.repo ? cached : null;
	}

	const diffArgs = ["diff"];
	if (cfg.git.includeStaged) diffArgs.push("HEAD");
	diffArgs.push("--numstat");

	const [branch, numstat, aheadBehind] = await Promise.all([
		gitExec(cwd, ["rev-parse", "--abbrev-ref", "HEAD"]),
		gitExec(cwd, diffArgs),
		gitExec(cwd, ["rev-list", "--left-right", "--count", "@{upstream}...HEAD"]),
	]);

	if (branch === null) {
		gitCache.set(cwd, { repo: false, at: Date.now() });
		return null;
	}

	let added = 0;
	let removed = 0;
	if (numstat) {
		for (const line of numstat.split("\n")) {
			const [a, d] = line.split("\t");
			const ai = parseInt(a ?? "", 10);
			const di = parseInt(d ?? "", 10);
			if (Number.isFinite(ai)) added += ai;
			if (Number.isFinite(di)) removed += di;
		}
	}

	let ahead: number | undefined;
	let behind: number | undefined;
	if (aheadBehind) {
		const [l, r] = aheadBehind.trim().split(/\s+/).map(Number);
		if (Number.isFinite(l)) behind = l;
		if (Number.isFinite(r)) ahead = r;
	}

	const info: GitInfo = { repo: true, branch: branch.trim(), added, removed, ahead, behind, at: Date.now() };
	gitCache.set(cwd, info);
	return info;
}

// ============================================================
// Session stats
// ============================================================

interface SessionStats {
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	cost: number;
	turns: number;
}

function getSessionStats(ctx: any): SessionStats {
	const stats: SessionStats = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, cost: 0, turns: 0 };
	try {
		for (const entry of ctx.sessionManager.getBranch()) {
			if (entry.type !== "message" || !entry.message) continue;
			const m = entry.message;
			if (m.role === "assistant" && m.usage) {
				stats.input += m.usage.input || 0;
				stats.output += m.usage.output || 0;
				stats.cacheRead += m.usage.cacheRead || 0;
				stats.cacheWrite += m.usage.cacheWrite || 0;
				stats.cost += m.usage.cost?.total || 0;
			} else if (m.role === "user") {
				stats.turns++;
			}
		}
	} catch {
		// session not ready — zeros are fine
	}
	return stats;
}

// ============================================================
// Segment builders
// ------------------------------------------------------------
// Each builder: (ctx, cfg, opts, data) → painted string | undefined
// `opts` = the global section for this segment deep-merged with any
// per-instance options from the `segments` entry. Return undefined to hide.
// ============================================================

type BuildFn = (ctx: any, cfg: StatuslineConfig, o: any, d: RenderData) => string | undefined;

interface RenderData {
	ctx: any;
	theme: any;
	usage: { tokens: number | null; contextWindow: number; percent: number | null } | undefined;
	stats: SessionStats;
	git: GitInfo | null;
	cwd: string | undefined;
	sandbox: boolean;
	/** paint(spec, text, percent?) — wraps text in the resolved color */
	P: Painter["P"];
	/** ansi(spec, percent?) — raw ANSI prefix for a color spec */
	ansi: Painter["ansi"];
	/** merged colors: cfg.colors overridden by segment-instance `colors` */
	colors: Record<string, string>;
}

/** Colors for a multi-part segment: global cfg.colors + per-instance `colors`. */
function partColors(cfg: StatuslineConfig, o: any): Record<string, string> {
	return { ...cfg.colors, ...(o.colors ?? {}) };
}

function segModel(ctx: any, cfg: StatuslineConfig, o: any, d: RenderData): string | undefined {
	const model = ctx.model;
	if (!model) return undefined;

	const qualified = `${model.provider}/${model.id}`;
	let name = o.aliases?.[qualified] ?? o.aliases?.[model.id] ?? model.id;
	if (o.showProvider) name = `${model.provider}/${name}`;
	if (!name) return undefined;

	const colors = partColors(cfg, o);
	let out = "";
	if (o.showSandbox) {
		// sandbox display opts: global "sandbox" section, overridable per instance
		const sb = deepMerge(cfg.sandbox ?? {}, o.sandbox ?? {});
		const icon = sb.icons?.[d.sandbox ? "yes" : "no"];
		if (icon) out += d.P(colors[d.sandbox ? "sandboxYes" : "sandboxNo"], icon) + " ";
	}
	out += d.P(o.color ?? colors.model, (o.icon ? o.icon + " " : "") + name);

	if (o.showThinking) {
		const level = ctx.thinkingLevel;
		if (level && level !== "off") {
			const label = cfg.thinking.labels[level] ?? level;
			if (label) out += " " + d.P(colors.thinking, label);
		}
	}
	return out;
}

function segThinking(ctx: any, cfg: StatuslineConfig, o: any, d: RenderData): string | undefined {
	const level = ctx.thinkingLevel;
	if (!level || level === "off") return undefined;
	const label = o.labels?.[level] ?? level;
	if (!label) return undefined;
	return d.P(o.color ?? cfg.colors.thinking, label);
}

function segContext(ctx: any, cfg: StatuslineConfig, o: any, d: RenderData): string | undefined {
	const colors = partColors(cfg, o);
	const tokens = d.usage?.tokens ?? null;
	const pct = d.usage?.percent ?? null;
	const window = d.usage?.contextWindow || ctx.model?.contextWindow || 0;

	const style: string = o.style || "bar+tokens+pct";
	const parts: string[] = [];

	if (style.includes("bar")) {
		const p = Math.max(0, Math.min(100, Math.round(pct ?? 0)));
		const width = Math.max(1, o.barWidth | 0);
		const filled = Math.round((p * width) / 100);
		const fill = o.barFilled.repeat(filled);
		const empty = o.barEmpty.repeat(width - filled);
		parts.push(d.P(colors.contextBarFilled, fill, pct) + d.P(colors.contextBarEmpty, empty, pct));
	}
	if (style.includes("tokens")) {
		const used = tokens === null ? "?" : formatTokens(tokens, o.tokenFormat);
		const total = window ? formatTokens(window, o.tokenFormat) : "?";
		parts.push(d.P(colors.contextTokens, `${used}/${total}`, pct));
	}
	if (style.includes("pct")) {
		parts.push(d.P(colors.contextPct, pct === null ? "–%" : `${Math.round(pct)}%`, pct));
	}

	return parts.join(" ") || undefined;
}

function segSession(_ctx: any, cfg: StatuslineConfig, o: any, d: RenderData): string | undefined {
	const colors = partColors(cfg, o);
	const s = d.stats;

	const defs: Record<string, { icon: string; value: string; color: string }> = {
		in: { icon: o.icons?.in ?? "↑", value: formatTokens(s.input, o.tokenFormat), color: colors.sessionIn },
		out: { icon: o.icons?.out ?? "↓", value: formatTokens(s.output, o.tokenFormat), color: colors.sessionOut },
		cacheRead: { icon: o.icons?.cacheRead ?? "⟲", value: formatTokens(s.cacheRead, o.tokenFormat), color: colors.sessionCacheRead },
		cacheWrite: { icon: o.icons?.cacheWrite ?? "✎", value: formatTokens(s.cacheWrite, o.tokenFormat), color: colors.sessionCacheWrite },
		cost: { icon: o.icons?.cost ?? "", value: `${o.costSymbol ?? "$"}${s.cost.toFixed(o.costPrecision ?? 2)}`, color: colors.sessionCost },
		turns: { icon: o.icons?.turns ?? "⟳", value: String(s.turns), color: colors.sessionTurns },
	};

	const parts: string[] = [];
	for (const part of o.parts ?? []) {
		const def = defs[part];
		if (!def || !def.value) continue;
		parts.push(d.P(def.color, (def.icon || "") + def.value));
	}
	return parts.join(" ") || undefined;
}

/** One piece of the project/dir/branch/diff segments. */
function projectPart(part: string, o: any, d: RenderData, colors: Record<string, string>): string | undefined {
	switch (part) {
		case "dir": {
			const dir = displayDir(d.cwd, o.dirStyle);
			return dir ? d.P(colors.dir, dir) : undefined;
		}
		case "branch":
			return d.git?.branch ? d.P(colors.branch, (o.branchPrefix ?? "@") + d.git.branch) : undefined;
		case "diff": {
			if (!d.git || (!d.git.added && !d.git.removed)) return undefined;
			return (
				d.P("dim", "(") +
				d.P(colors.diffAdded, `+${d.git.added || 0}`) + " " +
				d.P(colors.diffRemoved, `-${d.git.removed || 0}`) +
				d.P("dim", ")")
			);
		}
		case "aheadBehind": {
			if (!d.git || (d.git.ahead === undefined && d.git.behind === undefined)) return undefined;
			if (!d.git.ahead && !d.git.behind) return undefined;
			const pieces: string[] = [];
			if (d.git.ahead) pieces.push(d.P(colors.ahead, `↑${d.git.ahead}`));
			if (d.git.behind) pieces.push(d.P(colors.behind, `↓${d.git.behind}`));
			return pieces.join(" ");
		}
		default:
			return undefined;
	}
}

function segProject(ctx: any, cfg: StatuslineConfig, o: any, d: RenderData): string | undefined {
	const colors = partColors(cfg, o);
	const parts: string[] = [];
	for (const part of o.parts ?? []) {
		const piece = projectPart(part, o, d, colors);
		if (piece) parts.push(piece);
	}
	return parts.join(" ") || undefined;
}

function segDir(ctx: any, cfg: StatuslineConfig, o: any, d: RenderData): string | undefined {
	return projectPart("dir", o, d, partColors(cfg, o));
}

function segBranch(ctx: any, cfg: StatuslineConfig, o: any, d: RenderData): string | undefined {
	return projectPart("branch", o, d, partColors(cfg, o));
}

function segDiff(ctx: any, cfg: StatuslineConfig, o: any, d: RenderData): string | undefined {
	return projectPart("diff", o, d, partColors(cfg, o));
}

function segTime(_ctx: any, cfg: StatuslineConfig, o: any, d: RenderData): string | undefined {
	return d.P(o.color ?? cfg.colors.time, strftime(new Date(), o.format || "%H:%M"));
}

function segText(_ctx: any, cfg: StatuslineConfig, o: any, d: RenderData): string | undefined {
	const text = o.text ?? "";
	if (!text) return undefined;
	return d.P(o.color ?? cfg.colors.text, text);
}

function segSandbox(_ctx: any, cfg: StatuslineConfig, o: any, d: RenderData): string | undefined {
	const state = d.sandbox ? "yes" : "no";
	const colors = partColors(cfg, o);
	const icon = o.icons?.[state] ?? "";
	const label = o.labels?.[state] ?? "";
	if (!icon && !label) return undefined;
	return d.P(colors[d.sandbox ? "sandboxYes" : "sandboxNo"], icon + label);
}

const BUILDERS: Record<string, BuildFn> = {
	model: segModel,
	thinking: segThinking,
	sandbox: segSandbox,
	context: segContext,
	session: segSession,
	project: segProject,
	dir: segDir,
	branch: segBranch,
	diff: segDiff,
	time: segTime,
	text: segText,
};

// ============================================================
// Composition — the whole line is a fold over cfg.segments
// ============================================================

async function buildRenderData(ctx: any, cfg: StatuslineConfig): Promise<RenderData> {
	const theme = (ctx.ui as any)?.theme;
	const P = makePainter(theme, cfg);

	return {
		ctx,
		theme,
		usage: ctx.getContextUsage?.(),
		stats: getSessionStats(ctx),
		git: await getGitInfo(ctx.cwd, cfg),
		cwd: ctx.cwd,
		sandbox: await isSandboxed(),
		P: P.P,
		ansi: P.ansi,
		colors: cfg.colors,
	};
}

function composeFromData(cfg: StatuslineConfig, data: RenderData, segments: (string | Record<string, any>)[]): string | undefined {
	const sep = data.P(cfg.separatorColor, cfg.separator);
	const parts: string[] = [];

	for (const entry of segments) {
		const name = typeof entry === "string" ? entry : entry?.segment;
		if (!name) continue;
		const builder = BUILDERS[name];
		if (!builder) continue;

		const entryOpts = typeof entry === "string" ? {} : entry;
		if (entryOpts.enabled === false) continue;

		// per-instance options win over the global section of the same name
		const o = deepMerge((cfg as any)[name] ?? {}, entryOpts);
		const seg = builder(data.ctx, cfg, o, data);
		if (seg) parts.push(seg);
	}

	if (parts.length === 0) return undefined;
	return parts.join(sep);
}

// ============================================================
// Zones — any segment entry may set "align": "right" to be pushed to
// the right edge of the line (padded to the terminal width; falls back
// to inline when the width is unknown, e.g. rpc/print mode).
// ============================================================

function splitSegments(segments: (string | Record<string, any>)[]): {
	leftEntries: (string | Record<string, any>)[];
	rightEntries: (string | Record<string, any>)[];
} {
	const leftEntries: (string | Record<string, any>)[] = [];
	const rightEntries: (string | Record<string, any>)[] = [];
	for (const entry of segments) {
		const align = typeof entry === "string" ? undefined : (entry as any)?.align;
		(align === "right" ? rightEntries : leftEntries).push(entry);
	}
	return { leftEntries, rightEntries };
}

/**
 * Join left/right zones, padding to `width` when known (inline fallback otherwise).
 * Padded with NBSP (")") rather than spaces: pi's footer sanitizer collapses runs
 * of ASCII spaces (sanitizeStatusText: / +/g → " "), which would squash the gap.
 * NBSP survives sanitization and measures as exactly 1 column in visibleWidth.
 */
const PAD = " ";

function joinZones(left: string | undefined, right: string | undefined, sep: string, width: number): string | undefined {
	if (!left && !right) return undefined;
	if (!right) return left;
	if (!left) {
		if (width > 0) return PAD.repeat(Math.max(0, width - visibleWidth(right))) + right;
		return right;
	}
	if (width > 0) {
		const pad = Math.max(1, width - visibleWidth(left) - visibleWidth(right));
		return left + PAD.repeat(pad) + right;
	}
	return left + sep + right;
}

// ============================================================
// Footer takeover
// ------------------------------------------------------------
// setStatus() text is rendered BY pi's built-in footer component, so
// replacing the footer means rendering everything we want ourselves.
//
//   "keep" — built-in footer stays; our line renders via setStatus below it
//   "own"  — we replace the built-in footer: cached left/right lines render
//            width-aware, and other extensions' status items are preserved
//            below. Outside the TUI (rpc/print) we fall back to setStatus.
// ============================================================

let footerApplied = false;
let activeTui: any = null;
let footerLeftLine: string | undefined;
let footerRightLine: string | undefined;

function unapplyFooter(ctx: any): void {
	if (!footerApplied) return;
	footerApplied = false;
	activeTui = null;
	footerLeftLine = undefined;
	footerRightLine = undefined;
	try { (ctx.ui as any).setFooter(undefined); } catch { /* ignore */ }
}

function applyFooterMode(ctx: any, cfg: StatuslineConfig, force = false): void {
	const ui = (ctx.ui as any);
	if (ctx.mode !== "tui" || typeof ui?.setFooter !== "function") return;

	if (cfg.footer === "keep") {
		unapplyFooter(ctx);
		return;
	}
	if (footerApplied && !force) return;
	if (footerApplied) unapplyFooter(ctx);
	footerApplied = true;

	ui.setFooter((tui: any, _theme: any, footerData: any) => {
		activeTui = tui;
		let unsub: (() => void) | undefined;
		try {
			unsub = footerData?.onBranchChange?.(() => tui.requestRender());
		} catch { /* optional API */ }
		return {
			dispose() {
				if (typeof unsub === "function") { try { unsub(); } catch { /* ignore */ } }
				if (activeTui === tui) activeTui = null;
			},
			invalidate() {},
			render(width: number): string[] {
				const lines: string[] = [];
				const left = footerLeftLine;
				const right = footerRightLine;
				if (left && right) {
					const pad = Math.max(1, width - visibleWidth(left) - visibleWidth(right));
					lines.push(truncateToWidth(left + " ".repeat(pad) + right, width));
				} else if (left) {
					lines.push(truncateToWidth(left, width));
				} else if (right) {
					lines.push(truncateToWidth(" ".repeat(Math.max(0, width - visibleWidth(right))) + right, width));
				}
				// keep other extensions' status items visible below our line
				try {
					const statuses = footerData?.getExtensionStatuses?.();
					if (statuses) {
						for (const [key, text] of statuses) {
							if (key !== STATUS_KEY && text) lines.push(truncateToWidth(text, width));
						}
					}
				} catch { /* ignore */ }
				return lines;
			},
		};
	});
}

// ============================================================
// Refresh plumbing
// ============================================================

let refreshSeq = 0;
let resizeHooked = false;
let lastRefreshCtx: any = null;

function hookResize(ctx: any): void {
	lastRefreshCtx = ctx;
	if (resizeHooked) return;
	const stdout = process.stdout as any;
	if (typeof stdout?.on === "function") {
		resizeHooked = true;
		stdout.on("resize", () => {
			if (lastRefreshCtx) scheduleRefresh(lastRefreshCtx);
		});
	}
}

function scheduleRefresh(ctx: any): void {
	if (!ctx?.hasUI) return;
	hookResize(ctx);
	const seq = ++refreshSeq;
	void (async () => {
		try {
			const cfg = loadConfig(ctx.cwd);
			applyFooterMode(ctx, cfg);
			const data = await buildRenderData(ctx, cfg);
			if (seq !== refreshSeq) return; // a newer refresh superseded this one

			const { leftEntries, rightEntries } = splitSegments(cfg.segments);
			const left = composeFromData(cfg, data, leftEntries);
			const right = rightEntries.length ? composeFromData(cfg, data, rightEntries) : undefined;
			const sep = data.P(cfg.separatorColor, cfg.separator);

			if (footerApplied && cfg.footer === "own") {
				// our line lives IN the footer now — zones render width-aware there
				footerLeftLine = left;
				const footerRightEntries = [...rightEntries, ...cfg.footerRight];
				footerRightLine = footerRightEntries.length ? composeFromData(cfg, data, footerRightEntries) : undefined;
				try { activeTui?.requestRender?.(); } catch { /* ignore */ }
			} else {
				if (footerApplied) {
					footerLeftLine = undefined;
					footerRightLine = undefined;
				}
				let line = joinZones(left, right, sep, process.stdout?.columns || 0);
				if (line && cfg.maxWidth > 0) line = truncateToWidth(line, cfg.maxWidth);
				ctx.ui.setStatus(STATUS_KEY, line);
			}
		} catch {
			// never let the statusline take the session down
		}
	})();
}

// ============================================================
// Config template (used by /statusline when no config exists)
// ============================================================

function configTemplate(): string {
	return `// ── pi statusline configuration ─────────────────────────────────────
// This file is JSONC: // comments, /* block comments */ and trailing
// commas are all fine.
//
// Merge order:  built-in defaults → this file → <project>/.pi/statusline.json
// Edit anytime with /statusline (this file) or /statusline project.
// /statusline reset deletes both and returns to built-in defaults.
//
// Colors may be:
//   - a theme token name (accent, muted, dim, success, warning, error, text,
//     toolDiffAdded, toolDiffRemoved, thinkingHigh, syntaxString, ...)
//   - "auto" → colored by the first matching entry in "thresholds"
//   - "#rrggbb" → raw truecolor (bypasses the theme)
//   - "none"
{
  // Segment pipeline. Order = render order. Remove, reorder or duplicate
  // freely. An entry may be a plain name or an object overriding options
  // for that one instance:
  //   "context"
  //   { "segment": "context", "barWidth": 20, "colors": { "contextPct": "#ff8800" } }
  //   { "segment": "text", "text": "🚀", "color": "accent" }
  //   { "segment": "session", "enabled": false }
  //   { "segment": "project", "align": "right" }   // push to the right edge
  //
  // Built-in segments:
  //   model     current model (+ provider + thinking level + sandbox icon)
  //   thinking  thinking level on its own
  //   sandbox   sandbox indicator on its own (🔒 sandboxed / ⚠ unsandboxed)
  //   context   context-window usage: bar / tokens / percent
  //   session   session totals: in, out, cacheRead, cacheWrite, cost, turns
  //   project   dir + branch + diff (+ aheadBehind)
  //   dir       working directory alone
  //   branch    git branch alone
  //   diff      git diff stat alone
  //   time      current time (strftime-style)
  //   text      literal text
  "segments": [
    "model",
    "session",
    { "segment": "project", "align": "right" }
    // "align": "right" pads the line so the segment sits at the right edge
    // (re-pads automatically on terminal resize).
    //
    // "context" is omitted by default — pi's built-in footer already shows
    // context usage. Add it back (or set "footer": "own") if you want it here.
  ],

  // Text between segments, and its color.
  "separator": " | ",
  "separatorColor": "dim",

  // Hard-truncate the whole line to N terminal columns (0 = never).
  "maxWidth": 0,

  // ── footer takeover ──────────────────────────────────────────────
  // pi draws a built-in footer line (context %, provider/model) and this
  // statusline renders below it as a status item. "footer" controls that:
  //   "keep" — built-in footer stays (default)
  //   "own"  — this statusline REPLACES the built-in footer: "segments"
  //            become the left zone and "footerRight" (same syntax as
  //            "segments") an optional right-aligned zone, padded to the
  //            terminal width. Other extensions' status items still render
  //            below. Outside the TUI it falls back to normal behavior.
  "footer": "keep",

  // Right-aligned zone for "footer": "own" — same segment syntax.
  "footerRight": [],

  // Thresholds for every color set to "auto". First matching "at" wins.
  "thresholds": [
    { "at": 0,  "color": "success" },
    { "at": 50, "color": "warning" },
    { "at": 75, "color": "error" }
  ],

  // Default colors for every segment part. Override per instance with
  // "colors": { ... } on a segment object.
  "colors": {
    "model": "accent",
    "thinking": "muted",
    "sandboxYes": "success",
    "sandboxNo": "error",
    "contextBarFilled": "auto",
    "contextBarEmpty": "dim",
    "contextTokens": "auto",
    "contextPct": "auto",
    "sessionIn": "dim",
    "sessionOut": "dim",
    "sessionCacheRead": "dim",
    "sessionCacheWrite": "dim",
    "sessionCost": "muted",
    "sessionTurns": "dim",
    "dir": "accent",
    "branch": "success",
    "diffAdded": "toolDiffAdded",
    "diffRemoved": "toolDiffRemoved",
    "ahead": "success",
    "behind": "error",
    "time": "dim",
    "text": "text"
  },

  // ── model ────────────────────────────────────────────────────────
  "model": {
    "icon": "",               // prefix, e.g. "🤖" or "◆"
    "showProvider": false,    // "openrouter/id" instead of "id"
    "showThinking": true,     // append effective thinking level
    "showSandbox": true,      // prefix the sandbox icon (see "sandbox" below)
    "aliases": {
      // "provider/model-id": "short name",
      // "other-model-id": "also works bare"
    }
  },

  // ── thinking ─────────────────────────────────────────────────────
  // Labels per level; "" hides the level entirely.
  "thinking": {
    "labels": {
      "off": "",
      "minimal": "min",
      "low": "low",
      "medium": "med",
      "high": "high",
      "xhigh": "xhigh",
      "max": "max"
    }
  },

  // ── sandbox ──────────────────────────────────────────────────────
  // Detects an externally-imposed sandbox (safehouse-style): sandboxes
  // that restrict process access make /bin/ps fail. Probed once and
  // cached for the whole session. The model segment reuses these icons
  // when "showSandbox" is on; override per instance with e.g.
  // { "segment": "model", "showSandbox": false } or
  // { "segment": "model", "sandbox": { "icons": { "yes": "🛡" } } }.
  "sandbox": {
    "icons": { "yes": "🔒", "no": "⚠" },
    "labels": { "yes": "", "no": "" }   // optional text after the icon
  },

  // ── context ──────────────────────────────────────────────────────
  // "style": any combination of bar, tokens, pct (always that order).
  "context": {
    "style": "bar+tokens+pct",
    "barWidth": 10,
    "barFilled": "█",
    "barEmpty": "░",
    "tokenFormat": "compact"  // compact | commas | raw
  },

  // ── session ──────────────────────────────────────────────────────
  // "parts": any subset of in | out | cacheRead | cacheWrite | cost | turns
  "session": {
    "parts": ["in", "out", "cost"],
    "tokenFormat": "compact",
    "costSymbol": "$",
    "costPrecision": 2,
    "icons": { "in": "↑", "out": "↓", "cacheRead": "⟲", "cacheWrite": "✎", "cost": "", "turns": "⟳" }
  },

  // ── project ──────────────────────────────────────────────────────
  // "parts": any subset of dir | branch | diff | aheadBehind
  "project": {
    "parts": ["dir", "branch", "diff"],
    "dirStyle": "basename",   // basename | full | tilde
    "branchPrefix": "@"
  },

  // ── time ─────────────────────────────────────────────────────────
  // strftime subset: %Y %m %d %e %H %I %M %S %p %b %B %a %A %% (- = no pad)
  "time": { "format": "%H:%M" },

  // ── git (shared by project / branch / diff segments) ─────────────
  "git": {
    "includeStaged": false,   // count staged changes too (git diff HEAD)
    "cacheMs": 1500           // how long git lookups are cached
  }
}
`;
}

// ============================================================
// Extension wiring
// ============================================================

export default function (pi: ExtensionAPI) {
	// Re-render whenever anything the line can display might have changed.
	pi.on("session_start", (_event, ctx) => {
		// force: a replaced session reuses this module — re-claim the footer
		applyFooterMode(ctx, loadConfig(ctx.cwd), true);
		scheduleRefresh(ctx);
	});
	pi.on("session_info_changed", (_event, ctx) => scheduleRefresh(ctx));
	pi.on("model_select", (_event, ctx) => scheduleRefresh(ctx));
	pi.on("thinking_level_select", (_event, ctx) => scheduleRefresh(ctx));
	pi.on("message_end", (_event, ctx) => scheduleRefresh(ctx));
	pi.on("turn_end", (_event, ctx) => scheduleRefresh(ctx));
	pi.on("agent_end", (_event, ctx) => scheduleRefresh(ctx));
	pi.on("session_compact", (_event, ctx) => scheduleRefresh(ctx));
	pi.on("session_tree", (_event, ctx) => scheduleRefresh(ctx));

	pi.on("session_shutdown", (_event, ctx) => {
		try { ctx.ui.setStatus(STATUS_KEY, undefined); } catch { /* ignore */ }
		unapplyFooter(ctx);
	});

	pi.registerCommand("statusline", {
		description: "Edit statusline config (global | project | reset)",
		handler: async (args, ctx) => {
			const sub = (args || "global").trim().toLowerCase();

			if (sub === "reset") {
				const ok = await ctx.ui.confirm(
					"Reset statusline config?",
					"Deletes the global and project config files. Built-in defaults apply again.",
				);
				if (!ok) return;
				for (const path of [globalConfigPath(), projectConfigPath(ctx.cwd)]) {
					try { unlinkSync(path); } catch { /* didn't exist */ }
				}
				ctx.ui.notify("Statusline config reset", "info");
				scheduleRefresh(ctx);
				return;
			}

			if (sub !== "global" && sub !== "project") {
				ctx.ui.notify("Usage: /statusline [global|project|reset]", "warning");
				return;
			}

			const path = sub === "project" ? projectConfigPath(ctx.cwd) : globalConfigPath();
			const existing = existsSync(path) ? readFileSync(path, "utf8") : configTemplate();

			const edited = await ctx.ui.editor(`statusline config (${sub})`, existing);
			if (edited === undefined || edited === existing) return;

			try {
				JSON.parse(stripJsonComments(edited));
			} catch (e: any) {
				ctx.ui.notify(`Statusline config not saved — invalid JSON: ${e?.message ?? e}`, "error");
				return;
			}

			mkdirSync(dirname(path), { recursive: true });
			writeFileSync(path, edited);
			ctx.ui.notify(`Saved ${path}`, "info");
			scheduleRefresh(ctx);
		},
	});
}
