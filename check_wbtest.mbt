///|
fn codes(result : Report) -> Array[String] {
  result.findings.map(fn(x) { x.code })
}

///|
test "name and message IDs are case-insensitive; source order is irrelevant" {
  let a =
    #|{"Receipt":{"message":"$name$: $2","placeholders":{"NAME":{"content":"$1"}}}}
  let b =
    #|{"rEcEiPt":{"message":"$2，由 $PERSON$ 支付","placeholders":{"person":{"content":"$1"}}}}
  let result = audit(a, b)
  assert_eq((result.checked, result.errors, result.warnings), (1, 0, 0))
}

///|
test "omission and addition of runtime arguments" {
  let a =
    #|{"total":{"message":"$1 + $2"}}
  let b =
    #|{"total":{"message":"$1 加 $3"}}
  assert_eq(codes(audit(a, b)), ["missing_slot", "extra_slot"])
}

///|
test "same named tokens cannot silently swap their bindings" {
  let a =
    #|{"pay":{"message":"$WHO$ : $SUM$","placeholders":{"who":{"content":"$1"},"sum":{"content":"$2"}}}}
  let b =
    #|{"pay":{"message":"$SUM$，付款人 $WHO$","placeholders":{"who":{"content":"$2"},"sum":{"content":"$1"}}}}
  assert_eq(codes(audit(a, b)), ["changed_binding", "changed_binding"])
}

///|
test "literal dollar runs and one-digit substitutions follow Chromium" {
  assert_eq(slots_used("$$1 $$$2 $$$$3 $4 $9 $0 $10 $4"), [1, 4, 9])
}

///|
test "literal and multi-slot placeholders are expanded" {
  let a =
    #|{"time":{"message":"$WHEN$ / $SITE$","placeholders":{"when":{"content":"$1–$2"},"site":{"content":"Example.com"}}}}
  let b =
    #|{"time":{"message":"Example.cn，时间 $2 至 $1"}}
  assert_eq(codes(audit(a, b)), [])
}

///|
test "argument can straddle a constant and the following literal" {
  let a =
    #|{"x":{"message":"$D$2","placeholders":{"D":{"content":"$"}}}}
  let b =
    #|{"x":{"message":"$2"}}
  assert_eq(codes(audit(a, b)), [])
}

///|
test "undefined reference keeps the malformed message out of comparison" {
  let a =
    #|{"x":{"message":"Hello $1"}}
  let b =
    #|{"x":{"message":"你好 $PERSON$"}}
  let result = audit(a, b)
  assert_eq((result.checked, codes(result)), (0, ["undefined_placeholder"]))
  assert_eq(result.findings[0].side, "translation")
}

///|
test "known name in source but not actually referenced creates no error" {
  let a =
    #|{"x":{"message":"A","placeholders":{"unused":{"content":"$3"}}}}
  let b =
    #|{"x":{"message":"甲"}}
  assert_eq(codes(audit(a, b)), [])
}

///|
test "partial translations are allowed via fallback" {
  let a =
    #|{"a":{"message":"one"}}
  let b =
    #|{"b":{"message":"二"}}
  let result = audit(a, b)
  assert_eq((result.errors, result.warnings), (0, 2))
  assert_eq(codes(result), ["fallback", "translation_only"])
}

///|
test "invalid or repeated JSON keys are rejected before comparing" {
  let repeat =
    #|{"a":{"message":"a"},"a":{"message":"b"}}
  for bad in [repeat, "{", "[]"] {
    let r = audit(bad, "{}")
    assert_eq((r.checked, r.errors, r.warnings), (0, 1, 0))
    assert_eq(r.findings[0].side, "source")
  }
}

///|
test "case-colliding catalog IDs are ambiguous" {
  let a =
    #|{"Profile":{"message":"one"},"pROFILE":{"message":"two"}}
  assert_eq(codes(audit(a, "{}")), ["duplicate_key"])
}

///|
test "message names and placeholder definitions are validated" {
  let b =
    #|{"@@reserved":{"message":"r"},"a":{"message":"x","placeholders":[]},"b":{"message":"x","placeholders":{"x":{}}},"c":{"message":3},"d":true,"e":{"message":"ok","placeholders":{"not-valid":{"content":"abc"}}},"f":{"message":"ok","placeholders":{"A":{"content":"$1"},"a":{"content":"$2"}}}}
  let observed = codes(audit("{}", b))
  let expected = [
    "key_name", "placeholders_type", "placeholder_content", "message_type", "entry_type",
    "placeholder_name", "duplicate_placeholder",
  ]
  observed.sort()
  expected.sort()
  assert_eq(observed, expected)
}

///|
test "UTF-8 BOM, emoji and repeated argument usage are accepted" {
  let a =
    #|{"hi":{"message":"🌙 $1 $1"}}
  let b =
    #|{"hi":{"message":"你好 🌕 $1"}}
  assert_eq(codes(audit("\u{feff}" + a, b)), [])
}

///|
test "both broken files report their own parsing failure" {
  let r = audit("[", "{")
  assert_eq((r.errors, r.warnings), (2, 0))
  assert_eq(r.findings.map(fn(x) { x.side }), ["source", "translation"])
}
