// Epic 23b finding (render fixture 06_nested_state): a widget watching a
// dotted key such as `theme.color` must rebuild when the nested value
// changes, and must not rebuild for unrelated keys.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_gateway/orca_gateway.dart';

void main() {
  testWidgets('WatchBuilder rebuilds on nested changes behind a dotted watch', (
    tester,
  ) async {
    final store = ElmStore(
      initial: {
        'theme': {'color': 'red'},
        'count': 0,
      },
    );
    var builds = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: WatchBuilder(
          pageStore: store,
          watches: const {'theme.color'},
          builder: (context, state) {
            builds++;
            final color = lookupStatePath(state, 'theme.color');
            return Text('color=$color');
          },
        ),
      ),
    );
    expect(builds, 1);
    expect(find.text('color=red'), findsOneWidget);

    store.dispatch({'count': 1}); // unrelated key: no rebuild
    await tester.pump();
    expect(builds, 1);

    store.dispatch({
      'theme': {'color': 'blue'},
    });
    await tester.pump();
    expect(builds, 2);
    expect(find.text('color=blue'), findsOneWidget);
  });

  test('lookupStatePath walks maps and lists, flat key wins', () {
    final state = <String, dynamic>{
      'a.b': 'flat',
      'a': {
        'b': 'nested',
        'items': [
          {'name': 'first'},
          {'name': 'second'},
        ],
      },
    };
    expect(lookupStatePath(state, 'a.b'), 'flat');
    expect(lookupStatePath(state, 'a.items.1.name'), 'second');
    expect(lookupStatePath(state, 'a.items.9.name'), isNull);
    expect(lookupStatePath(state, 'a.missing.deeper'), isNull);
    expect(lookupStatePath(state, 'nope'), isNull);
  });
}
