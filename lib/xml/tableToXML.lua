---Converte uma tabela lua para uma string que representa um trecho de código XML
--@param tb Tabela a ser convertida
--@param level Apenas usado internamente, quando a função
--é chamada recursivamente, para imprimir espaços e 
--representar os níveis dentro da tabela.
--@param elevateAnonymousSubTables Se igual a true, quando encontrada uma sub-tabela sem nome dentro da tabela
--(tendo sido definida apenas como {chave1 = valor1, chave2 = valor2, chaveN = valorN}
--ao invés de nomeSubTabela = {chave1 = valor1, chave2 = valor2, chaveN = valorN})
--os elementos da sub-tabela serão consideradas como se estivessem diretamente dentro da tabela 
--a qual a sub-tabela pertence, e não que estejam dentro da sub-tabela. 
--Tais sub-tabelas não tem um nome para a chave, e sim um índice definido
--automaticamente pelo compilador Lua. O parâmetro é opcional e seu valor default é false.
--O uso do valor true é útil quando tem-se sub-tabelas contendo apenas um campo,
--onde colocou-se tal campo dentro da sub-tabela sem nome, apenas para que, ao ser processada a tabela
--principal, os campos sejam acessados na ordem em que foram definidos, e não em ordem
--arbitrária definida pela função pairs (usada internamente nesta função).
--Assim, o comportamento padrão de acesso aos elementos de uma tabela
--não garante que os campos serão acessados na mesma ordem em que
--foram definidos. 
--@return Retorna a string com as tags XML geradas
--a partir dos itens da tabela
--@param tableName Nome da variável table sendo passada para a função. 
--Este parâmetro é opcional e seu valor é utilizado apenas quando
--é passada uma table em formato de um vetor (array) onde 
--só existem índices, não existindo chaves nomeadas (como ocorre em um registro/struct).
--Assim, para cada posição no vetor, será gerada uma tag com o nome do mesmo,
--contendo os dados de cada posição. Isto é utilizado
--quando o método no Web Service a ser chamado possuir um vetor como parâmetro.
--Logo, a função tableToXml gerará
--um código XML como <vet>valor1</vet><vet>valor2</vet><vet>valorN</vet>.
	
require "util"






function addNewItem(keyTable, myTable, key, value)
    table.insert(keyTable, key)
    myTable[key] = value 
end 

function attrToXml(attrTable)
	local s = ""
	for k, v in pairs(attrTable) do
      	s = s .. " " .. k .. "=" .. '"' .. v .. '"'
	end
	return s
end

function lookingForAttr(attrTable)
  lookingfor = false
  for k, v in pairs(attrTable) do
    if k == "_attr" then
      lookingfor = true
    end
  end
  return lookingfor
end

