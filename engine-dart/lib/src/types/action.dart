/// Action types are represented as Map<String, dynamic> to match wire format.
/// Helper constructors produce these maps directly.

typedef ActionMap = Map<String, dynamic>;

// ── Action Helper Constructors ──────────────────────────────

Map<String, dynamic> navigate(
  dynamic route, {
  Map<String, dynamic>? params,
  bool? replace,
}) {
  final a = <String, dynamic>{'type': 'navigate', 'route': route};
  if (params != null) a['params'] = params;
  if (replace != null) a['replace'] = replace;
  return a;
}

Map<String, dynamic> goBack() => {'type': 'goBack'};

Map<String, dynamic> switchTab(String tabId) =>
    {'type': 'switchTab', 'tabId': tabId};

Map<String, dynamic> openDrawer() => {'type': 'openDrawer'};

Map<String, dynamic> openDialog(String dialogId, [double? heightFactor]) {
  final a = <String, dynamic>{'type': 'openDialog', 'dialogId': dialogId};
  if (heightFactor != null) a['heightFactor'] = heightFactor;
  return a;
}

Map<String, dynamic> closeDialog() => {'type': 'closeDialog'};

Map<String, dynamic> setState(
  String key,
  dynamic value, {
  String scope = 'page',
}) =>
    {'type': 'setState', 'scope': scope, 'key': key, 'value': value};

Map<String, dynamic> clearState(String key, {String scope = 'page'}) =>
    {'type': 'clearState', 'scope': scope, 'key': key};

Map<String, dynamic> serverAction(
  String id, {
  Map<String, dynamic>? params,
}) {
  final a = <String, dynamic>{'type': 'serverAction', 'id': id};
  if (params != null) a['params'] = params;
  return a;
}

Map<String, dynamic> copyToClipboard(dynamic text) =>
    {'type': 'copyToClipboard', 'text': text};

Map<String, dynamic> share(String title, dynamic message, [String? url]) {
  final a = <String, dynamic>{'type': 'share', 'title': title, 'message': message};
  if (url != null) a['url'] = url;
  return a;
}

Map<String, dynamic> openUrl(dynamic url) => {'type': 'openUrl', 'url': url};

Map<String, dynamic> showSnackbar(dynamic message, [int? duration]) {
  final a = <String, dynamic>{'type': 'showSnackbar', 'message': message};
  if (duration != null) a['duration'] = duration;
  return a;
}

Map<String, dynamic> showToast(dynamic message) =>
    {'type': 'showToast', 'message': message};

Map<String, dynamic> sequential(List<Map<String, dynamic>> actions) =>
    {'type': 'actionGroup', 'mode': 'sequential', 'actions': actions};

Map<String, dynamic> parallel(List<Map<String, dynamic>> actions) =>
    {'type': 'actionGroup', 'mode': 'parallel', 'actions': actions};

Map<String, dynamic> when(
  List<Map<String, dynamic>> branches, [
  Map<String, dynamic>? elseAction,
]) {
  final a = <String, dynamic>{
    'type': 'conditionalAction',
    'branches': branches,
  };
  if (elseAction != null) a['else'] = elseAction;
  return a;
}

Map<String, dynamic> animateForward(String animationId) =>
    {'type': 'animateForward', 'animationId': animationId};

Map<String, dynamic> animateReverse(String animationId) =>
    {'type': 'animateReverse', 'animationId': animationId};

Map<String, dynamic> lifecycle(
  Map<String, dynamic> action, {
  dynamic onLoading,
  dynamic onSuccess,
  dynamic onError,
  dynamic onComplete,
}) {
  final a = <String, dynamic>{'type': 'lifecycle', 'action': action};
  if (onLoading != null) a['onLoading'] = onLoading;
  if (onSuccess != null) a['onSuccess'] = onSuccess;
  if (onError != null) a['onError'] = onError;
  if (onComplete != null) a['onComplete'] = onComplete;
  return a;
}

Map<String, dynamic> refetchPage() => {'type': 'refetchPage'};

Map<String, dynamic> updateSubPage(
  dynamic subPageId,
  dynamic pageId, {
  dynamic mode = 'replace',
  Map<String, dynamic>? params,
}) {
  final a = <String, dynamic>{
    'type': 'updateSubPage',
    'subPageId': subPageId,
    'pageId': pageId,
    'mode': mode,
  };
  if (params != null) a['params'] = params;
  return a;
}

Map<String, dynamic> custom(String type, [Map<String, dynamic>? params]) =>
    {'type': type, ...?params};

/// Action triggers.
const actionTriggers = [
  'onTap', 'onLongPress', 'onDoubleTap', 'onChange',
  'onScrollBegin', 'onScrolling', 'onScrollEnd', 'onVisible', 'onInit',
  'onBackground', 'onForeground', 'onSuccess', 'onError', 'onComplete',
];
