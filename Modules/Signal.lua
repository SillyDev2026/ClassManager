--!strict
local Class = require(script.Parent.ClassSystem)

export type Connection<T...> = {
	Connected: boolean,
	Callback: (T...) -> (),
	Signal: Signal<T...>,
	Disconnect: (self: Connection<T...>) -> (),
}

export type Signal<T...> = {
	_connections: { Connection<T...> },
	_waitingThreads: { thread },
	_destroyed: boolean,

	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection<T...>,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection<T...>,
	Wait: (self: Signal<T...>) -> (T...),
	Fire: (self: Signal<T...>, T...) -> (),
	FireAsync: (self: Signal<T...>, T...) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

function createConnection<T...>(signal: Signal<T...>, callback: (T...) -> ()): Connection<T...>
	local connection: Connection<T...> = {
		Connected = true,
		Callback = callback,
		Signal = signal,
		Disconnect = function(self: Connection<T...>)
			if not self.Connected then return end
			self.Connected = false
			local sig = self.Signal
			for i, conn in ipairs(sig._connections) do
				if conn == self then
					table.remove(sig._connections, i)
					break
				end
			end
		end,
	}
	return connection
end

local SignalClass = Class.define({
	name = "Signal",
	base = nil,
	abstract = false,
	properties = {},
	static = {},
	mixins = {},
	interfaces = {},
	constructor = function(self)
		self._connections = {}
		self._waitingThreads = {}
		self._destroyed = false
	end,
	methods = {
		Connect = function<T...>(self: Signal<T...>, callback: (T...) -> ()): Connection<T...>
			assert(not self._destroyed, "Cannot connect to destroyed Signal")
			local connection: Connection<T...> = createConnection(self, callback)
			table.insert(self._connections, connection)
			return connection
		end,
		
		Once = function<T...>(self: Signal<T...>, callback: (T...) -> ()): Connection<T...>
			local connection: Connection<T...>
			connection = self:Connect(function(...)
				connection:Disconnect()
				callback(...)
			end)
			return connection
		end,

		Wait = function<T...>(self: Signal<T...>): (T...)
			assert(not self._destroyed, "Cannot wait on destroyed Signal")
			local thread = coroutine.running()
			table.insert(self._waitingThreads, thread)
			return coroutine.yield()
		end,

		Fire = function<T...>(self: Signal<T...>, ...: T...)
			if self._destroyed then return end

			local conns = table.clone(self._connections)
			local args = table.pack(...:: any)
			for _, conn in ipairs(conns) do
				if conn.Connected then
					conn.Callback(table.unpack(args, 1, args.n))
				end
			end

			local waiting = table.clone(self._waitingThreads)
			table.clear(self._waitingThreads)
			for _, thread in ipairs(waiting) do
				task.spawn(coroutine.resume, thread, ...)
			end
		end,

		FireAsync = function<T...>(self: Signal<T...>, ...: T...)
			if self._destroyed then return end
			local args = table.pack(...:: any)
			task.defer(function()
				self:Fire(table.unpack(args, 1, args.n))
			end)
		end,

		Destroy = function<T...>(self: Signal<T...>)
			if self._destroyed then return end
			self._destroyed = true
			for _, conn in ipairs(self._connections) do
				conn.Connected = false
			end
			table.clear(self._connections)
			table.clear(self._waitingThreads)
		end,
	},
})

local SignalModule = {}

function SignalModule.new<T...>(): Signal<T...>
	return SignalClass.new() :: Signal<T...>
end

return SignalModule