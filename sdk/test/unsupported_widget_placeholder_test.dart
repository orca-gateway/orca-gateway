// Slice A coverage for Epic 38 tasks 38.1 – 38.3.
//
// These tests pin the three pieces that don't need a running web VM:
//
//   1. ComponentRegistry carries WidgetWebMetadata and web-stub builders
//      alongside the main builder map, and its helper predicates
//      (isUnsupportedOnWeb, getWebStub, getMetadata) behave correctly for
//      every combination of present/absent metadata.
//
//   2. The UnsupportedWidgetPlaceholder builder renders its five documented
//      props (widgetType, displayName, iconName, docsUrl, reason) into a
//      visible card — proving the builder is wired into registerDefaults
//      and that the widget survives a round trip through ComponentRenderer
//      when emitted explicitly.
//
//   3. mergePlugins forwards per-widget metadata and webStubs from each
//      OrcaPlugin into the merged registry, so a plugin author only has to
//      declare the fallback chain once and it lights up everywhere
//      OrcaApp/OrcaPage is used.
//
// The kIsWeb branch in component_renderer.dart (real-web substitution of a
// web-unsupported widget with either a stub or the placeholder) is not
// exercised here — kIsWeb is a compile-time constant that only flips true
// under `flutter test -d chrome`. That branch is covered by the Flutter Web
// preview integration tests in cloud/apps/flutter-web-preview (Epic 37) and
// will gain direct coverage when Slice D bundles the preview build pipeline.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_gateway/orca_gateway.dart';

