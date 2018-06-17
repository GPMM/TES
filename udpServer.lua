local socket = require("socket")

udp = socket.udp()
udp:setsockname("127.0.0.1", 31337)
udp:settimeout()

while true do
    data, ip, port = udp:receivefrom()
    if data then
        print("Received: ", data, ip, port)
        udp:sendto("Thanks", ip, port)
    end
    socket.sleep(0.01)
end