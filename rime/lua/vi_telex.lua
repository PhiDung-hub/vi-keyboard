local function word_set(words)
  local set = {}
  for word in words:gmatch('%S+') do set[word] = true end
  return set
end

local onsets = word_set('b c ch d đ g gh gi h k kh l m n ng ngh nh p ph qu r s t th tr v x')
local front_only = word_set('gh ngh')
local back_only = word_set('c g ng')
local checked = word_set('c ch p t')
local rhymes = {}
for nucleus, codas in ([[
  a=- c ch m n ng nh p t; ă=c m n ng p t; â=c m n ng p t; e=- c m n ng p t; ê=- ch m n nh p t;
  i=- ch m n nh p t; o=- c m n ng p t; ô=- c m n ng p t; ơ=- m n p t; u=- c m n ng p t;
  ư=- c m n ng t; y=- ch nh t; iê=c m n ng p t; yê=m n t; uô=c m n ng t; ươ=c m n ng p t;
  oa=- c ch m n ng nh p t; oă=c m n ng t; oe=- n t; uâ=n ng t; uê=- ch n nh; uy=- ch n nh p t;
  uyê=n t; ai=-; ao=-; au=-; ay=-; âu=-; ây=-; eo=-; êu=-; ia=-; iêu=-; iu=-; oai=-; oao=-;
  oay=-; oeo=-; oi=-; ôi=-; ơi=-; ua=-; uây=-; ui=-; uôi=-; uơ=-; uya=-; uyu=-; ưa=-; ưi=-;
  ưu=-; ươi=-; ươu=-; yêu=-
]]):gmatch('(%S+)=([^;]+)') do
  rhymes[nucleus] = word_set(codas)
end
local circumflex = {a = 'â', e = 'ê', o = 'ô'}
local horn = {a = 'ă', o = 'ơ', u = 'ư', ['â'] = 'ă', ['ô'] = 'ơ'}
local plain = {['â'] = 'a', ['ă'] = 'a', ['ê'] = 'e', ['ô'] = 'o', ['ơ'] = 'o', ['ư'] = 'u', ['đ'] = 'd'}
local tone_keys = {s = 1, f = 2, r = 3, x = 4, j = 5}
local vowels = {
  a = {'á', 'à', 'ả', 'ã', 'ạ', 'Á', 'À', 'Ả', 'Ã', 'Ạ'},
  ['ă'] = {'ắ', 'ằ', 'ẳ', 'ẵ', 'ặ', 'Ắ', 'Ằ', 'Ẳ', 'Ẵ', 'Ặ'},
  ['â'] = {'ấ', 'ầ', 'ẩ', 'ẫ', 'ậ', 'Ấ', 'Ầ', 'Ẩ', 'Ẫ', 'Ậ'},
  e = {'é', 'è', 'ẻ', 'ẽ', 'ẹ', 'É', 'È', 'Ẻ', 'Ẽ', 'Ẹ'},
  ['ê'] = {'ế', 'ề', 'ể', 'ễ', 'ệ', 'Ế', 'Ề', 'Ể', 'Ễ', 'Ệ'},
  i = {'í', 'ì', 'ỉ', 'ĩ', 'ị', 'Í', 'Ì', 'Ỉ', 'Ĩ', 'Ị'},
  o = {'ó', 'ò', 'ỏ', 'õ', 'ọ', 'Ó', 'Ò', 'Ỏ', 'Õ', 'Ọ'},
  ['ô'] = {'ố', 'ồ', 'ổ', 'ỗ', 'ộ', 'Ố', 'Ồ', 'Ổ', 'Ỗ', 'Ộ'},
  ['ơ'] = {'ớ', 'ờ', 'ở', 'ỡ', 'ợ', 'Ớ', 'Ờ', 'Ở', 'Ỡ', 'Ợ'},
  u = {'ú', 'ù', 'ủ', 'ũ', 'ụ', 'Ú', 'Ù', 'Ủ', 'Ũ', 'Ụ'},
  ['ư'] = {'ứ', 'ừ', 'ử', 'ữ', 'ự', 'Ứ', 'Ừ', 'Ử', 'Ữ', 'Ự'},
  y = {'ý', 'ỳ', 'ỷ', 'ỹ', 'ỵ', 'Ý', 'Ỳ', 'Ỷ', 'Ỹ', 'Ỵ'},
}
local uppercase = {['â'] = 'Â', ['ă'] = 'Ă', ['ê'] = 'Ê', ['ô'] = 'Ô', ['ơ'] = 'Ơ', ['ư'] = 'Ư', ['đ'] = 'Đ'}

