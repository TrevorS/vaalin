# MockLichServer - Integration Testing Utility

## Overview

`MockLichServer` is an in-process TCP server that simulates Lich 5's detachable client XML protocol for automated integration testing. It allows testing the complete Vaalin data flow (network → parser → UI) without requiring a real Lich/GemStone IV server.

## Key Features

- **Actor-based design** - Thread-safe for concurrent test execution
- **Random port assignment** - Avoids conflicts in parallel test runs
- **Realistic XML scenarios** - Predefined game situations (room descriptions, combat, vitals, etc.)
- **Multiple connections** - Supports testing reconnection and multi-client scenarios
- **Clean lifecycle** - Start/stop with proper resource cleanup
- **Zero dependencies** - Pure Network.framework implementation

## Quick Start

```swift
import Testing
@testable import VaalinNetwork

@Test func test_basicConnection() async throws {
    // 1. Create and start server
    let server = MockLichServer()
    try await server.start()

    // 2. Get assigned port
    let port = await server.port

    // 3. Connect your client
    let connection = LichConnection()
    try await connection.connect(host: "127.0.0.1", port: port)

    // 4. Send test scenarios
    await server.sendScenario(.initialConnection)
    await server.sendScenario(.roomDescription)

    // 5. Clean up
    await connection.disconnect()
    await server.stop()
}
```

## Architecture

```
                 ┌─────────────────┐
                 │  MockLichServer │
                 │   (Actor)       │
                 └────────┬────────┘
                          │ TCP (localhost:random)
                          │
              ┌───────────┴───────────┐
              │                       │
       ┌──────▼──────┐        ┌──────▼──────┐
       │LichConnection│        │LichConnection│
       │  (Client 1)  │        │  (Client 2)  │
       └──────┬───────┘        └──────┬───────┘
              │                       │
              ▼                       ▼
      XMLStreamParser         XMLStreamParser
              │                       │
              ▼                       ▼
          [GameTag]              [GameTag]
```

## API Reference

### Lifecycle Methods

#### `start() async throws`
Starts the server on a random available port. The assigned port is stored in the `port` property.

**Throws**: `MockLichServerError.failedToStart` if server cannot bind to a port.

```swift
let server = MockLichServer()
try await server.start()
let port = await server.port // e.g., 54321
```

#### `stop() async`
Stops the server and closes all client connections. Resets the port to 0.

```swift
await server.stop()
```

### XML Broadcasting

#### `sendXML(_ xml: String) async`
Sends raw XML to all connected clients. Use for custom test scenarios.

```swift
await server.sendXML("<prompt>&gt;</prompt>")
await server.sendXML("<left>Empty</left><right>Empty</right>")
```

#### `sendScenario(_ scenario: Scenario) async`
Sends a predefined game scenario to all connected clients.

```swift
await server.sendScenario(.initialConnection)
await server.sendScenario(.combatSequence)
```

### State Inspection

#### `port: UInt16`
The assigned port number. `0` until server starts, then a random high port (e.g., 54321).

```swift
let port = await server.port
```

#### `connectionCount: Int`
Number of active client connections. Useful for test assertions.

```swift
let count = await server.connectionCount
#expect(count == 2)
```

## Predefined Scenarios

### `.initialConnection`
Game mode setup and stream window initialization.

**Contains**:
- `<mode id="GAME"/>`
- `<settingsInfo>` with dimensions
- Multiple `<streamWindow>` declarations
- `<component>` definitions
- Initial `<prompt>`

**Use case**: Test connection handshake and initial state setup.

### `.roomDescription`
Room description with exits and objects.

**Contains**:
- `<pushStream id="room">` ... `<popStream/>`
- Room text (e.g., "[Wehnimer's Landing, Town Square]")
- Exits list
- `<compass>` with directions
- `<nav/>` indicator
- `<prompt>`

**Use case**: Test stream management and room parsing.

### `.combatSequence`
Combat spam with damage calculations and vitals updates.

**Contains**:
- `<pushStream id="combat">` ... `<popStream/>`
- Combat messages (swings, hits, damage)
- `<progressBar id="health">` update
- `<progressBar id="stamina">` update
- `<prompt>`

**Use case**: Test vitals updates and combat stream filtering.

