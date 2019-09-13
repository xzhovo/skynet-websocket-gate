local skynet = require "skynet"
require "skynet.manager"
local socket = require "skynet.socket"
local websocket = require "http.websocket"

local watchdog
local connection = {}	-- fd -> connection : { fd , client, agent , ip, mode }
local forwarding = {}	-- agent -> connection

local function unforward(c)
	if c.agent then
		forwarding[c.agent] = nil
		c.agent = nil
		c.client = nil
	end
end

local function close_fd(fd)
	local c = connection[fd]
	if c then
		unforward(c)
		connection[fd] = nil
	end
end

local handle = {}

function handle.connect(fd)
	local addr = websocket.addrinfo(fd)
    print("ws connect from: " .. tostring(fd))
    local c = {
		fd = fd,
		ip = addr,
	}
	connection[fd] = c
	skynet.send(watchdog, "lua", "socket", "open", fd, addr)
end

function handle.handshake(fd, header, url)
    local addr = websocket.addrinfo(fd)
    print("ws handshake from: " .. tostring(fd), "url", url, "addr:", addr)
    print("----header-----")
    for k,v in pairs(header) do
        print(k,v)
    end
    print("--------------")
end

function handle.message(fd, msg)
	print("ws ping from: " .. tostring(fd), msg.."\n")
	local sz = #msg
    -- recv a package, forward it
	local c = connection[fd]
	local agent = c.agent
	if agent then
		-- It's safe to redirect msg directly , gateserver framework will not free msg.
		skynet.redirect(agent, c.client, "client", fd, msg, sz)
	else
		skynet.send(watchdog, "lua", "socket", "data", fd, msg)
		-- skynet.tostring will copy msg to a string, so we must free msg here.
		skynet.trash(msg,sz)
	end
end

function handle.ping(fd)
    print("ws ping from: " .. tostring(fd) .. "\n")
end

function handle.pong(fd)
    print("ws pong from: " .. tostring(fd))
end

function handle.close(fd, code, reason)
    print("ws close from: " .. tostring(fd), code, reason)
    close_fd(fd)
	skynet.send(watchdog, "lua", "socket", "close", fd)
end

function handle.error(fd)
    print("ws error from: " .. tostring(fd))
    close_fd(fd)
	skynet.send(watchdog, "lua", "socket", "error", fd, msg)
end


local CMD = {}

function CMD.open(source, conf)
	print("open", source, conf)
	watchdog = conf.watchdog or source

	local address = conf.address or "0.0.0.0"
	local port = assert(conf.port)
	local protocol = "ws"
    local fd = socket.listen(address, port)
    skynet.error(string.format("Listen websocket port:%s protocol:%s", port, protocol))
    socket.start(fd, function(fd, addr)
        print(string.format("accept client socket_fd: %s addr:%s", fd, addr))
        websocket.accept(fd, handle, protocol, addr)
    end)
end

function CMD.forward(source, fd, client, address)
	local c = assert(connection[fd])
	unforward(c)
	c.client = client or 0
	c.agent = address or source
	forwarding[c.agent] = c
	-- websocket.forward(fd, handle, protocol, addr)
end

function CMD.accept(source, fd)
	local c = assert(connection[fd])
	unforward(c)
	--websocket.start(fd)
end

function CMD.kick(source, fd)
	websocket.close(fd)
end

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
}

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if not f then
            skynet.error("simplewebsocket can't dispatch cmd ".. (cmd or nil))
            skynet.ret(skynet.pack({ok=false}))
            return
        end
        if session == 0 then
            f(source, ...)
        else
            skynet.ret(skynet.pack(f(source, ...)))
        end
    end)

    skynet.register(".ws_gate")

    skynet.error("ws_gate booted...")
end)