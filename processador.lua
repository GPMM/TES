package.path = './lib/?.lua;' .. package.path
require "xml.xml"
require "xml.handler"
require "xml.tableToXML"



-- Print contents of `tbl`, with indentation.
-- `indent` sets the initial level of indentation.
function tprint(tbl, indent)
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    formatting = string.rep("  ", indent) .. k .. ": "
    if type(v) == "table" then
      print(formatting)
      tprint(v, indent+1)
    else
      print(formatting .. v)
    end
  end
end

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function table.removekey(table, key)
    local element = table[key]
    table[key] = nil
    return element
end


local function contains(table, val)
   for i=1,#table do
      if table[i] == val then
         return true
      end
   end
   return false
end

function splitFilename(strFilename)
  -- Returns the Path, Filename, and Extension as 3 values
  sep = package.config:sub(1,1)
  print(sep)
  return string.match(strFilename, "(.-)([^"..sep..sep.."]-([^"..sep..sep.."%.]+))$")
end



function getTags(table)
  local tags = {}
  if table.area then
    for i=1, #table.area do
      if table.area[i]._attr["tag"] then
        tags[i] = table.area[i]._attr["tag"]
      end
    end
    return tags
  end
end




local function has_value (tab, val)
    for index, value in pairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

path,file,extension = splitFilename(arg[1])
print(path,file,extension)
if (extension ~= "ncl") then
  error("Voce deve passar um arquivo com a extensao .ncl")
end

filename_in = arg[1]
f, e = io.open(filename_in, "r")
if f then
  xmltextNCL = f:read("*a")
  else
    error(e)
end

--Instantiate the object the states the XML file as a Lua table
xmlhandlerNCL = simpleTreeHandler()

--Instantiate the object that parses the XML to a Lua table
xmlparserNCL = xmlParser(xmlhandlerNCL)
xmlparserNCL:parse(xmltextNCL)

res = showTable(xmlhandlerNCL.root)
--print(res)

effect_id_list = {}


-- loop para buscar os atributos de mídia de efeitos sensoriais
for key, value in pairs(xmlhandlerNCL.root.ncl.body.media) do

   has_sensory_effects = "no"
   player_increment = 1

   if(value._attr.setype) then
      has_sensory_effects = "yes"
   end
   print("media:'".. value._attr.id .."'has sensory effects?:".. has_sensory_effects)


   if(has_sensory_effects == "yes") then

      effect_id_list[#effect_id_list+1] = value._attr.id

      -- Criar uma nova area para essa mídia
      value.area = {}
      value.area._attr = {}
      value.area._attr.id = {}
      value.area._attr["id"] = "effectInterface"

      -- adicionar um novo arquivo lua que vai representar o efeito sensorial
      -- será um novo arquivo para cada mídia de efeito sensorial
      -- esse arquivo deverá ter os valores de atributos
      player_instance_name = ""..effect_id_list[#effect_id_list].."_"..value._attr.setype.."Player.lua" -- string.format("%04d",player_increment)
      value._attr.src = player_instance_name


      -- Remover o SEtype do NCL
      effect_type = value._attr.setype
      value._attr.setype = nil

      effect_properties = {}
      -- Salvar as propriedades de mídia numa tabela
      for _,property in pairs(value.property) do
         if(property._attr.name) then
            effect_properties[property._attr.name] = property._attr.value
         end
      end

      -- transformar a localização de NCL para string
      if(effect_properties["azimuthal"] and effect_properties["polar"]) then
            effect_location = "{"..effect_properties["azimuthal"]..","..effect_properties["polar"]..""
            effect_properties["azimuthal"],effect_properties["polar"] = nil
      else
         if(effect_properties["wcs"]) then
            effect_location = "{"..effect_properties["wcs"]..""
            effect_properties["wcs"] = nil
         else
            error("Nao identificados parametros de localização do efeito. Você deve usar (azimulhal,polar) ou (WCS) ")
         end
      end

      if(effect_properties["width"] and effect_properties["height"]) then
         effect_location = effect_location .. "," .. effect_properties["width"] .. "," .. effect_properties["height"] .. "}"
         effect_properties["width"],effect_properties["height"] = nil
      else
         effect_location = effect_location .. "}"
      end


      player_instance = [[
--- automatically created palyer instance
function main()
require('event')
package.path = './lib/?.lua;' .. package.path
local SEplayer = require('lib.SEplayer.SEplayer')

local effect = {}]].."\n"
player_instance = player_instance .. "effect.type = '"..effect_type.."'\n"
player_instance = player_instance .. "effect.location = "..effect_location.."\n"

-- adicionando o restante das propriedades
for k,v in pairs(effect_properties) do
   player_instance = player_instance .. "effect."..k.. " = '" .. v .. "'\n"
end
player_instance = player_instance .. "print('"..player_instance_name.." iniciado')"
player_instance =  player_instance .. [[

local player = SEplayer:new(effect)


function handler(evt)
  if (evt.class ~= 'ncl') then return end
  if (evt.type == 'presentation') and (evt.label == 'effectInterface') then
    player:presentation(evt)
  elseif (evt.type == 'attribution') then
      effect[evt.name] = evt.value
  end
end

function post_evt(action)
  evt = {}
  evt.class = 'ncl'
  evt.type = 'presentation'
  evt.label = 'effectInterface'
  evt.action = action
  event.post(evt)
end

event.register(handler)
player:register(post_evt)

end

local ok, res = pcall(main)

if not ok then
   print("\n\nError: "..res, "\n\n")
   return -1
end

]]



   local file = io.open(""..path..""..player_instance_name, "w")
   file:write(player_instance)
   file:close()



   end

end




-- alterar restante do documento para ficar consistente com o novo .lua


-- passo necessário para podermos inserir novas portas com table.insert
if(xmlhandlerNCL.root.ncl.body.port._attr)then
   temp_table = deepcopy(xmlhandlerNCL.root.ncl.body.port)
   xmlhandlerNCL.root.ncl.body.port = {}
   xmlhandlerNCL.root.ncl.body.port[1] = temp_table
end


for _,effect_id in pairs(effect_id_list) do

      -- Criar uma porta para essa mídia ( p/ forçar a inicialização do .lua)
      temp_table = {_attr={}}
      temp_table._attr["id"] = "p"..effect_id
      temp_table._attr["component"] = effect_id
      table.insert(xmlhandlerNCL.root.ncl.body.port,temp_table)

      --  já que estamos aqui, vamos buscar links (~=set) e inserir a interface neles
      for link_key, link_value in pairs(xmlhandlerNCL.root.ncl.body.link) do
         for _,bind_v in pairs(link_value.bind) do
            if(bind_v._attr.role ~= "set" and bind_v._attr.component == effect_id) then
               bind_v._attr["interface"] =  "effectInterface"
            end
         end
      end

end







writeToXml(xmlhandlerNCL.root,""..arg[1].."_ready.ncl")

