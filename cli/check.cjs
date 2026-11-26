const fs = require("node:fs");
const engine = require("../dist/engine.cjs");

function run(args) {
  const json = args[0] === "--json";
  const files = json ? args.slice(1) : args;
  if (files.length !== 2) {
    console.error("用法：node cli/check.cjs [--json] 原文.json 译文.json");
    return 2;
  }
  let result;
  try {
    const [source, translation] = files.map((file) => fs.readFileSync(file, "utf8"));
    result = JSON.parse(engine.audit_json(source, translation));
  } catch (error) {
    console.error(error.message);
    return 2;
  }
  if (json) {
    console.log(JSON.stringify(result, null, 2));
  } else {
    console.log("已对照 " + result.checked + " 条消息，" + result.errors + " 个错误，" + result.warnings + " 条提示。");
    for (const item of result.findings) {
      const where = item.side === "source" ? "原文" : "译文";
      const severity = item.severity === "error" ? "错误" : "提示";
      console.log([severity, where, item.key || "整个文件", item.detail].join("  "));
    }
  }
  return result.errors ? 1 : 0;
}
process.exitCode = run(process.argv.slice(2));
