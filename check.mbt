///|
#derive(ToJson)
pub struct Finding {
  severity : String
  side : String
  key : String
  code : String
  detail : String
}

///|
#derive(ToJson)
pub struct Report {
  checked : Int32
  errors : Int32
  warnings : Int32
  findings : Array[Finding]
}

///|
priv struct Entry {
  name : String
  slots : Array[Int32]
  named : Map[String, Array[Int32]]
}

///|
fn valid_name_char(c : Char) -> Bool {
  c.is_ascii_alphabetic() || c.is_ascii_digit() || c == '_' || c == '@'
}

///|
fn valid_name(s : String) -> Bool {
  !s.is_empty() && s.to_array().iter().all(valid_name_char)
}

///|
fn[V] sorted_keys(m : Map[String, V]) -> Array[String] {
  let keys = m.keys().to_array()
  keys.sort()
  keys
}

///|
// Chromium interprets a run of two or more dollar signs as escaped text.
// Only the single digits 1 through 9 identify caller-supplied arguments.
fn slots_used(text : String) -> Array[Int32] {
  let chars = text.to_array()
  let result = []
  let mut i = 0
  while i + 1 < chars.length() {
    if chars[i] != '$' {
      i += 1
      continue
    }
    i += 1
    if chars[i] == '$' {
      while i < chars.length() && chars[i] == '$' {
        i += 1
      }
    } else {
      let c = chars[i]
      if c >= '1' && c <= '9' {
        let slot = c.to_int() - '0'.to_int()
        if !result.contains(slot) {
          result.push(slot)
        }
      }
      i += 1
    }
  }
  result.sort()
  result
}

///|
fn read_entry(
  key : String,
  value : Json,
  side : String,
  issues : Array[Finding],
) -> Entry? {
  fn fail(code : String, detail : String) -> Unit {
    issues.push({ severity: "error", side, key, code, detail, })
  }
  guard value is Object(fields) else {
    fail("entry_type", "这条消息需要一个含 message 字段的对象。")
    return None
  }
  guard fields.get("message") is Some(String(message)) else {
    fail("message_type", "message 字段必须是字符串。")
    return None
  }
  let before = issues.length()
  let definitions : Map[String, String] = Map([])
  match fields.get("placeholders") {
    None => ()
    Some(Object(items)) =>
      for name in sorted_keys(items) {
        let folded = name.to_lower()
        if !valid_name(name) {
          fail("placeholder_name", "占位符名称无效：\{name}")
          continue
        }
        if definitions.contains(folded) {
          fail(
            "duplicate_placeholder",
            "同一个占位符出现了两种大小写：\{name}",
          )
          continue
        }
        if items.get(name) is Some(Object(item)) &&
          item.get("content") is Some(String(content)) {
          definitions[folded] = content
        } else {
          fail(
            "placeholder_content",
            "占位符 \{name} 需要字符串类型的 content。",
          )
        }
      }
    Some(_) =>
      fail("placeholders_type", "placeholders 字段必须是对象。")
  }
  if issues.length() != before {
    return None
  }

  // Resolve named tokens first, then inspect the fully expanded text. A slot
  // can even straddle the boundary between a constant and the following text.
  let chars = message.to_array()
  let expanded = StringBuilder()
  let named : Map[String, Array[Int32]] = Map([])
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '$' {
      let mut end = i + 1
      while end < chars.length() && valid_name_char(chars[end]) {
        end += 1
      }
      if end > i + 1 && end < chars.length() && chars[end] == '$' {
        let name = String::from_array(chars[i + 1:end]).to_lower()
        match definitions.get(name) {
          Some(content) => {
            expanded.write_string(content)
            named[name] = slots_used(content)
          }
          None =>
            fail(
              "undefined_placeholder",
              "消息引用了未定义的占位符 $\{name}$。",
            )
        }
        i = end + 1
        continue
      }
    }
    expanded.write_char(chars[i])
    i += 1
  }
  if issues.length() != before {
    return None
  }
  Some({ name: key, slots: slots_used(expanded.to_string()), named, })
}

///|
fn catalog(
  text : String,
  side : String,
  issues : Array[Finding],
) -> Map[String, Entry?]? {
  fn fail(key : String, code : String, detail : String) -> Unit {
    issues.push({ severity: "error", side, key, code, detail, })
  }
  let clean = text.strip_prefix("\u{feff}").unwrap_or(text.to_string_view())
  let parsed = @json.parse(clean, reject_duplicate_keys=true) catch {
    err => {
      fail("", "invalid_json", "JSON 解析失败。\{err}")
      return None
    }
  }
  guard parsed is Object(items) else {
    fail(
      "", "catalog_type", "文件顶层必须是消息名到消息对象的映射。",
    )
    return None
  }
  let entries : Map[String, Entry?] = Map([])
  for key in sorted_keys(items) {
    let normalized = key.to_lower()
    if entries.contains(normalized) {
      fail(key, "duplicate_key", "两条消息的键仅大小写不同。")
      entries[normalized] = None
    } else if !valid_name(key) || key.has_prefix("@@") {
      fail(
        key, "key_name", "该消息名称含无效字符或使用了浏览器保留的 @@ 前缀。",
      )
      entries[normalized] = None
    } else if items.get(key) is Some(value) {
      entries[normalized] = read_entry(key, value, side, issues)
    }
  }
  Some(entries)
}

///|
pub fn audit(source : String, translation : String) -> Report {
  let issues : Array[Finding] = []
  let base = catalog(source, "source", issues)
  let target_catalog = catalog(translation, "translation", issues)
  let mut checked = 0
  if base is Some(original) && target_catalog is Some(translated) {
    for id in sorted_keys(original) {
      guard original.get(id) is Some(Some(entry)) else { continue }
      let key = entry.name
      fn note(severity : String, code : String, detail : String) -> Unit {
        issues.push({ severity, side: "translation", key, code, detail, })
      }
      match translated.get(id) {
        None =>
          note(
            "warning", "fallback", "译文缺少此消息，浏览器将按语言回退规则查找。",
          )
        Some(None) => ()
        Some(Some(target)) => {
          checked += 1
          for slot in entry.slots {
            if !target.slots.contains(slot) {
              note(
                "error",
                "missing_slot",
                "译文漏用了调用方传入的参数 $\{slot}。",
              )
            }
          }
          for slot in target.slots {
            if !entry.slots.contains(slot) {
              note(
                "error",
                "extra_slot",
                "译文新增了原文没有使用的参数 $\{slot}。",
              )
            }
          }
          for name in sorted_keys(entry.named) {
            if entry.named.get(name) is Some(a) &&
              target.named.get(name) is Some(b) &&
              a != b {
              note(
                "error",
                "changed_binding",
                "同名占位符 $\{name}$ 绑定的参数已改变。",
              )
            }
          }
        }
      }
    }
    for id in sorted_keys(translated) {
      if !original.contains(id) && translated.get(id) is Some(Some(entry)) {
        issues.push({
          severity: "warning",
          side: "translation",
          key: entry.name,
          code: "translation_only",
          detail: "只有译文包含这条消息，请核对默认语言文件。",
        })
      }
    }
  }
  let errors = issues.iter().filter(fn(x) { x.severity == "error" }).count()
  { checked, errors, warnings: issues.length() - errors, findings: issues, }
}

///|
#export_name("audit_json")
pub fn audit_json(source : String, translation : String) -> String {
  @json.to_json(audit(source, translation)).stringify()
}
