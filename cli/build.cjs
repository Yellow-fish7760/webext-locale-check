const fs = require("node:fs");
const path = require("node:path");
const root = path.resolve(__dirname, "..");
const read = (name) => fs.readFileSync(path.join(root, name), "utf8");
const notice = [
  read("LICENSE"),
  "Bundled MoonBit core — Apache License 2.0",
  read("third_party/moonbit-core-LICENSE.txt"),
  read("third_party/moonbit-core-NOTICE.txt"),
].join("\n\n").replaceAll("*/", "* /");
const compiled = "/*!\n" + notice + "\n*/\n" + read("_build/js/release/build/webext_locale_check.js");
const examples = {
  en: read("examples/en.json"), review: read("examples/zh-CN.review.json"), fixed: read("examples/zh-CN.fixed.json"),
};
const html = read("web/page.html")
  .replace("/* COMPILED_MOONBIT */", () => compiled.replace(/<\/script/gi, "<\\/script"))
  .replace("/* JSON_EXAMPLES */ null", () => JSON.stringify(examples).replace(/</g, "\\u003c"));
const out = path.join(root, "dist");
fs.mkdirSync(out, { recursive: true });
fs.writeFileSync(path.join(out, "engine.cjs"), compiled);
fs.writeFileSync(path.join(out, "locale-check.html"), html);
