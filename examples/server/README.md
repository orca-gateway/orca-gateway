# Example Servers

Working server implementations demonstrating Orca Gateway engine features.

## Running

```bash
# Start all examples (server + Flutter app)
task example:dev

# Or just the server
task example:dev:server
```

The server runs on `http://localhost:8080` by default.

## Examples

| File                  | Description                                                  |
| --------------------- | ------------------------------------------------------------ |
| `counter.ts`          | Basic counter with page state and increment/decrement actions |
| `ecommerce.ts`        | Product listing with cart, checkout flow, and server actions   |
| `animations.ts`       | Tween animations, sequences, and animated transitions         |
| `basic-actions.ts`    | Navigate, SetState, CopyToClipboard, OpenUrl, ShowSnackbar    |
| `server-actions.ts`   | Server-side action handlers with request round-trips          |
| `static-flows.ts`     | Offline-capable static flow definitions with versioning       |
| `capability-demo.ts`  | Capability negotiation and safe degradation fallbacks         |
| `custom.ts`           | Custom widget types and custom action handlers                |
| `orca_google_map.ts`  | Google Maps integration via the map plugin                    |
| `index.ts`            | Entry point — registers all examples into a single engine     |
