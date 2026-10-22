#!/usr/bin/env node
// Mint / verify / revoke a temporary Vercel "Protection Bypass for Automation"
// secret so an automated browser can reach a protected deployment.
//
// Usage:
//   vercel whoami                              # refresh the CLI token FIRST (it expires)
//   node vercel-bypass.mjs baseline <project> <team-slug>
//   node vercel-bypass.mjs create   <project> <team-slug> [note]
//   node vercel-bypass.mjs revoke   <project> <team-slug>
//
// - create writes the generated secret to  <os-tmp>/vbypass-<project>.secret
//   (mode 600) and prints ONLY counts + notes, never the secret value.
// - create ADDS a secret; existing bypass secrets are preserved.
// - revoke reads that file and removes only the secret it created.
//
// Read the secret for a curl/browser header without printing it, e.g.:
//   curl -s -o /dev/null -w "%{http_code}\n" \
//     -H "x-vercel-protection-bypass: $(cat <os-tmp>/vbypass-<project>.secret)" <url>
//
// Reuses the Vercel CLI's own auth token — no separate token needed.

import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { randomBytes } from "node:crypto";
import os from "node:os";
import path from "node:path";

const [cmd, project, teamSlug, note] = process.argv.slice(2);
if (!cmd || !project || !teamSlug) {
  console.error(
    "usage: vercel-bypass.mjs <baseline|create|revoke> <project> <team-slug> [note]",
  );
  process.exit(2);
}

const AUTH_CANDIDATES = [
  "Library/Application Support/com.vercel.cli/auth.json", // macOS
  ".local/share/com.vercel.cli/auth.json", // linux
  ".config/com.vercel.cli/auth.json",
];
const authPath = AUTH_CANDIDATES.map((p) => path.join(os.homedir(), p)).find(
  existsSync,
);
if (!authPath) {
  console.error(
    "vercel auth.json not found — run `vercel login` (and `vercel whoami` to refresh).",
  );
  process.exit(1);
}
const token = JSON.parse(readFileSync(authPath, "utf8")).token;
const secretFile = path.join(os.tmpdir(), `vbypass-${project}.secret`);

const api = async (method, url, body) => {
  const res = await fetch(`https://api.vercel.com${url}`, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    json = { raw: text.slice(0, 300) };
  }
  return { status: res.status, json };
};

// Summarise WITHOUT revealing secret values (the map keys ARE the secrets).
const summarise = (pb = {}) =>
  Object.entries(pb).map(([, v]) => ({
    note: v.note ?? "(none)",
    scope: v.scope,
  }));

const q = `slug=${encodeURIComponent(teamSlug)}`;

if (cmd === "baseline") {
  const { status, json } = await api("GET", `/v9/projects/${project}?${q}`);
  if (status === 403)
    console.error(
      "403 — run `vercel whoami` to refresh the CLI token, then retry.",
    );
  const pb = json.protectionBypass || {};
  console.log(
    `status=${status} count=${Object.keys(pb).length}`,
    JSON.stringify(summarise(pb)),
  );
} else if (cmd === "create") {
  const secret = randomBytes(24)
    .toString("base64")
    .replace(/[^a-zA-Z0-9]/g, "")
    .slice(0, 32)
    .padEnd(32, "0");
  const { status, json } = await api(
    "PATCH",
    `/v1/projects/${project}/protection-bypass?${q}`,
    {
      generate: {
        secret,
        note: note || "temporary QA bypass (automated, auto-revoked)",
      },
    },
  );
  if (status === 200) {
    writeFileSync(secretFile, secret, { mode: 0o600 });
    const pb = json.protectionBypass || {};
    console.log(
      `CREATED count=${Object.keys(pb).length} file=${secretFile}`,
      JSON.stringify(summarise(pb)),
    );
  } else {
    console.error(
      `FAILED status=${status}`,
      JSON.stringify(json).slice(0, 300),
    );
    process.exit(1);
  }
} else if (cmd === "revoke") {
  if (!existsSync(secretFile)) {
    console.error(`no secret file at ${secretFile} — nothing to revoke.`);
    process.exit(1);
  }
  const secret = readFileSync(secretFile, "utf8").trim();
  const { status, json } = await api(
    "PATCH",
    `/v1/projects/${project}/protection-bypass?${q}`,
    {
      revoke: { secret, regenerate: false },
    },
  );
  const pb = json.protectionBypass || {};
  console.log(
    `REVOKED status=${status} count=${Object.keys(pb).length}`,
    JSON.stringify(summarise(pb)),
  );
} else {
  console.error(`unknown command: ${cmd}`);
  process.exit(2);
}
