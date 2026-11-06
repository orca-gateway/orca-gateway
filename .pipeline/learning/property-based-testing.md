---
topic: property-based-testing
status: new
first_seen: native-sdk/07 2026-11-06
seen: native-sdk/07
---
# Property-based testing

**Concept**  State a property (for all x: decode(encode(x)) == x) and let a generator throw hundreds
of random inputs at it; a failure is shrunk to the smallest input that still breaks it.

**Why here**  Decode then encode of any ComponentNode must be identity, add then subtract must give
the input back, split then join must round-trip; three SDKs, same properties, same seeds.

**When not**  Behaviour that is a lookup table (BoolExpr truth tables, fixtures); examples are clearer.

**Tiny example**  Swift, SwiftCheck: forAll { (n: Node) in decode(encode(n)) == n }
Kotlin, kotest: checkAll<Node> { decode(encode(it)) shouldBe it }

**Go deeper**  https://hypothesis.works/articles/what-is-property-based-testing/ · kotest docs
