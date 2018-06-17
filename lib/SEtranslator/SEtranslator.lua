--- @module SEplayer.SEplayer
package.path = './lib/?.lua;' .. package.path

local SEplayer = {}
SEplayer.__index = SEplayer


local utils = require("SEtranslator.utils")

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
  tprint(self.effect)
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
    print("enviando udp:")
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

  print("apresentando:")
  -- cria e envia o efeito
  local sedl = self:create_sedl(evt.action, 0)
  print("meu sedl e:"..sedl)
  send_udp(sedl)

  if evt.action == 'start' then
      if self.effect.duration ~= nil then
      -- Cria stop e coloca na fila
      self.queue[#self.queue+1] = {self.effect.duration, 'stop'}
      end
      print("minha queue")
      tprint(self.queue)
      self:start_queue()
    elseif evt.action == 'stop' or evt.action == 'abort' then
      print("paroou")
      self.unreg()
      self.queue = {}
    elseif evt.action == 'pause' then
      self:pause_queue()
    elseif evt.action == 'resume' then
      self:start_queue()
    end

end



function SEplayer:run_queue()
  -- é preciso fazer alguma coisa antes para ver quem já pode ser disparado
  -- não sei se vale a pena usar timer ou ficar disparando evento de usuário
  -- do ncl para ficar gerenciando a fila. Sugestões?

  -- pensei em algo do tipo:
  -- verifica o tempo desde a última chamada de run_queue()
  local current_time = os.time()
  local time_passed = current_time - self.last_run

  print("time_passed: "..time_passed)

  -- a lista de eventos na fila pode ficar armazenada por ordem de delay
  table.sort(self.queue)

  -- essa função run_queue() é chamada, então ela vai pegar o tempo atual do sistema
  -- vai ver quanto tempo se passou desde a última vez que ela foi chamada e vai
  -- decrementar esse tempo dos delays da fila

  local prontos = {}
  for k,e in pairs(self.queue) do
    print("e[1] before: "..e[1])
    e[1] = e[1] - time_passed
    print("e[1] after: "..e[1])
    if e[1] == 0 then
      prontos[#prontos+1] = e
      table.remove(self.queue, k)
    end
  end

  print("prontos:")
  tprint(prontos)

  -- o delay que tiver chegado a zero vai enviar na rede e
  -- notificar o ncl como o código abaixo
  for _,e in pairs(prontos) do
    -- envia o efeito na fila uma vez alcançado seu delay
    print("criando sedl com e[2]="..e[2])
    local sedl = self:create_sedl(e[2], 0)
    print("meu sedl: "..sedl)
    send_udp(sedl)
    -- notifica o ncl do evento ocorrido
    self.listener(e[2])
  end

  print("--------------> "..self.queue[1][1])

  -- depois de disparado o efeitos que deveriam, volta a esperar para uma
  -- nova passada pela lista. Pega o menor valor e gera um timer para
  -- ele. Como a tabela está ordenada, o primeiro tem o menor delay.
  self.unreg = event.timer(self.queue[1][1]*1000, self:run_queue())
  return
end


function SEplayer:pause_queue()
  -- para o timer
  self.unreg()

  -- verifica o tempo desde a última chamada de run_queue()
  local current_time = os.time()
  local time_passed = current_time - self.last_run

  -- decrementa esse tempo de todos os delays
  for e in pairs(self.queue) do
    e[1] = e[1] - time_passed
  end
end


function SEplayer:start_queue()
  -- guarda o tempo de inicio da file
  local current_time = os.time()
  self.last_run = current_time
  print("last_run"..self.last_run)

  -- a lista de eventos na fila pode ficar armazenada por ordem de delay
  table.sort(self.queue)

  print("minha queue apos sort:")
  tprint(self.queue)
  -- esperar para uma nova passada pela lista. Pega o menor valor e gera um
  -- timer para ele. Como a tabela está ordenada, o primeiro tem o menor delay.
  self.unreg = event.timer(self.queue[1][1]*1000, self:run_queue())
  return
end


return SEplayer