local function vowel_span(letters)
  local first
  for index, letter in ipairs(letters) do
    if vowels[letter] then
      first = first or index
    elseif first then
      return first, index - 1
    end
  end
  return first, #letters
end

local function pronounced_vowels(letters)
  local first, last = vowel_span(letters)
  if first == 2 and last > first then
    if (letters[1] == 'g' and letters[2] == 'i') or (letters[1] == 'q' and letters[2] == 'u') then
      first = first + 1
    end
  end
  return first, last
end

local function apply_horn(letters, first, last)
  if not first then return false end
  for index = last, first, -1 do
    local vowel = letters[index]
    if horn[vowel] then
      if vowel == 'o' and index > first and (letters[index - 1] == 'u' or letters[index - 1] == 'ư') then
        letters[index - 1] = 'ư'
      end
      letters[index] = horn[vowel]
      return true
    end
  end
  return false
end

local function tone_position(letters, first, last, coda)
  for index = last, first, -1 do
    if plain[letters[index]] then return index end
  end
  if first == last then return first end
  if coda ~= '' then return last end
  return last - 1
end

local function convert(raw)
  if not raw:match('^[A-Za-z]+$') then return raw end
  local letters, upper = {}, {}
  local tone = 0
  local previous
  for character in raw:gmatch('.') do
    local key = character:lower()
    local first, last = pronounced_vowels(letters)
    if key == 'd' and #letters == 1 and letters[1] == 'd' then
      letters[1] = 'đ'
    elseif first and tone_keys[key] then
      if tone == tone_keys[key] or (tone ~= 0 and not tone_keys[previous]) then return raw end
      tone = tone_keys[key]
    elseif circumflex[key] and previous == key and letters[#letters] == key then
      letters[#letters] = circumflex[key]
    elseif key == 'w' and apply_horn(letters, first, last) then
    elseif key == 'z' and first then
      local changed = tone ~= 0
      tone = 0
      for index, letter in ipairs(letters) do
        if plain[letter] then
          letters[index] = plain[letter]
          changed = true
        end
      end
      if not changed then return raw end
    else
      local leading_w = key == 'w' and #letters == 0
      letters[#letters + 1] = leading_w and 'ư' or key
      upper[#letters] = character ~= key
    end
    previous = key
  end

  local first, last = pronounced_vowels(letters)
  if not first then
    if #letters == 1 and letters[1] == 'đ' then return upper[1] and 'Đ' or 'đ' end
    return raw
  end
  local onset = table.concat(letters, '', 1, first - 1)
  local nucleus = table.concat(letters, '', first, last)
  local coda = table.concat(letters, '', last + 1)
  if onset == 'gi' and nucleus == 'ê' then onset, nucleus = 'g', 'iê' end
  if nucleus == 'ươ' and coda == '' and (onset == 'h' or onset == 'th') then
    nucleus = 'uơ'
    letters[first] = 'u'
  end
  local front = nucleus:match('^[ey]') or nucleus:match('^ê') or (nucleus:match('^i') and onset ~= 'g')
  local codas = rhymes[nucleus]
  if (onset ~= '' and not onsets[onset]) or (front and back_only[onset]) or (not front and front_only[onset])
      or not codas or not codas[coda == '' and '-' or coda]
      or (checked[coda] and tone ~= 1 and tone ~= 5) then
    if #letters == 1 and tone == 0 and plain[nucleus] then return upper[1] and uppercase[nucleus] or nucleus end
    return raw
  end

  local accent = tone ~= 0 and tone_position(letters, first, last, coda)
  for index, letter in ipairs(letters) do
    if index == accent then
      letters[index] = vowels[letter][tone + (upper[index] and 5 or 0)]
    elseif upper[index] then
      letters[index] = uppercase[letter] or letter:upper()
    end
  end
  return table.concat(letters)
end

return {convert = convert, word_set = word_set}
