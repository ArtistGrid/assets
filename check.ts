import { readdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const BASE = "https://sheetsv3.edideaur.workers.dev";
const IMAGE_DIR = join(import.meta.dir, "og");

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

function availableImages(): Set<string> {
  const names = new Set<string>();
  for (const name of readdirSync(IMAGE_DIR)) {
    const dot = name.lastIndexOf(".");
    const base = dot === -1 ? name : name.slice(0, dot);
    names.add(normalize(base));
  }
  return names;
}

function main(csv: string): void {
  const artists = parseArtists(csv);
  const have = availableImages();

  const missing: string[] = [];
  for (const artist of artists) {
    if (!have.has(normalize(artist))) {
      missing.push(`${normalize(artist)}`);
    }
  }

  console.log(`Artists: ${artists.size}, Have: ${have.size}, Missing: ${missing.length}`);
  for (const m of missing) {
    console.log(m);
  }
}

if (import.meta.main) {
  await fetchAndTrigger();
  const csv = await fetchCsv();
  writeFileSync("sheet.csv", csv);
  main(csv);
}
