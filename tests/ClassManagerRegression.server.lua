--!strict
-- Place this server Script beside a Folder named Modules containing ClassModule and Signal.
local modules = script.Parent:WaitForChild("Modules")
local Class = require(modules:WaitForChild("ClassModule"))
local Signal = require(modules:WaitForChild("Signal"))

local Base = Class.define({
    name = "Base",
    methods = {Say = function() return "works" end},
})
local Child = Class.define({name = "Child", base = Base})
local child = Child.new()
assert(child:Say() == "works", "Child did not inherit Base method")
assert(child:IsA("Base") and child:IsA("Child"), "IsA did not traverse inheritance")

local Tracked = Class.define({
    name = "Tracked",
    properties = {
        Token = {signal = true},
    },
})
local first = Tracked.new()
local second = Tracked.new()
assert(first.TokenChanged ~= second.TokenChanged, "Different instances share a property signal")
local notifications = 0
first.TokenChanged:Connect(function() notifications += 1 end)
second.Token = 1
assert(notifications == 0, "Another instance fired this signal")
first.Token = 1
assert(notifications == 1, "Own instance property signal did not fire")

local signal = Signal.new()
local value = 0
signal:Connect(function(nextValue) value = nextValue end)
signal:Fire(5)
task.wait()
assert(value == 5, "Signal constructor or Fire failed")
signal:Destroy()
print("ClassManager regression PASS: 6 checks")
