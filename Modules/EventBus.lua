--!strict
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

export type EventBus<T...> = {
	_listeners: { [string]: { NormalListener<T...> }, ['*']: { WildListener<T...> }? },
	_On: (self: EventBus<T...>, eventName: string, callback: EventCallback<T...>, priority: number?, async: boolean?, source: any?) -> Signal.Connection<T...>,
	_Once: (self: EventBus<T...>, eventName: string, callback: EventCallback<T...>, priority: number?, async: boolean?, source: any?) -> Signal.Connection<T...>,
	_Fire: (self: EventBus<T...>, eventName: string, source: any?, T...) -> boolean,
	_Clear: (self: EventBus<T...>, eventName: string?) -> (),
}

local EventBus = {}
EventBus.__index = EventBus

function EventBus.new<T...>(): EventBus<T...>
	local self = setmetatable({}, EventBus)
	self._listeners = {}
	return self :: EventBus<T...>
end

local function createListener<T...>(callback: EventCallback<T...>,	priority: number?,async: boolean?,source: any?): NormalListener<T...>
	return {
		callback = callback,
		priority = priority or 0,
		async = async ~= false,
		source = source,
	}
end

local function sortListeners<T...>(listeners: {NormalListener<T...>})
	table.sort(listeners, function(a: NormalListener<T...>, b: NormalListener<T...>)
		return a.priority > b.priority
	end)
end

function EventBus:_On<T...>(eventName: string,callback: EventCallback<T...>,priority: number?,async: boolean?,source: any?): Signal.Connection<T...>
	local listeners: {NormalListener<T...>} = self._listeners[eventName] or {}:: {NormalListener<T...>}
	self._listeners[eventName] = listeners:: {NormalListener<T...>}

	local listener = createListener(callback:: any, priority, async, source)
	table.insert(listeners:: {NormalListener<T...>}, listener:: NormalListener<T...>)
	sortListeners(listeners:: any)

	local connection: Signal.Connection<T...>
	connection = {
		Connected = true,
		Disconnect = function()
			if not connection.Connected then return end
			connection.Connected = false
			for i, l in ipairs(listeners) do
				if l == listener then
					table.remove(listeners, i)
					break
				end
			end
		end,
	} :: Signal.Connection<T...>

	return connection
end

function EventBus:_Once<T...>(eventName: string,callback: EventCallback<T...>,priority: number?,async: boolean?,source: any?): Signal.Connection<T...>
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
		for _, listener in ipairs(listeners) do
			if listener.async then
				task.spawn(listener.callback, source, ...)
			else
				local result = listener.callback(source, ...)
				if result == false then return false end
			end
		end
	end

	local wild: {WildListener<T...>}? = self._listeners["*"]:: any
	if wild then
		for _, listener in ipairs(wild) do
			if listener.async then
				task.spawn(listener.callback, eventName, source, ...)
			else
				local result = listener.callback(eventName, source, ...)
				if result == false then return false end
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