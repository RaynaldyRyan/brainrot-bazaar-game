// Brainrot Bazaar — the hand-in program for roblox-brainrot-01 (Node 22,
// standard library only). It gathers the Rojo-built place and the entry
// files beside this file into the output directory in the shape the gate
// expects, then builds the dossier the judge reads.
//
//   ~/workspace/.tools/rojo/rojo build default.project.json --output game.rbxl
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
//
// Outside the grader's container MAKEFUN_OUTPUT_DIR stands in for /output.
// Every name under the output must start with a letter, a digit or _ and
// hold only letters, digits, . _ and - , so dotfiles (.gitkeep, .DS_Store)
// are skipped at every depth: one of them anywhere under /output fails
// the entry.

import { copyFileSync, cpSync, existsSync, mkdirSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { basename, join } from "node:path";
import { fileURLToPath } from "node:url";
import { buildDossier } from "./vendor/makefun-roblox.ts";

// The repository root is the directory this file lives in.
const repoRoot = fileURLToPath(new URL(".", import.meta.url));
// The grader gives us /output; locally we write wherever the env var says.
const outputDir = process.env.MAKEFUN_OUTPUT_DIR ?? "/output";

// Skip anything whose name starts with a dot, file or directory.
function isVisible(path: string): boolean {
	return !basename(path).startsWith(".");
}

// Copy one top-level file, failing loudly if it is missing.
function copyRequiredFile(name: string): void {
	const from = join(repoRoot, name);
	if (!existsSync(from)) {
		throw new Error(`missing entry file: ${name} (run rojo build first for game.rbxl)`);
	}
	copyFileSync(from, join(outputDir, name));
}

// Copy one top-level directory, creating it first; an empty screenshots/
// directory is fine for a local probe run, the real captures come later.
function copyDirIfPresent(name: string): void {
	const from = join(repoRoot, name);
	const to = join(outputDir, name);
	mkdirSync(to, { recursive: true });
	if (!existsSync(from)) {
		return;
	}
	cpSync(from, to, { recursive: true, filter: isVisible });
}

mkdirSync(outputDir, { recursive: true });
copyRequiredFile("game.rbxl");
copyRequiredFile("PLAY.json");
copyDirIfPresent("src");
copyDirIfPresent("screenshots");

// Fail early with a plain message when the captures are not in yet, instead
// of letting the dossier builder be the one to complain: screenshots are
// taken in Roblox Studio after the playtest, and the entry is not
// submittable without 3 or 4 of them. A probe run with an empty
// screenshots/ folder is expected to stop here.
const shotNames = existsSync(join(outputDir, "screenshots"))
	? readdirSync(join(outputDir, "screenshots")).filter((name) => !name.startsWith("."))
	: [];
if (shotNames.length === 0) {
	throw new Error(
		"no screenshots yet: take 3 or 4 captures of the game running in Roblox Studio (1280x720, first by name is the cover/thumbnail) and put them in screenshots/ before handing in",
	);
}

// The dossier caps screenshots at 4: a 5th capture fails the whole entry
// at grading, so refuse it here with the extra names spelled out instead
// of handing in a doomed dossier.
if (shotNames.length > 4) {
	throw new Error(
		`too many screenshots: ${shotNames.length} in screenshots/ but the dossier allows at most 4 — remove: ${shotNames.slice(4).join(", ")}`,
	);
}

// The dossier is the judge's view of the game: screenshots first, then the
// place text (instance counts, script list, sources), capped at 65,536
// bytes of text. The caps below are the bounty's own: at most 4 screenshots
// of at most 256 KiB each, at most 500,000 place instances, at most 8 MiB
// of script source, at most 1,048,576 characters of script paths. A place
// past one of the hard caps fails here exactly where the scorer would fail it.
const dossier = buildDossier(outputDir, {
	text_max_bytes: 65536,
	screenshots: { max: 4, max_bytes: 262144 },
	max_instances: 500000,
	scripts_max_source_bytes: 8388608,
	scripts_max_path_chars: 1048576,
});
writeFileSync(join(outputDir, "dossier.json"), dossier);

// The dossier JSON wraps the text plus the screenshots as base64; the text
// itself is the part capped at 65,536 bytes, so report both sizes.
const dossierText = JSON.parse(Buffer.from(dossier).toString("utf8")).text as string;
const placeBytes = statSync(join(outputDir, "game.rbxl")).size;
console.log(
	`Brainrot Bazaar handed in: ${shotNames.length} screenshot(s), place ${placeBytes} bytes, dossier ${dossier.length} bytes, dossier text ${Buffer.byteLength(dossierText, "utf8")} bytes.`,
);
