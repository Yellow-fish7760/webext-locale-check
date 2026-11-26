const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const { Script } = require("node:vm");
const root = path.resolve(__dirname, "..");
const run = (...args) => spawnSync(process.execPath, [path.join("cli", "check.cjs"), ...args], { cwd:root, encoding:"utf8" });

test("review and corrected examples have the expected exit codes and findings", () => {
  const review = run("--json", "examples/en.json", "examples/zh-CN.review.json");
  assert.equal(review.status, 1);
  const result = JSON.parse(review.stdout);
  assert.deepEqual([result.checked, result.errors, result.warnings], [3, 1, 1]);
  const omitted = result.findings.find((item) => item.code === "missing_slot");
  assert.equal(omitted.key, "invoicePaid");
  assert.match(omitted.detail, /\$2/);
  const fixed = run("--json", "examples/en.json", "examples/zh-CN.fixed.json");
  assert.equal(fixed.status, 0);
  assert.deepEqual(JSON.parse(fixed.stdout), {checked:4, errors:0, warnings:0, findings:[]});
});

test("incomplete arguments and I/O failures give actionable errors", () => {
  assert.equal(run().status, 2);
  const missing = run("examples/does-not-exist.json", "examples/en.json");
  assert.equal(missing.status, 2);
  assert.match(missing.stderr, /does-not-exist/);
});

test("the portable release contains an inline, syntactically valid script and the tested engine", () => {
  const html = fs.readFileSync(path.join(root, "dist", "locale-check.html"), "utf8");
  const engine = fs.readFileSync(path.join(root, "dist", "engine.cjs"), "utf8");
  const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)];
  assert.equal(scripts.length, 1);
  assert.doesNotThrow(() => new Script(scripts[0][1]));
  assert.ok(scripts[0][1].includes(engine.replace(/<\/script/gi, "<\\/script")));
  assert.doesNotMatch(html, /COMPILED_MOONBIT|JSON_EXAMPLES|<script[^>]*\ssrc=/i);
});