local function tableToXml(tb, level, elevateAnonymousSubTables, tableName)
	level = level or 1
	local spaces = string.rep(' ', level*2)
	local xmltb = {}
	
	--printable(tb)
	
	for k, v in pairs(tb) do
    if type(k) ~= "number" then 
      tableName = k
    end
		if type(v) == "table" then
			if type(k) == "number" then
				--Se o nome da chave da sub-tabela for um número,
				--é porque esta sub-tabela não possui um nome, tendo sido definida
				--como {chave1 = valor1, chave2 = valor2, chaveN = valorN}
				--ao invés de nomeSubTabela = {chave1 = valor1, chave2 = valor2, chaveN = valorN}.
				--Então, se é pra elevar esta sub-tabela anônima, processa seus campos como
				--se estivessem fora da sub-tabela, como explicado na documentação desta função.
				if elevateAnonymousSubTables then  
					table.insert(xmltb, spaces..tableToXml(v, level+1))
				else
					local attrs = attrToXml(v._attr)
	               	v._attr = nil
	               		-- MOD
	               	if getFirstKey(v) then
	               		table.insert(xmltb, spaces..'<'..tableName..attrs..'>\n'..tableToXml(v, level+1)..'\n'..spaces..'</'..tableName..'>') 
	               	else
	               		table.insert(xmltb, spaces..'<'..tableName..attrs..'/>'..tableToXml(v, level+1)) 
					end
					-- /MOD
				end
			else --se o elemento é uma tabela e sua chave tem um nome definido    
	            level = level + 1
				--Obtém o nome da primeira chave da sub-tabela v. Se o tipo dela for numérico,
				--considera que a mesma é um array (vetor), assim, para cada elemento existente,
				--será criada uma tag com o nome da table. 
				--Por isto, aqui a função tableToXml é chamada recursivamente,
				--passando um valor para o parâmetro tableName.
				if type(getFirstKey(v)) == "number" then --
					--table.insert(xmltb, spaces..tableToXml(v, level, false, k))
          table.insert(xmltb, tableToXml(v, level, false, k))
				else
					--Senão, considera que a table está em formato de struct,
					--logo, possui chaves nomeadas. Desta forma, cria uma tag com o nome da table
					--e inclui seus elementos como sub-tags contendo seus respectivos nomes.
					if lookingForAttr(v) then
						local attrs = attrToXml(v._attr)
            if attrs ~= nil then
              v._attr = nil
              if not next(v) then
              	-- MOD
              		-- verifica se existem filhos e coloca apenas coloca /> ao final de tags sem filhos
              	if getFirstKey(v) then
              		table.insert(xmltb, spaces..'<'..k..attrs..'>'..'</'..k..'>')
              	else
              		table.insert(xmltb, spaces..'<'..k..attrs..'/>')
           		end
           		-- /MOD
              else
                table.insert(xmltb, spaces..'<'..tableName..attrs..'>\n'..tableToXml(v, level)..'\n'..spaces..'</'..tableName..'>')
              end
            end
					else
						table.insert(xmltb, spaces..'<'..k..'>\n'.. tableToXml(v, level)..'\n'..spaces..'</'..k..'>')
					end
				end
			end
		else
			--Se o parâmetro tableName foi informado, é porque a table passada
			--está estruturada como um array (vetor), assim, para cada elemento dela
			--deve ser criada uma tag com o nome da table (tableName)
			if tableName then
	            k = tableName
			else
				--Se o elemento não for uma tabela mas o nome da sua chave for um índice numérico,
				--deve-se incluir uma letra qualquer antes do nome da chave, pois alguns
				--WS (como os em PHP) não suportam chaves numéricas no XML.
				--Isto é feito apenas quando a função é chamada para gerar o trecho XML para
				--os parâmetros de entrada do WS, quando elevateAnonymousSubTables é true.
				if type(k) == "number" and elevateAnonymousSubTables then 
	               	k = "p" .. k --p é o prefixo de param (poderia ser usado qualquer caractere alfabético)
				end
			end
      if lookingForAttr(tb) then
        local attrs = attrToXml(tb._attr)
        if attrs ~= nil then
          tb._attr = nil
          table.insert(xmltb, spaces..'<'..k..attrs..'>'..'</'..k..'>')
        end
      else
        table.insert(xmltb, spaces..'<'..k..'>'..tostring(v)..'</'..k..'>')
      end  
		end
	end
	return table.concat(xmltb, "\n")
end

---Grava uma tabela em um arquivo xml no disco
--@param tb Tabela a partir da qual será gerado o xml
--@param fileName Nome do arquivo xml a ser criado
--@param encoding Codificação de caracteres a ser definida
--no cabeçalho do xml (opcional, valor padrão ISO-8859-1)
function writeToXml(tb, fileName, encoding)
	local encoding = encoding or "ISO-8859-1"
	local xmlText = tableToXml(tb, 1, false, getFirstKey(tb))
 	xmlText = '<?xml version="1.0" encoding="'.. encoding ..'"?>\n' .. xmlText
	createFile(xmlText, fileName)
	return xmlText
end
