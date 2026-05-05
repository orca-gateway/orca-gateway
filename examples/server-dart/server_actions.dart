import 'package:orca_engine/orca_engine.dart';

// ── In-memory data ─────────────────────────────────────────

final products = <String, Map<String, dynamic>>{
  'prod-1': {'name': 'Orca Gateway Pro License', 'price': 49.99, 'stock': 100},
  'prod-2': {'name': 'Wireless Headphones', 'price': 79.99, 'stock': 5},
  'prod-3': {'name': 'USB-C Hub', 'price': 29.99, 'stock': 0},
};

var cartItems = <Map<String, dynamic>>[];

// ── Server Actions ──────────────────────────────────────

final addToCartAction = ServerActionDefinition.create(ServerActionConfig(
  id: 'addToCart',
  schema: {
    'productId': const SchemaField(type: 'string'),
    'quantity': const SchemaField(type: 'number'),
  },
  execute: (ctx) async {
    final productId = ctx.actionParams['productId'] as String;
    final quantity = (ctx.actionParams['quantity'] as num).toInt();

    final product = products[productId];
    if (product == null) throw Exception('Product "$productId" not found');
    if ((product['stock'] as num) < quantity) {
      throw Exception('Not enough stock. Only ${product['stock']} available.');
    }

    product['stock'] = (product['stock'] as num) - quantity;

    final existing = cartItems.where((i) => i['productId'] == productId).firstOrNull;
    if (existing != null) {
      existing['quantity'] = (existing['quantity'] as num) + quantity;
    } else {
      cartItems.add({'productId': productId, 'quantity': quantity});
    }

    final cartCount = cartItems.fold<int>(0, (sum, i) => sum + (i['quantity'] as int));
    final lineTotal = ((product['price'] as num) * quantity).toStringAsFixed(2);

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 3));

    return [
      {'type': 'setState', 'scope': 'page', 'key': 'cartCount', 'value': cartCount},
      {'type': 'setState', 'scope': 'page', 'key': 'stock', 'value': product['stock']},
      {
        'type': 'addComponent',
        'parentId': 'cart-list',
        'keyPrefix': 'cart-$productId-${DateTime.now().millisecondsSinceEpoch}',
        'widget': Row(
          mainAxisAlignment: 'spaceBetween',
          children: [
            Text(data: '${quantity}x ${product['name']}', style: {'fontSize': 14}),
            Text(data: '\$$lineTotal', style: {'fontSize': 14, 'fontWeight': 'bold'}),
          ],
        ),
      },
      {'type': 'showSnackbar', 'message': 'Added ${quantity}x ${product['name']} to cart!'},
    ];
  },
));

final clearCartAction = ServerActionDefinition.create(ServerActionConfig(
  id: 'clearCart',
  execute: (ctx) async {
    for (final item in cartItems) {
      final product = products[item['productId'] as String];
      if (product != null) {
        product['stock'] = (product['stock'] as num) + (item['quantity'] as num);
      }
    }
    cartItems = [];
    return [
      {'type': 'setState', 'scope': 'page', 'key': 'cartCount', 'value': 0},
      {'type': 'showToast', 'message': 'Cart cleared!'},
      {
        'type': 'replaceComponent',
        'targetId': 'cart-list',
        'keyPrefix': 'cart',
        'widget': Column(crossAxisAlignment: 'start', children: [])..withKey('cart-list'),
      },
    ];
  },
));

// ── Page ────────────────────────────────────────────────

final shopPage = PageDefinition.create(PageDefinitionConfig(
  id: 'shop',
  title: 'Shop',
  state: (_) => [
    const StateDefinition(key: 'cartCount', scope: 'page', initial: 0),
    const StateDefinition(key: 'stock', scope: 'page', initial: 100),
    const StateDefinition(key: 'adding', scope: 'page', initial: false),
  ],
  getInfoData: (ctx) async => {'product': products['prod-1']},
  render: (ctx, info) => Scaffold(
    appBar: AppBar(
      title: Text(data: 'Server Actions Shop'),
      centerTitle: true,
    ),
    body: SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: 'start',
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: 'spaceBetween',
                  children: [
                    Text(data: 'Cart', style: {'fontSize': 20, 'fontWeight': 'bold'}),
                    Text(
                      data: V.transform(V.pageState('cartCount'), [
                        TV.toString$(),
                        TV.template('{{value}} items'),
                      ]),
                      style: {'fontSize': 16, 'color': '#2E7D32'},
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8),
            Column(crossAxisAlignment: 'start', children: [])..withKey('cart-list'),
            SizedBox(height: 24),

            Text(data: 'Featured Product', style: {'fontSize': 18, 'fontWeight': 'w600', 'color': '#333333'}),
            SizedBox(height: 8),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: 'start',
                  children: [
                    Text(data: V.info('product.name'), style: {'fontSize': 22, 'fontWeight': 'bold'}),
                    SizedBox(height: 8),
                    Text(
                      data: V.transform(V.info('product.price'), [TV.formatCurrency('USD')]),
                      style: {'fontSize': 18, 'color': '#2E7D32', 'fontWeight': 'w600'},
                    ),
                    SizedBox(height: 8),
                    Text(
                      data: V.transform(V.pageState('stock'), [
                        TV.toString$(),
                        TV.template('Stock: {{value}}'),
                      ]),
                      style: {'fontSize': 14, 'color': '#666666'},
                    ),
                    SizedBox(height: 16),
                    Divider(),
                    SizedBox(height: 16),
                    ElevatedButton(
                      child: Text(
                        data: V.when([
                          {
                            'when': Expr.eq(V.pageState('adding'), V.static$(true)),
                            'then': V.static$('Adding...'),
                          },
                        ], V.static$('Add to Cart')),
                      ),
                      actions: {
                        'onTap': lifecycle(
                          serverAction('addToCart', params: {
                            'productId': V.static$('prod-1'),
                            'quantity': V.static$(1),
                          }),
                          onLoading: setState('adding', V.static$(true)),
                          onError: showSnackbar('Failed to add to cart. Try again.'),
                          onComplete: setState('adding', V.static$(false)),
                        ),
                      },
                    ),
                    SizedBox(height: 8),
                    TextButton(
                      child: Text(data: 'Add 3 to Cart'),
                      actions: {
                        'onTap': serverAction('addToCart', params: {
                          'productId': V.static$('prod-1'),
                          'quantity': V.static$(3),
                        }),
                      },
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),
            Text(data: 'Cart Actions', style: {'fontSize': 18, 'fontWeight': 'w600', 'color': '#333333'}),
            SizedBox(height: 8),
            Row(children: [
              ElevatedButton(
                child: Text(data: 'Refresh Cart'),
                actions: {'onTap': serverAction('getCart')},
              ),
              SizedBox(width: 12),
              TextButton(
                child: Text(data: 'Clear Cart'),
                actions: {'onTap': serverAction('clearCart')},
              ),
            ]),
            SizedBox(height: 32),
          ],
        ),
      ),
    ),
  ),
));

// ── App ──────────────────────────────────────────────────

final mainFlow = Flow.create(FlowConfig(
  name: 'main',
  routes: [RouteDefinition(path: 'shop', page: shopPage)],
));

final serverActionsApp = App.create(AppConfig(
  id: 'server-actions',
  name: 'Server Actions Demo',
  flows: [mainFlow],
  actions: [addToCartAction, clearCartAction],
));
