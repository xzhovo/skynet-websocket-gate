# Skynet websocket gate 服务

这是基于 [Skynet 官方 websocket 分支](https://github.com/cloudwu/skynet/tree/websocket) 的 websocket 版 ws_gate 服务，功能同 [原版 gate](https://github.com/cloudwu/skynet/wiki/GateServer)  

**准备**  
将本目录下 websocket.lua 中的 `forward` 函数加入 *.\lualib\http\websocket.lua*，或者比对替换  

**使用**  
在需要 `websocket.write` 的服务中引入 `local websocket = require "http.websocket"` 并调用 `websocket.forward(fd, protocol, addr)`  
`forward` 和 `kick` 和原版一致  

**注意**  
无法支持 websockets，建议反向代理  