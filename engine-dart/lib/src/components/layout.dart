import '../types/widget.dart';

// ── Column ──────────────────────────────────────────────────

class Column extends MultiChildLayout {
  @override
  String get type => 'Column';
  final Map<String, dynamic> _props;

  Column({
    required List<Widget> children,
    Map<String, dynamic>? actions,
    dynamic gap,
    dynamic mainAxisAlignment,
    dynamic crossAxisAlignment,
    dynamic mainAxisSize,
  }) : _props = {
          if (gap != null) 'gap': gap,
          if (mainAxisAlignment != null)
            'mainAxisAlignment': mainAxisAlignment,
          if (crossAxisAlignment != null)
            'crossAxisAlignment': crossAxisAlignment,
          if (mainAxisSize != null) 'mainAxisSize': mainAxisSize,
        } {
    this.children = children;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map.from(_props);
}

// ── Row ─────────────────────────────────────────────────────

class Row extends MultiChildLayout {
  @override
  String get type => 'Row';
  final Map<String, dynamic> _props;

  Row({
    required List<Widget> children,
    Map<String, dynamic>? actions,
    dynamic gap,
    dynamic mainAxisAlignment,
    dynamic crossAxisAlignment,
    dynamic mainAxisSize,
  }) : _props = {
          if (gap != null) 'gap': gap,
          if (mainAxisAlignment != null)
            'mainAxisAlignment': mainAxisAlignment,
          if (crossAxisAlignment != null)
            'crossAxisAlignment': crossAxisAlignment,
          if (mainAxisSize != null) 'mainAxisSize': mainAxisSize,
        } {
    this.children = children;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map.from(_props);
}

// ── Container ───────────────────────────────────────────────

class Container extends SingleChildLayout {
  @override
  String get type => 'Container';
  final Map<String, dynamic> _props;

  Container({
    Widget? child,
    Map<String, dynamic>? actions,
    dynamic padding,
    dynamic margin,
    dynamic decoration,
    dynamic width,
    dynamic height,
    dynamic alignment,
    dynamic color,
  }) : _props = {
          if (padding != null) 'padding': padding,
          if (margin != null) 'margin': margin,
          if (decoration != null) 'decoration': decoration,
          if (width != null) 'width': width,
          if (height != null) 'height': height,
          if (alignment != null) 'alignment': alignment,
          if (color != null) 'color': color,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map.from(_props);
}

// ── Padding ─────────────────────────────────────────────────

class Padding extends SingleChildLayout {
  @override
  String get type => 'Padding';
  final Map<String, dynamic> _props;

  Padding({Widget? child, Map<String, dynamic>? actions, required dynamic padding})
      : _props = {'padding': padding} {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map.from(_props);
}

// ── Center ──────────────────────────────────────────────────

class Center extends SingleChildLayout {
  @override
  String get type => 'Center';

  Center({Widget? child, Map<String, dynamic>? actions}) {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => {};
}

// ── SizedBox ────────────────────────────────────────────────

class SizedBox extends SingleChildLayout {
  @override
  String get type => 'SizedBox';
  final Map<String, dynamic> _props;

  SizedBox({Widget? child, dynamic width, dynamic height})
      : _props = {
          if (width != null) 'width': width,
          if (height != null) 'height': height,
        } {
    this.child = child;
  }

  @override
  Map<String, dynamic> getProps() => Map.from(_props);
}

// ── Stack ───────────────────────────────────────────────────

class Stack extends MultiChildLayout {
  @override
  String get type => 'Stack';
  final Map<String, dynamic> _props;

  Stack({
    required List<Widget> children,
    Map<String, dynamic>? actions,
    dynamic alignment,
    dynamic fit,
  }) : _props = {
          if (alignment != null) 'alignment': alignment,
          if (fit != null) 'fit': fit,
        } {
    this.children = children;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map.from(_props);
}

// ── Positioned ──────────────────────────────────────────────

class Positioned extends SingleChildLayout {
  @override
  String get type => 'Positioned';
  final Map<String, dynamic> _props;

