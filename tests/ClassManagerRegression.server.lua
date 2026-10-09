--!strict
-- Roblox Studio server Script, placed beside the Modules directory.
local modules = script.Parent:WaitForChild("Modules")
local Signal = require(modules:WaitForChild("Signal"))
local EventBus = require(modules:WaitForChild("EventBus"))

local signal = Signal.new()
local hits = 0
local connection = signal:Connect(function(value)
    assert(value == 42)
    hits += 1
end)
signal:Fire(42)
task.wait(0.03)
assert(hits == 1)
connection:Disconnect()

local finished = false
task.spawn(function()
    assert(signal:Wait() == nil, "Destroy should wake waiting threads")
    finished = true
end)
task.wait()
signal:Destroy()
task.wait(0.03)
assert(finished)

local bus = EventBus.new()
local calls = 0
bus:_On("tick", function() calls += 1 end, 2, false)
bus:_On("tick", function() calls += 1 end, 1, false)
bus:_Fire("tick", nil)
assert(calls == 2, "EventBus dropped a synchronous subscriber")
print("ClassManager regression PASS")