void main() {
  group('ComponentRegistry — Epic 38 metadata + web stubs', () {
    late ComponentRegistry registry;

    setUp(() {
      registry = ComponentRegistry();
    });

    test('isUnsupportedOnWeb is false when no metadata registered', () {
      registry.register('Text', (ctx) => const SizedBox());
      expect(registry.isUnsupportedOnWeb('Text'), isFalse);
      expect(registry.getMetadata('Text'), isNull);
    });

    test('isUnsupportedOnWeb honors the metadata flag', () {
      registry.register(
        'OrcaGoogleMap',
        (ctx) => const SizedBox(),
        metadata: const WidgetWebMetadata(
          isSupportedOnWeb: false,
          displayName: 'Google Maps',
          iconName: 'map',
          docsUrl: 'https://docs.example.com/maps',
        ),
      );
      expect(registry.isUnsupportedOnWeb('OrcaGoogleMap'), isTrue);

      final meta = registry.getMetadata('OrcaGoogleMap');
      expect(meta, isNotNull);
      expect(meta!.displayName, 'Google Maps');
      expect(meta.iconName, 'map');
      expect(meta.docsUrl, 'https://docs.example.com/maps');
    });

    test('metadata defaults to supported-on-web when not explicit', () {
      registry.register(
        'SomeWidget',
        (ctx) => const SizedBox(),
        metadata: const WidgetWebMetadata(displayName: 'Some Widget'),
      );
      expect(registry.isUnsupportedOnWeb('SomeWidget'), isFalse);
      expect(registry.getMetadata('SomeWidget')!.displayName, 'Some Widget');
    });

    test('registerWebStub stores a separate builder independent of register', () {
      Widget realBuilder(OrcaComponentContext ctx) =>
          const Text('real', textDirection: TextDirection.ltr);
      Widget stubBuilder(OrcaComponentContext ctx) =>
          const Text('stub', textDirection: TextDirection.ltr);

      registry.register(
        'OrcaGoogleMap',
        realBuilder,
        metadata: const WidgetWebMetadata(isSupportedOnWeb: false),
      );
      registry.registerWebStub('OrcaGoogleMap', stubBuilder);

      expect(registry.get('OrcaGoogleMap'), isNotNull);
      expect(registry.getWebStub('OrcaGoogleMap'), isNotNull);
      // The two map entries must not clobber each other.
      expect(registry.get('OrcaGoogleMap'), isNot(equals(stubBuilder)));
      expect(registry.getWebStub('OrcaGoogleMap'), equals(stubBuilder));
    });

    test('setMetadata lets late-bound plugins attach web metadata', () {
      registry.register('Widget', (ctx) => const SizedBox());
      expect(registry.isUnsupportedOnWeb('Widget'), isFalse);

      registry.setMetadata(
        'Widget',
        const WidgetWebMetadata(isSupportedOnWeb: false),
      );
      expect(registry.isUnsupportedOnWeb('Widget'), isTrue);
    });
  });

  group('UnsupportedWidgetPlaceholder builder', () {
    testWidgets('renders displayName, reason, and a "Learn more" link',
        (tester) async {
      final registry = ComponentRegistry()..registerDefaults();
      final renderer = ComponentRenderer(registry: registry);

      final node = ComponentNode(
        id: 'root',
        type: 'UnsupportedWidgetPlaceholder',
        kind: 'primitive',
        childMode: 'none',
        props: const <String, dynamic>{
          'widgetType': 'OrcaGoogleMap',
          'displayName': 'Google Maps',
          'iconName': 'map',
          'docsUrl': 'https://docs.example.com/maps',
          'reason': 'Maps render in the compiled mobile app.',
        },
        children: const <String>[],
        watches: const <String>[],
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: renderer.render([node]),
        ),
      );

      expect(find.text('Google Maps'), findsOneWidget);
      expect(
        find.text('Maps render in the compiled mobile app.'),
        findsOneWidget,
      );
      expect(find.text('Learn more'), findsOneWidget);
    });

    testWidgets('falls back to widgetType when displayName is absent',
        (tester) async {
      final registry = ComponentRegistry()..registerDefaults();
      final renderer = ComponentRenderer(registry: registry);

      final node = ComponentNode(
        id: 'root',
        type: 'UnsupportedWidgetPlaceholder',
        kind: 'primitive',
        childMode: 'none',
        props: const <String, dynamic>{'widgetType': 'CustomWidget'},
        children: const <String>[],
        watches: const <String>[],
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: renderer.render([node]),
        ),
      );

      expect(find.text('CustomWidget'), findsOneWidget);
      // With no docsUrl, the "Learn more" affordance must not appear.
      expect(find.text('Learn more'), findsNothing);
    });
  });

  group('mergePlugins — metadata + webStubs propagation', () {
    test('forwards widgetMetadata and webStubs into the merged registry', () {
      final plugin = OrcaPlugin(
        name: 'test_plugin',
        widgets: {
          'OrcaGoogleMap': (ctx) => const SizedBox(),
        },
        widgetMetadata: const {
          'OrcaGoogleMap': WidgetWebMetadata(
            isSupportedOnWeb: false,
            displayName: 'Google Maps',
          ),
        },
        webStubs: {
          'OrcaGoogleMap': (ctx) =>
              const Text('stub', textDirection: TextDirection.ltr),
        },
      );

      final result = mergePlugins(
        registry: ComponentRegistry()..registerDefaults(),
        plugins: [plugin],
      );

      expect(result.registry.has('OrcaGoogleMap'), isTrue);
      expect(result.registry.isUnsupportedOnWeb('OrcaGoogleMap'), isTrue);
      expect(result.registry.getMetadata('OrcaGoogleMap')!.displayName,
          'Google Maps');
      expect(result.registry.getWebStub('OrcaGoogleMap'), isNotNull);
    });

    test('plugins without metadata keep the default supported-on-web behavior',
        () {
      final plugin = OrcaPlugin(
        name: 'plain_plugin',
        widgets: {
          'SimpleCustomWidget': (ctx) => const SizedBox(),
        },
      );

      final result = mergePlugins(
        registry: ComponentRegistry()..registerDefaults(),
        plugins: [plugin],
      );

      expect(result.registry.has('SimpleCustomWidget'), isTrue);
      expect(result.registry.isUnsupportedOnWeb('SimpleCustomWidget'), isFalse);
      expect(result.registry.getWebStub('SimpleCustomWidget'), isNull);
    });
  });
}
