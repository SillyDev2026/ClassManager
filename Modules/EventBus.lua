--!strict
local Class = require(script.Parent.ClassSystem)
local Signal = require(script.Parent.Signal)

export type EventCallback<T...> = (source: any, T...) -> (boolean?)
export type EventCallbackWithName<T...> = (eventName: string, source: any, T...) -> (boolean?)

export type NormalListener<T...> = {
	callback: EventCallback<T...>,
	priority: number,
	async: boolean,
	source: any?,
}

export type WildListener<T...> = {
	callback: EventCallbackWithName<T...>,
	priority: number,
	async: boolean,
	source: any?,
}

export type EventBus = {
	_listeners: { [string]: { NormalListener<...any> }, ['*']: WildListener<...any>? },
	_On: <T...>(self: EventBus, eventName: string, callback: EventCallback<T...>, priority: number?, async: boolean?, source: any?) -> Signal.Connection<T...>,
	_Once: <T...>(self: EventBus, eventName: string, callback: EventCallback<T...>, priority: number?, async: boolean?, source: any?) -> Signal.Connection<T...>,
	_Fire: <T...>(self: EventBus, eventName: string, source: any?, T...) -> boolean,
	_Clear: (self: EventBus, eventName: string?) -> (),
}

local EventBus = {}
EventBus.__index = EventBus

function EventBus.new(): EventBus
	local self = setmetatable({}, EventBus):: any
	self._listeners = {}
	return self
end

local function createListener(callback: EventCallback<...any>, priority: number?, async: boolean?, source: any?): NormalListener<...any>
	return {
		callback = callback,
		priority = priority or 0,
		async = async ~= false,
		source = source,
	}
end

local function sortListeners<T...>(listeners)
	table.sort(listeners, function(a, b)
		return (a::NormalListener<T...>).priority > (b::NormalListener<T...>).priority
	end)
end
function EventBus:_On<T...>(eventName: string, callback: EventCallback<T...>, priority: number?, async: boolean?, source: any?): Signal.Connection<T...>
	if not self._listeners[eventName] then
		self._listeners[eventName] = {}
	end
	local listener = createListener(callback, priority, async, source)
	table.insert(self._listeners[eventName], listener)
	sortListeners(self._listeners[eventName])
	local connection: Signal.Connection<T...>
	connection = {
		Connected = true,
		Disconnect = function()
			if not connection.Connected then return end
			connection.Connected = false
			for i, l in ipairs(self._listeners[eventName]) do
				if l == listener then
					table.remove(self._listeners[eventName], i)
					break
				end
			end
		end,
	} :: Signal.Connection<T...>
	return connection
end

function EventBus:_Once<T...>(eventName: string, callback: EventCallback<T...>, priority: number?, async: boolean?, source: any?): Signal.Connection<T...>
	local connection: Signal.Connection<T...>
	connection = self:_On(eventName, function(sourceArg: any, ...: T...)
		connection:Disconnect()
		return callback(sourceArg, ...)
	end, priority, async, source)
	return connection
end

function EventBus:_Fire<T...>(eventName: string, source: any?, ...: T...): boolean
	local listeners: {NormalListener<T...>}? = self._listeners[eventName]
	if listeners then
		for i = 1, #listeners do
			local listener: NormalListener<T...> = listeners[i]
			if listener.async then
				task.spawn(listener.callback, source, ...)
			else
				local result = listener.callback(source, ...)
				if not result then return false end
			end
		end
		return true
	end
	local listen = self._listeners['*']:: any
	local wild: {WildListener<T...>}? = listen
	if wild then
		for i = 1, #wild do
			local listener: WildListener<T...> = wild[i]
			if listener.async then
				task.spawn(listener.callback, eventName, source, ...)
			else
				local result = listener.callback(eventName, source, ...)
				if not result then return false end
			end
		end
	end
	return true
end

function EventBus:_Clear(eventName: string?)
	if eventName then
		self._listeners[eventName] = nil
	else
		self._listeners = {}
	end
end

return EventBus