### `.streamSequence`
Multiple stream changes (thoughts, speech).

**Contains**:
- `<pushStream id="thoughts">` ... `<popStream/>`
- `<pushStream id="speech">` ... `<popStream/>`
- Stream-specific content

**Use case**: Test stream stack management and filtering.

### `.itemLoot`
Items with `exist` and `noun` attributes for highlighting.

**Contains**:
- Multiple `<a exist="..." noun="...">` tags
- Items: gem, coins, box
- `<prompt>`

**Use case**: Test item categorization and highlighting.

### `.handsUpdate`
Equipment changes in hands.

**Contains**:
- `<left exist="..." noun="shield">a steel shield</left>`
- `<right exist="..." noun="sword">a steel broadsword</right>`
- `<prompt>`

**Use case**: Test hands panel updates.

### `.vitalsUpdate`
All vitals progress bars.

**Contains**:
- `<progressBar id="health">`
- `<progressBar id="mana">`
- `<progressBar id="stamina">`
- `<progressBar id="spirit">`
- `<progressBar id="concentration">`
- `<progressBar id="encumbrance">`
- `<prompt>`

**Use case**: Test vitals panel updates.

### `.promptSequence`
Multiple prompts in sequence.

**Contains**:
- Three consecutive `<prompt>` tags

**Use case**: Test prompt handling and UI state updates.

### `.complexNested`
Deeply nested tags with formatting.

**Contains**:
- `<pushBold/>` ... `<popBold/>`
- `<preset id="whisper">`
- `<d cmd="...">` interactive tags
- Nested `<a>` tags with children
- `<prompt>`

**Use case**: Test complex tag hierarchies and rendering.

## Integration Testing Patterns

### Pattern 1: Connection + Parse + Verify

```swift
@Test func test_parseRoomDescription() async throws {
    let server = MockLichServer()
    try await server.start()

    let connection = LichConnection()
    let parser = XMLStreamParser()

    try await connection.connect(host: "127.0.0.1", port: await server.port)

    await server.sendScenario(.roomDescription)

    var receivedData = Data()
    let task = Task { @MainActor in
        let stream = await connection.dataStream
        for await chunk in stream {
            receivedData.append(chunk)
            if receivedData.count > 0 { break }
        }
    }

    try await Task.sleep(nanoseconds: 300_000_000) // 0.3s
    task.cancel()

    let xml = String(data: receivedData, encoding: .utf8) ?? ""
    let tags = await parser.parse(xml)

    #expect(!tags.isEmpty)
    #expect(xml.contains("<pushStream id=\"room\"/>"))

    await connection.disconnect()
    await server.stop()
}
```

### Pattern 2: ParserConnectionBridge Integration

```swift
@Test func test_bridgeIntegration() async throws {
    let server = MockLichServer()
    try await server.start()

    let connection = LichConnection()
    let parser = XMLStreamParser()
    let bridge = ParserConnectionBridge(connection: connection, parser: parser)

    try await connection.connect(host: "127.0.0.1", port: await server.port)
    await bridge.start()

    // Send scenarios
    await server.sendScenario(.combatSequence)
    await server.sendScenario(.vitalsUpdate)

    try await Task.sleep(nanoseconds: 500_000_000)

    // Get accumulated tags
    let tags = await bridge.getParsedTags()
    #expect(!tags.isEmpty)

    await bridge.stop()
    await connection.disconnect()
    await server.stop()
}
```

### Pattern 3: Multi-Client Broadcasting

```swift
@Test func test_multiClientBroadcast() async throws {
    let server = MockLichServer()
    try await server.start()

    let client1 = LichConnection()
    let client2 = LichConnection()

    let port = await server.port
    try await client1.connect(host: "127.0.0.1", port: port)
    try await client2.connect(host: "127.0.0.1", port: port)

    await server.sendScenario(.roomDescription)

    // Both clients receive the same data
    // ... verify both received XML ...

    await client1.disconnect()
    await client2.disconnect()
    await server.stop()
}
```

### Pattern 4: Reconnection Testing

