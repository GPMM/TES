--- @module SEplayer.SEplayer

local SEplayer = {}
SEplayer.__index = SEplayer


local utils = require("SEtranslator_async.utils")

local socket = require("socket")

ip = "127.0.0.1"
port = 31337

local time_scale = 9000


function SEplayer:new(p)
  local obj = {}
  obj.effect = p
  obj.queue = {}
  return setmetatable(obj, self)
end

function SEplayer:register(f)
  self.listener = f
end


function SEplayer:create_sedl(action,delay)
  local eft = {}
  eft[#eft+1] = "<Effect type='" .. self.effect.type .. "'"
  for k,v in pairs(self.effect) do
    if k == 'type' then
      -- do nothing
    elseif k == 'location' then
      eft[#eft+1] = k .. "='" .. table.concat(v, ':') .. "'"
    elseif k == 'intensity' then
      eft[#eft+1] = k .. "-value='" .. v .. "'"
    else
      eft[#eft+1] = k .. "='" .. v .. "'"
    end
  end
  local t = action == 'start' or action == 'resume'
  eft[#eft+1] = "activate='" .. tostring(t) .. "'"
  if delay then
    eft[#eft+1] = "pts='" .. delay*time_scale.. "'"
  end
  eft[#eft+1] = '/>'
  return table.concat(eft, ' ')
end



function send_udp(sedl)

    -- ENVIAR PELA REDE

    --package.path = ';../luasocket-2.0.2/src/?.lua;' .. package.path
    local socket = require("socket")
    local udp = assert(socket.udp())
    local data

    udp:settimeout(1)
    assert(udp:setsockname("*",0))
    assert(udp:setpeername(ip,port))

    for i = 0, 2, 1 do
      assert(udp:send(sedl))
      data = udp:receive()
      if data then
        break
      end
    end

    if(data == nil) then
      return "timeout"
    else
      return data
    end
end


-- essa função poderia vai ficar em loop infinito até receber a resposta.
-- a princípio faz sentido né, o loop infinito seria a execução do efeito como mídia.
-- com certeza assim não terá nem pause nem stop no meu efeito, já que o lua só vai parar quando receber udp
-- Então uma idéia é usar io assíncrono para tratar isso. Abaixo tem uma implementação do copas (socket assíncrono)

function udp_response_callback()

udp = socket.udp()
udp:setsockname("127.0.0.1", 31338)
udp:settimeout(0)

while true do
    data, ip, port = udp:receivefrom()
    if data then
        print("Received from MPE: ", data, ip, port)
        return data
    end
    socket.sleep(0.01)
end

end




function udp_copas_callback()

  copas = require "copas"

  udp = socket.udp()
  udp:setsockname("127.0.0.1", 31338)
  udp:settimeout(0.5)

  function handler(skt)
    skt = copas.wrap(skt)
    print("UDP connection handler")

    local s, err
    print("receiving...")
    s, err = skt:receive(2048)
    if not s then
      print("Receive error: ", err)
      return
    end
    print("Received data, bytes:" , #s)

  end

  copas.addserver(udp, handler, 1)
  --copas.loop()



  -- A IDÉIA É TER O COPAS RODANDO JUNTO COM O EVT. CADA VEZ QUE O EVT RODA, O COPAS DÁ UM STEP E BUSCA A RESPOSTA


  local cont = 1
  for i=1,5 do
    print("estoy assincrono"..cont)
    cont = cont +1
    -- processing for other events from your system here
    copas.step(0.5)
  end


end


function SEplayer:play(activate,delay)

  sedl = self:create_sedl(activate,delay)

  res = send_udp(sedl)

  print("***********Tabela de efeitos***********")
  tprint(self.effect)
  print("***********SEDL gerado***********")
  print(sedl)
  print("***********Resposta UDP***********")
  print(res)


end




-- NCLua

function SEplayer:presentation(evt)

  self:play("true",delay)

  if evt.action == 'start' then
    print("EffectInterface recebeu um start, executando efeito sensorial")
    self:play("true",delay)

  elseif evt.action == 'stop' or evt.action == 'abort' then
    print("Script parou, Finalizando efeito sensorial")
    self:play("false",delay)
    -- TODO:modificar o estado do efeito na queue
    effect.queue = {}

  elseif evt.action == 'pause' then
    -- mandar um activate=pause para o simulador (MPE).
    -- A MPE deve entender isso como uma suspensão de contadores (delay ou duração) relativos a esse efeito
    -- se o efeito for infinito, MPE não faz nada. Pois ele teoricamente ja está "pausado"
    self:play("pause",delay)
    -- TODO:modificar o estado do efeito na queue

  elseif evt.action == 'resume' then
    -- retorna de onde parou o pause
    self:play("true",delay)
    -- TODO:modificar o estado do efeito na queue
  end

  -- TODO:esperar callback para dar resposta ao post_evt(action)

  return udp_copas_callback(self.effect)


end



return SEplayer