  Positioned({
    Widget? child,
    dynamic top,
    dynamic right,
    dynamic bottom,
    dynamic left,
    dynamic width,
    dynamic height,
  }) : _props = {
          if (top != null) 'top': top,
          if (right != null) 'right': right,
          if (bottom != null) 'bottom': bottom,
          if (left != null) 'left': left,
          if (width != null) 'width': width,
          if (height != null) 'height': height,
        } {
    this.child = child;
  }

  @override
  Map<String, dynamic> getProps() => Map.from(_props);
}

// ── Expanded ────────────────────────────────────────────────

class Expanded extends SingleChildLayout {
  @override
  String get type => 'Expanded';
  final Map<String, dynamic> _props;

  Expanded({Widget? child, dynamic flex})
      : _props = {if (flex != null) 'flex': flex} {
    this.child = child;
  }

  @override
  Map<String, dynamic> getProps() => Map.from(_props);
}

// ── Flexible ────────────────────────────────────────────────

class Flexible extends SingleChildLayout {
  @override
  String get type => 'Flexible';
  final Map<String, dynamic> _props;

  Flexible({Widget? child, dynamic flex, dynamic fit})
      : _props = {
          if (flex != null) 'flex': flex,
          if (fit != null) 'fit': fit,
        } {
    this.child = child;
  }

  @override
  Map<String, dynamic> getProps() => Map.from(_props);
}

// ── ListView ────────────────────────────────────────────────

class ListView extends MultiChildLayout {
  @override
  String get type => 'ListView';
  final Map<String, dynamic> _props;

  ListView({
    required List<Widget> children,
    Map<String, dynamic>? actions,
    dynamic scrollDirection,
    dynamic padding,
    dynamic shrinkWrap,
    dynamic reverse,
    dynamic separator,
  }) : _props = {
          if (scrollDirection != null) 'scrollDirection': scrollDirection,
          if (padding != null) 'padding': padding,
          if (shrinkWrap != null) 'shrinkWrap': shrinkWrap,
          if (reverse != null) 'reverse': reverse,
          if (separator != null) 'separator': separator,
        } {
    this.children = children;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map.from(_props);
}

// ── SingleChildScrollView ───────────────────────────────────

class SingleChildScrollView extends SingleChildLayout {
  @override
  String get type => 'SingleChildScrollView';
  final Map<String, dynamic> _props;

  SingleChildScrollView({
    Widget? child,
    Map<String, dynamic>? actions,
    dynamic scrollDirection,
    dynamic padding,
  }) : _props = {
          if (scrollDirection != null) 'scrollDirection': scrollDirection,
          if (padding != null) 'padding': padding,
        } {
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map.from(_props);
}

// ── SubPage ────────────────────────────────────────────────

/// Embeds a page inside another page. The SDK fetches the sub-page content
/// at render time and renders it in place. Sub-page component IDs are
/// prefixed with `{key}:` to prevent collisions with the parent page.
///
/// The optional child widget is used as a loading placeholder while the
/// sub-page content is being fetched.
///
/// `key` is **required** — it is used as the ID namespace prefix for
/// embedded components and as the target for `updateSubPage` actions.
class SubPage extends SingleChildLayout {
  @override
  String get type => 'SubPage';
  final Map<String, dynamic> _props;

  SubPage({
    required String key,
    required dynamic pageId,
    Map<String, dynamic>? params,
    Widget? child,
    Map<String, dynamic>? actions,
  }) : _props = {
          'pageId': pageId,
          if (params != null) 'params': params,
        } {
    this.key = key;
    this.child = child;
    this.actions = actions;
  }

  @override
  Map<String, dynamic> getProps() => Map.from(_props);
}

// ── Opacity ─────────────────────────────────────────────────

class Opacity extends SingleChildLayout {
  @override
  String get type => 'Opacity';
  final Map<String, dynamic> _props;

  Opacity({Widget? child, required dynamic opacity})
      : _props = {'opacity': opacity} {
    this.child = child;
  }

  @override
  Map<String, dynamic> getProps() => Map.from(_props);
}