```swift
@Test func test_reconnection() async throws {
    let server = MockLichServer()
    try await server.start()

    let connection = LichConnection()

    // First connection
    try await connection.connect(host: "127.0.0.1", port: await server.port)
    await connection.disconnect()

    // Restart server (new port)
    await server.stop()
    try await server.start()

    // Reconnect
    try await connection.connect(host: "127.0.0.1", port: await server.port)

    let state = await connection.state
    #expect(state == .connected)

    await connection.disconnect()
    await server.stop()
}
```

## Error Handling

MockLichServer handles errors gracefully:

- **Port binding failure**: Throws `MockLichServerError.failedToStart`
- **Client disconnect**: Automatically removes from connection list
- **Send when not running**: Logs warning, no-op
- **Double start/stop**: Safe no-ops

## Performance Characteristics

- **Start time**: < 1 second (typically < 100ms)
- **Send throughput**: > 100 scenarios/second
- **Connection handling**: Supports 10+ concurrent clients
- **Memory**: < 1MB overhead (excluding XML content)

## Thread Safety

All MockLichServer operations are actor-isolated, ensuring:
- Safe concurrent access from multiple test tasks
- No data races on connection list
- Atomic port assignment

## Testing Best Practices

### 1. Always Clean Up

```swift
@Test func test_example() async throws {
    let server = MockLichServer()
    try await server.start()

    defer {
        Task {
            await server.stop()
        }
    }

    // ... test code ...
}
```

### 2. Use Generous Timeouts

Network operations are asynchronous. Use 200-500ms delays for data propagation:

```swift
await server.sendScenario(.roomDescription)
try await Task.sleep(nanoseconds: 300_000_000) // 0.3s
```

### 3. Handle Actor Isolation

Access `dataStream` from an async context:

```swift
let task = Task { @MainActor in
    let stream = await connection.dataStream
    for await chunk in stream {
        // Process chunk
    }
}
```

### 4. Verify Connection Count

Track connections for multi-client tests:

```swift
let count = await server.connectionCount
#expect(count == expectedClientCount)
```

### 5. Test Both Success and Failure

```swift
// Success path
await server.sendScenario(.roomDescription)

// Failure path (disconnect)
await server.stop()
// ... verify client handles disconnect ...
```

## Troubleshooting

### "Connection failed" errors
- Ensure server started: `try await server.start()`
- Verify port assigned: `let port = await server.port`
- Check port > 0 before connecting

### No data received
- Increase sleep duration (300ms+)
- Check connection state: `await connection.state`
- Verify server running: `await server.port != 0`

### Flaky tests
- Increase timeouts (500ms for slow CI)
- Ensure proper cleanup (call `stop()`)
- Use `defer` for guaranteed cleanup

### Actor isolation errors
- Wrap `dataStream` access in `Task { @MainActor in ... }`
- Use `await` for all server/connection calls

## File Locations

```
VaalinAppTests/
├── Mocks/
│   ├── MockLichServer.swift       # Server implementation
│   ├── MockLichServerTests.swift  # Unit tests for server
│   └── README.md                  # This file
└── Integration/
    └── Phase1IntegrationTests.swift  # End-to-end tests using server
```

## Related Components

- **LichConnection**: Real TCP client (`VaalinNetwork/Sources/VaalinNetwork/LichConnection.swift`)
- **XMLStreamParser**: XML parser (`VaalinParser/Sources/VaalinParser/XMLStreamParser.swift`)
- **ParserConnectionBridge**: Integration layer (`VaalinNetwork/Sources/VaalinNetwork/ParserConnectionBridge.swift`)
- **GameTag**: Parsed XML model (`VaalinCore/Sources/VaalinCore/GameTag.swift`)

## Future Enhancements

- [ ] Add scenario builder DSL for custom sequences
- [ ] Support delayed/chunked XML sending (simulate network lag)
- [ ] Add client command echo (simulate server echoing commands)
- [ ] Support WebSocket protocol (future Lich versions)
- [ ] Add scenario recording from real Lich output

## References

- [GemStone IV Wiki - Lich XML Data and Tags](https://gswiki.play.net/Lich_XML_Data_and_Tags)
- [Lich 5 Detachable Client Mode](https://github.com/elanthia-online/lich-5)
- [Illthorn TypeScript Parser](../../../illthorn/src/frontend/parser/) (reference implementation)
