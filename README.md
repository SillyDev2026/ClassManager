# ClassManager — Roblox Luau classes, signals and events

ClassManager contains a runtime `Class.define` helper, a typed generic `Signal` facade, and an `EventBus`. The repository stores all three as sibling modules under `Modules`.

## Installation

```text
ReplicatedStorage
└── ClassManager
    ├── ClassModule
    ├── Signal
    └── EventBus
```

```luau
local package = game.ReplicatedStorage.ClassManager
local Class = require(package.ClassModule)
local Signal = require(package.Signal)
local EventBus = require(package.EventBus)

local changed = Signal.new()
local connection = changed:Connect(function(value)
    print("Value changed:", value)
end)
changed:Fire(5)
connection:Disconnect()
changed:Destroy()

local bus = EventBus.new()
bus:_On("Example", function(source, value)
    print(source, value)
end, 0, true)
bus:_Fire("Example", "server", 5)
```

## API

| Module | Primary functions |
| --- | --- |
| `ClassModule` | `define`, `new`, class `new`, `IsA`, `GetClassName` |
| `Signal` | `new`, `Connect`, `Once`, `Wait`, `Fire`, `FireAsync`, `Destroy` |
| `EventBus` | `new`, `_On`, `_Once`, `_Fire`, `_Clear` |

## Correctness patch

- Fixed a missing `ClassSystem` sibling require: the class implementation is actually `ClassModule`.
- Localized `createConnection` so loading Signal does not create a global.
- Wake pending Signal waiters on `Destroy()` (receiving `nil`) rather than leaving suspended threads.
- Use the scheduler's direct coroutine resume, preserving visible coroutine errors.
- Snapshot EventBus subscribers during dispatch so disconnecting a handler cannot skip another listener while iterating.

This keeps method names and the module folder layout unchanged. The class system remains dynamically typed in places where it constructs tables at runtime; the presence of Luau type aliases alone is not evidence of a clean end-to-end `--!strict` typecheck. Run the included Studio test and Script Analysis before merging.

## Test

Copy `tests/ClassManagerRegression.server.lua` into a Roblox Studio Script alongside the `Modules` folder. It checks requiring Signal, firing callbacks, waiting, cancellation, and EventBus dispatch after disconnect.
