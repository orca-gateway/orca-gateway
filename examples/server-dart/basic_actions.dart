import 'package:orca_engine/orca_engine.dart';

// ── Helpers ───────────────────────────────────────────────

Widget sectionTitle(String title) {
  return Padding(
    padding: EdgeInsets.only(bottom: 8),
    child: Text(
      data: title,
      style: {'fontSize': 18, 'fontWeight': 'w600', 'color': '#333333'},
    ),
  );
}

// ── Home Page ─────────────────────────────────────────────

final homePage = PageDefinition.create(PageDefinitionConfig(
  id: 'home',
  title: 'Basic Actions',
  state: (_) => [
    const StateDefinition(key: 'count', scope: 'page', initial: 0),
    const StateDefinition(key: 'message', scope: 'page', initial: 'Hello, Orca Gateway!'),
  ],
  render: (ctx, info) => Scaffold(
    appBar: AppBar(
      title: Text(data: 'Basic Actions Demo'),
      centerTitle: true,
    ),
    body: SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: 'start',
          children: [
            // ── Counter Section ──
            sectionTitle('setState'),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(children: [
                  Text(
                    data: V.transform(V.pageState('count'), [TV.toString$()]),
                    style: {'fontSize': 48, 'fontWeight': 'bold'},
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: 'center',
                    children: [
                      ElevatedButton(
                        child: Text(data: '-'),
                        actions: {
                          'onTap': setState('count',
                              V.transform(V.pageState('count'), [TV.subtract(V.static$(1))])),
                        },
                      ),
                      SizedBox(width: 12),
                      ElevatedButton(
                        child: Text(data: '+'),
                        actions: {
                          'onTap': setState('count',
                              V.transform(V.pageState('count'), [TV.add(V.static$(1))])),
                        },
                      ),
                      SizedBox(width: 12),
                      OutlinedButton(
                        child: Text(data: 'Reset'),
                        actions: {
                          'onTap': sequential([
                            setState('count', V.static$(0)),
                            showSnackbar('Counter reset to 0'),
                          ]),
                        },
                      ),
                    ],
                  ),
                ]),
              ),
            ),

            SizedBox(height: 24),

            // ── Navigate Section ──
            sectionTitle('navigate / goBack'),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: 'start',
                  children: [
                    Text(
                      data: 'Push a new page onto the navigation stack.',
                      style: {'fontSize': 14, 'color': '#666666'},
                    ),
                    SizedBox(height: 12),
                    Column(
                      mainAxisSize: 'min',
                      crossAxisAlignment: 'start',
                      children: [
                        ElevatedButton(
                          child: Text(data: 'Go to About Page'),
                          actions: {'onTap': navigate('about')},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // ── Snackbar & Toast ──
            sectionTitle('showSnackbar / showToast'),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: 'start',
                  children: [
                    ElevatedButton(
                      child: Text(data: 'Show Snackbar'),
                      actions: {'onTap': showSnackbar('This is a snackbar message!', 3000)},
                    ),
                    SizedBox(height: 8),
                    ElevatedButton(
                      child: Text(data: 'Show Toast'),
                      actions: {'onTap': showToast('This is a toast!')},
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // ── Clipboard ──
            sectionTitle('copyToClipboard'),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: 'start',
                  children: [
                    Text(
                      data: V.pageState('message'),
                      style: {'fontSize': 16},
                    ),
                    SizedBox(height: 12),
                    ElevatedButton(
                      child: Text(data: 'Copy Message'),
                      actions: {
                        'onTap': sequential([
                          copyToClipboard(V.pageState('message')),
                          showToast('Copied to clipboard!'),
                        ]),
                      },
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // ── OpenUrl ──
            sectionTitle('openUrl'),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: ElevatedButton(
                  child: Text(data: 'Open Flutter Docs'),
                  actions: {'onTap': openUrl('https://flutter.dev')},
                ),
              ),
            ),

            SizedBox(height: 32),
          ],
        ),
      ),
    ),
  ),
));

// ── About Page ───────────────────────────────────────────

final aboutPage = PageDefinition.create(PageDefinitionConfig(
  id: 'about',
  title: 'About',
  render: (ctx, info) => Scaffold(
    appBar: AppBar(title: Text(data: 'About')),
    body: Center(
      child: Column(
        mainAxisAlignment: 'center',
        children: [
          Text(data: 'Orca Gateway Basic Actions', style: {'fontSize': 24, 'fontWeight': 'bold'}),
          SizedBox(height: 8),
          Text(data: 'Dart backend port.', style: {'fontSize': 16, 'color': '#666666'}),
          SizedBox(height: 24),
          ElevatedButton(
            child: Text(data: 'Go Back'),
            actions: {'onTap': goBack()},
          ),
        ],
      ),
    ),
  ),
));

// ── App ──────────────────────────────────────────────────

final mainFlow = Flow.create(FlowConfig(
  name: 'main',
  routes: [
    RouteDefinition(path: 'home', page: homePage),
    RouteDefinition(path: 'about', page: aboutPage),
  ],
));

final basicActionsApp = App.create(AppConfig(
  id: 'basic-actions',
  name: 'Basic Actions Demo',
  flows: [mainFlow],
));
