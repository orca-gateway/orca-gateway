import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:orca_gateway/orca_gateway.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:orca_google_map/orca_google_map.dart';

void main() {
  if (kDebugMode) {
    OrcaDebug.init(
      const OrcaDebugConfig(
        enabled: true,
        showOverlay: true,
        logTimings: true,
        captureStateChanges: true,
        captureNetworkRequests: true,
        appName: 'Orca Gateway Examples',
      ),
    );
  }
  runApp(const OrcaGatewayExamples());
}

class OrcaGatewayExamples extends StatelessWidget {
  const OrcaGatewayExamples({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Orca Gateway Examples',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const ExampleSelector(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class _Example {
  final String title;
  final String subtitle;
  final IconData icon;
  final String appId;
  final String path;
  final bool useOrcaApp;

  const _Example({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.appId,
    required this.path,
    this.useOrcaApp = false,
  });
}

const _examples = [
  _Example(
    title: 'Counter',
    subtitle: 'Basic state management with increment/decrement',
    icon: Icons.add_circle_outline,
    appId: 'counter',
    path: 'home',
  ),
  _Example(
    title: 'Basic Actions',
    subtitle: 'Navigation, snackbars, transforms, conditionals',
    icon: Icons.touch_app,
    appId: 'basic-actions',
    path: 'home',
  ),
  _Example(
    title: 'Server Actions',
    subtitle: 'Add-to-cart with server-side logic and component mutations',
    icon: Icons.cloud_sync,
    appId: 'server-actions',
    path: 'shop',
  ),
  _Example(
    title: 'E-Commerce (Navigation)',
    subtitle: 'Tabs, drawer, stack navigation, deeplinks',
    icon: Icons.shopping_bag,
    appId: 'ecommerce',
    path: '',
    useOrcaApp: true,
  ),
  _Example(
    title: 'Static Flows (Offline)',
    subtitle: 'Cached static pages, dynamic pages, version check',
    icon: Icons.offline_bolt,
    appId: 'static-flows',
    path: '',
    useOrcaApp: true,
  ),
  _Example(
    title: 'Animations (Auto-Play)',
    subtitle: 'Tween, TweenSequence, color & size animations',
    icon: Icons.animation,
    appId: 'animations',
    path: 'auto-play',
  ),
  _Example(
    title: 'Animations (Controlled)',
    subtitle: 'AnimateForward / AnimateReverse via button actions',
    icon: Icons.play_circle_outline,
    appId: 'animations',
    path: 'controlled',
  ),
  _Example(
    title: 'Custom Extensions',
    subtitle: 'Custom actions (haptic, confetti, rate) & custom components',
    icon: Icons.extension,
    appId: 'custom',
    path: 'home',
    useOrcaApp: false,
  ),
  _Example(
    title: 'Capability Demo',
    subtitle: 'FallbackPrompt at info / warn / blocking severities (Epic 25b)',
    icon: Icons.shield_outlined,
    appId: 'capability-demo',
    // Opens a sub-selector listing the three severity pages so users can
    // compare them side by side on-device. See _CapabilityDemoSelector.
    path: '__sub__',
    useOrcaApp: false,
  ),
];

// ── Capability Demo sub-selector (Epic 25b foundation slice) ─────────
//
// The capability-demo app has three routes (home/upgrade/blocked), each
// showcasing a different FallbackPrompt severity. Rather than collapse them
// into one static path, the sub-selector lets the user open any of the
// three from a nested menu — this is the whole pedagogical value of the
// demo (compare info vs warn vs blocking).

const _capabilityDemoRoutes = <_Example>[
  _Example(
    title: 'Info severity',
    subtitle: 'Inline FallbackPrompt as non-blocking announcement',
    icon: Icons.info_outline,
    appId: 'capability-demo',
    path: 'home',
  ),
  _Example(
    title: 'Warn severity',
    subtitle: 'Feature-gated soft warning; user can still continue',
    icon: Icons.warning_amber_outlined,
    appId: 'capability-demo',
    path: 'upgrade',
  ),
  _Example(
    title: 'Blocking severity',
    subtitle: 'Full-screen hard block; user must update',
    icon: Icons.block,
    appId: 'capability-demo',
    path: 'blocked',
  ),
];

class _CapabilityDemoSelector extends StatelessWidget {
  const _CapabilityDemoSelector();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capability Demo'),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _capabilityDemoRoutes.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final route = _capabilityDemoRoutes[index];
          return Card(
            child: ListTile(
              leading: Icon(route.icon, size: 32),
              title: Text(
                route.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(route.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _ExamplePage(example: route),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class ExampleSelector extends StatelessWidget {
  const ExampleSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orca Gateway Examples'),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _examples.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final example = _examples[index];
          return Card(
            child: ListTile(
              leading: Icon(example.icon, size: 32),
              title: Text(
                example.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(example.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                if (example.path == '__sub__' &&
                    example.appId == 'capability-demo') {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const _CapabilityDemoSelector(),
                    ),
                  );
                } else if (example.useOrcaApp) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _OrcaAppPage(appId: example.appId),
                    ),
                  );
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _ExamplePage(example: example),
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class _ExamplePage extends StatelessWidget {
  final _Example example;
  const _ExamplePage({required this.example});

  @override
  Widget build(BuildContext context) {
    final client = OrcaClient(
      baseUrl: 'http://localhost:8080',
      apiKey: 'demo-key',
    );
    final stateManager = StateManager();

    // Custom extensions for the "custom" example — using OrcaPlugin
    if (example.appId == 'custom') {
      return OrcaPage(
        client: client,
        appId: example.appId,
        path: example.path,
        stateManager: stateManager,
        plugins: [
          _BadgePlugin(context),
          _DeviceActionsPlugin(context),
          GoogleMapPlugin(),
        ],
      );
    }

    return OrcaPage(
      client: client,
      appId: example.appId,
      path: example.path,
      stateManager: stateManager,
    );
  }
}

class _OrcaAppPage extends StatelessWidget {
  final String appId;
  const _OrcaAppPage({required this.appId});

  @override
  Widget build(BuildContext context) {
    final client = OrcaClient(
      baseUrl: 'http://localhost:8080',
      apiKey: 'demo-key',
    );

    if (appId == 'static-flows') {
      return OrcaApp(
        client: client,
        appId: appId,
        title: 'Static Flows Demo',
        enableOffline: true,
        enableSessionTracking: true,
        debugConfig: const OrcaDebugConfig(
          enabled: true,
          logTimings: true,
          captureStateChanges: true,
          captureNetworkRequests: true,
          appName: 'Static Flows Demo',
        ),
        splashWidget: Scaffold(
          body: const Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Checking version...'),
                ],
              ),
            ),
          ),
        ),
        forceUpdateBuilder: () => const Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.system_update, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'Update Required',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('Please update the app to continue.'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return OrcaApp(
      client: client,
      appId: appId,
      materialApp: OrcaMaterialAppConfig(
        title: 'Orca Gateway Demo',
        theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
        debugShowCheckedModeBanner: false,
      ),
      enableSessionTracking: true,
    );
  }
}

// ── Plugins ─────────────────────────────────────────────

/// Plugin that bundles the custom ColoredBadge widget.
class _BadgePlugin extends OrcaPlugin {
  _BadgePlugin(BuildContext context)
    : super(
        name: 'BadgePlugin',
        widgets: {
          'ColoredBadge': (ctx) {
            final label = ctx.prop<String>('label') ?? '';
            final colorHex = ctx.prop<String>('color') ?? '#888888';
            final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
            return GestureDetector(
              onTap: () => ctx.fireAction('onTap'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            );
          },
        },
      );
}

/// Plugin that bundles device-capability custom actions:
/// haptic feedback, confetti, and app rating.
class _DeviceActionsPlugin extends OrcaPlugin {
  _DeviceActionsPlugin(BuildContext context)
    : super(
        name: 'DeviceActionsPlugin',
        widgets: {},
        actions: {
          'hapticFeedback': (action, executor) async {
            final intensity = action['intensity'] as String? ?? 'medium';
            switch (intensity) {
              case 'light':
                await HapticFeedback.lightImpact();
              case 'heavy':
                await HapticFeedback.heavyImpact();
              default:
                await HapticFeedback.mediumImpact();
            }
          },
          'showConfetti': (action, executor) async {
            final colors = (action['colors'] as List? ?? []);
            Confetti.launch(
              executor.context ?? context,
              options: ConfettiOptions(
                particleCount: 100,
                spread: 70,
                y: 0.6,
                colors: colors.isEmpty
                    ? defaultColors
                    : colors
                          .map(
                            (c) => Color(
                              int.parse(
                                (c as String).replaceFirst('#', '0xFF'),
                              ),
                            ),
                          )
                          .toList(),
              ),
            );
          },
          'rateApp': (action, executor) async {
            final appStoreId = action['appStoreId'] as String? ?? '';
            await executor.execute({
              'type': 'showToast',
              'message': 'Opening rating for $appStoreId...',
            });
          },
          'processPayment': (action, executor) async {
            // Simulated payment processing — in a real app, use Stripe/RevenueCat
            final amount = action['amount'];
            await Future<void>.delayed(const Duration(seconds: 2));
            await executor.execute({
              'type': 'showToast',
              'message': 'Payment of \$$amount processed!',
            });
          },
        },
      );
}
