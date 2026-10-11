import { execFileSync } from "node:child_process";
import { existsSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const BASE = "https://sheetsv3.edideaur.workers.dev";

const normalize = (s: string): string =>
  s.toLowerCase().replace(/[^a-z0-9]/g, "");

async function fetchAndTrigger(): Promise<void> {
  await fetch(`${BASE}/trigger`);
}

async function fetchCsv(): Promise<string> {
  const res = await fetch(BASE + "/");
  if (!res.ok) {
    throw new Error(`Failed to fetch CSV: ${res.status} ${res.statusText}`);
  }
  return res.text();
}

function parseCsvRows(csv: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let cur = "";
  let inQuotes = false;
  for (let i = 0; i < csv.length; i++) {
    const ch = csv[i];
    if (inQuotes) {
      if (ch === '"') {
        if (csv[i + 1] === '"') {
          cur += '"';
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cur += ch;
      }
    } else if (ch === '"') {
      inQuotes = true;
    } else if (ch === ",") {
      row.push(cur);
      cur = "";
    } else if (ch === "\n" || ch === "\r") {
      if (ch === "\r" && csv[i + 1] === "\n") i++;
      row.push(cur);
      rows.push(row);
      row = [];
      cur = "";
    } else {
      cur += ch;
    }
  }
  if (cur !== "" || row.length > 0) {
    row.push(cur);
    rows.push(row);
  }
  return rows;
}

function parseArtists(csv: string): Set<string> {
  const rows = parseCsvRows(csv);
  if (rows.length === 0) return new Set();

  const nameIdx = rows[0].indexOf("name");
  if (nameIdx === -1) {
    throw new Error("CSV has no 'name' column");
  }

  const artists = new Set<string>();
  for (let i = 1; i < rows.length; i++) {
    const name = (rows[i][nameIdx] ?? "").trim();
    if (name) artists.add(name);
  }
  return artists;
}

const OG_DIR = join(import.meta.dir, "og");
// Converted formats built by convert.sh / the Convert images workflow.
// They are gitignored on main and only exist on the orphan `dist` branch.
const FORMATS = ["avif", "jxl", "webp", "jpg"];

function baseNames(files: string[]): Set<string> {
  const names = new Set<string>();
  for (const name of files) {
    const dot = name.lastIndexOf(".");
    const base = dot === -1 ? name : name.slice(0, dot);
    if (base) names.add(normalize(base));
  }
  return names;
}

function localBases(dir: string): Set<string> | null {
  if (!existsSync(dir)) return null;
  return baseNames(readdirSync(dir));
}

// Read-only lookup of converted files from the latest `origin/dist`
// commit, so the check works from a main checkout without the build
// artifacts present locally. Returns null when the ref is unavailable.
function distBases(fmt: string): Set<string> | null {
  try {
    const out = execFileSync(
      "git",
      ["ls-tree", "-r", "--name-only", "origin/dist", "--", `${fmt}/`],
      { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] },
    );
    const files = out
      .split("\n")
      .filter((l) => l.startsWith(`${fmt}/`))
      .map((l) => l.slice(fmt.length + 1));
    return baseNames(files);
  } catch {
    return null;
  }
}

function indexStaleness(og: Set<string>): string {
  const indexPath = join(import.meta.dir, "index.json");
  if (!existsSync(indexPath)) return "";
  try {
    const entries = JSON.parse(readFileSync(indexPath, "utf8")) as string[];
    const indexed = baseNames(entries);
    let stale = 0;
    for (const b of og) {
      if (!indexed.has(b)) stale++;
    }
    return `, index.json missing ${stale} og file(s)`;
  } catch {
    return ", index.json unreadable";
  }
}

function main(csv: string): void {
  const artists = parseArtists(csv);
  const og = localBases(OG_DIR) ?? new Set<string>();

  const fmtSets = new Map<string, Set<string> | null>();
  const skipped: string[] = [];
  for (const fmt of FORMATS) {
    const set =
      localBases(join(import.meta.dir, fmt)) ?? distBases(fmt);
    fmtSets.set(fmt, set);
    if (!set) skipped.push(fmt);
  }

  const missingOg: string[] = [];
  const missingByFmt = new Map<string, string[]>();
  for (const fmt of FORMATS) {
    missingByFmt.set(fmt, []);
  }
  for (const artist of artists) {
    const n = normalize(artist);
    if (!og.has(n)) {
      missingOg.push(artist);
      continue;
    }
    for (const fmt of FORMATS) {
      const set = fmtSets.get(fmt);
      if (set && !set.has(n)) {
        missingByFmt.get(fmt)!.push(artist);
      }
    }
  }

  const summary = [
    `Artists: ${artists.size}`,
    `Missing in og: ${missingOg.length}`,
    ...FORMATS.map((fmt) => {
      const set = fmtSets.get(fmt);
      return set
        ? `Missing in ${fmt}: ${missingByFmt.get(fmt)!.length}`
        : `${fmt}: skipped (no local dir, no origin/dist ref)`;
    }),
  ].join(", ");
  console.log(summary + indexStaleness(og));
  for (const m of missingOg) {
    console.log(`${normalize(m)} (missing in: og)`);
  }
  for (const fmt of FORMATS) {
    for (const m of missingByFmt.get(fmt)!) {
      console.log(`${normalize(m)} (missing in: ${fmt})`);
    }
  }
  if (skipped.length > 0) {
    console.log(
      `Note: format coverage for ${skipped.join(", ")} skipped — ` +
        `run ./convert.sh or fetch origin/dist to enable it.`,
    );
  }
}

if (import.meta.main) {
  await fetchAndTrigger();
  const csv = await fetchCsv();
  writeFileSync("sheet.csv", csv);
  main(csv);
}
