import 'package:orca_engine/orca_engine.dart';

// ── Home Page ─────────────────────────────────────────────

final homePage = PageDefinition.create(PageDefinitionConfig(
  id: 'home',
  title: 'Counter',
  state: (_) => [
    const StateDefinition(key: 'count', scope: 'page', initial: 0),
  ],
  render: (ctx, info) => Scaffold(
    appBar: AppBar(
      title: Text(data: 'Counter Example'),
      centerTitle: true,
    ),
    body: Center(
      child: Column(
        mainAxisAlignment: 'center',
        children: [
          Text(
            data: V.transform(V.pageState('count'), [TV.toString$()]),
            style: {'fontSize': 48, 'fontWeight': 'bold'},
          ),
          SizedBox(height: 24),
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
              SizedBox(width: 16),
              ElevatedButton(
                child: Text(data: '+'),
                actions: {
                  'onTap': setState('count',
                      V.transform(V.pageState('count'), [TV.add(V.static$(1))])),
                },
              ),
            ],
          ),
          SizedBox(height: 16),
          ElevatedButton(
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
    ),
  ),
));

// ── App ──────────────────────────────────────────────────

final homeFlow = Flow.create(FlowConfig(
  name: 'home',
  routes: [RouteDefinition(path: 'home', page: homePage)],
));

final counterApp = App.create(AppConfig(
  id: 'counter',
  name: 'Counter',
  flows: [homeFlow],
));
