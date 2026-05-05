/// Orca Gateway SDUI Engine — Dart backend.
library orca_engine;

// Types
export 'src/types/node.dart';
export 'src/types/value.dart';
export 'src/types/action.dart';
export 'src/types/state.dart';
export 'src/types/context.dart';
export 'src/types/widget.dart';

// Core
export 'src/core/value_resolver.dart';
export 'src/core/json_tree_encoder.dart';
export 'src/core/capability_filter.dart';
export 'src/core/fallback_policy.dart';
export 'src/core/widget_registry.g.dart';
export 'src/core/page.dart';
export 'src/core/page_definition.dart';
export 'src/core/flow.dart';
export 'src/core/app.dart';
export 'src/core/server_action.dart';
export 'src/core/cache.dart';
export 'src/core/middleware.dart';
export 'src/core/monitor.dart';
export 'src/core/pipeline.dart';
export 'src/core/request_info.dart';
export 'src/core/engine.dart';

// Components (hand-written typed builders + helpers)
export 'src/components/layout.dart';
export 'src/components/primitive.dart';
export 'src/components/structure.dart';
export 'src/components/button.dart';
export 'src/components/input.dart';
export 'src/components/helpers.dart';
// Generated shells for all other widgets.
// `SubPage` is also declared hand-written in layout.dart — hide the duplicate here.
export 'src/components/widgets.g.dart' hide SubPage;
