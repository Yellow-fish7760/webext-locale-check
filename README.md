# 扩展译文检查

面向浏览器扩展维护者和本地化人员的离线检查工具。导入默认语言与目标语言的两份 messages.json，可以找出译文遗漏的运行时参数、变更的参数绑定和缺少的消息。报告保留消息键，方便回到原文件修改。

## 打开网页

双击 [离线工具](dist/locale-check.html)。首页的收款通知示例中，原文由调用程序分别传入付款人和金额，中文译文只保留了付款人。点击“查看修正示例”可以核对补回金额后的结果。检查自己的扩展时，依次选择两份 UTF-8 JSON 文件，即可导出本次报告。网页在本机读取文件，无需账号或联网。

## 如何判读

| 报告 | 含义 |
| --- | --- |
| 漏用或新增参数 | 中文和原文使用的运行时参数集合不同。例如金额由第二个参数传入，漏掉该参数会使金额消失。 |
| 同名变量绑定改变 | 两个语言文件都写了同名占位符，绑定的参数却不同。即使两个译文都用了相同数量的变量，也可能出现姓名和金额互换。 |
| 未定义或格式无效 | 检查消息引用的占位符、字段类型、重复键以及名称的大小写冲突。 |
| 语言回退提示 | 译文缺少一条消息时，浏览器会沿其语言回退链查找。团队可根据目标市场决定是否补译。 |

允许语序变化、变量重复使用，以及保留运行时参数的占位符改名。两种语言若都复用某个占位符名称，会额外核对它的参数绑定。规则覆盖 Chrome 扩展消息格式中的命名占位符、直接位置参数和美元符号转义。文案质量、固定品牌文本和应用自定义的双花括号模板需另行审阅。[Chrome 扩展消息格式](https://developer.chrome.com/docs/extensions/how-to/ui/localization-message-formats)

## 命令行

已有 Node.js 的用户可直接使用随包提供的编译结果。

~~~sh
node cli/check.cjs examples/en.json examples/zh-CN.review.json
node cli/check.cjs --json examples/en.json examples/zh-CN.fixed.json
~~~

第一条应报告 1 个错误和 1 条提示。第二条应报告 4 条消息通过。退出码 0 表示检查结束且没有错误，1 表示发现内容错误，2 表示参数或读文件失败。只含语言回退提示时退出码为 0。

## 构建与验证

检查引擎用 MoonBit 编写。网页与命令行共用编译生成的 JavaScript。网页内嵌引擎和示例，下载一个 HTML 文件就能运行。使用 MoonBit 2026-11-26 的稳定工具链和 Node.js。

~~~sh
moon test --target js
moon build --target js --release
node cli/build.cjs
node --test cli/check.test.cjs
~~~

14 项引擎回归测试涵盖变量丢失、参数对调、同义改名、Unicode、JSON 格式错误和语言回退。另有 3 项交付测试覆盖命令行退出码、示例报告、单文件网页脚本语法与引擎一致性。

使用 uBlock Origin 1.64.0 公开的英语和简体中文语言文件实测，成功对照 328 条同名消息，报告 0 个错误、0 条提示。这份英语文件没有定义命名占位符，金额丢失和同名变量对调分别由专门的回归用例验证。第三方项目的数据仅用于本地验证。[uBlock Origin 1.64.0](https://github.com/gorhill/uBlock/tree/1.64.0/src/_locales)

## 实现与来源

1. 分别解析两份 JSON，发现无效内容时标明原文或译文。消息键与占位符名按大小写不敏感规则匹配。
2. 展开实际使用的命名占位符，再从展开后的文本读取位置参数。相邻片段拼出的位置参数也可识别。
3. 对照各消息使用的参数集合，再比较两边共同使用的同名占位符与参数绑定。输入文件只读。

项目由 Codex 辅助完成代码、测试和说明。检查逻辑参考 Chrome 公开文档与 Chromium 对命名占位符和参数替换的说明。项目源代码使用 MIT 许可证。编译产物包含 MoonBit 标准库，其许可证和声明位于 third_party 目录，同时嵌入发行文件。[Chromium 消息处理](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/extensions/common/message_bundle.cc) · [MoonBit 标准库](https://github.com/moonbitlang/core)
