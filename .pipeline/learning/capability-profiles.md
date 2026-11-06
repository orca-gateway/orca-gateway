---
topic: capability-profiles
status: new
first_seen: native-sdk/02 2026-11-05
seen: native-sdk/02
---
# Capability profiles

**Concept**  One spec, several profiles: a core every implementation must support, plus extensions an
implementation may claim. Clients advertise what they claim; servers emit only that.

**Why here**  Three SDKs will not all render 92 Flutter widgets; core/material/flutter-only tells
backend authors what is safe everywhere and lets the caps vector degrade the rest predictably.

**When not**  One client, or a catalog small enough that every implementation can do all of it.

**Tiny example**  Vulkan Profiles, Bluetooth profiles, OpenGL core vs compatibility profile.
widget-registry.json: { "type": "SliverList", "tier": "flutter-only" }

**Go deeper**  https://github.com/KhronosGroup/Vulkan-Profiles · engine/src/core/json-tree-encoder.ts
