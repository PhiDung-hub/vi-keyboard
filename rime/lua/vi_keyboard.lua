local telex = require('vi_telex')
local english = telex.word_set(require('vi_english'))
local accepted, noop = 1, 2
local limit = 64

local function render(input, force)
  if not force and english[input:lower()] then return input end
  return telex.convert(input)
end

local function processor(key, env)
  if key:release() then return noop end
  local context = env.engine.context
  local code = key.keycode
  if (code >= 0xffe1 and code <= 0xffee) or code == 0xfe03 or code == 0xff7e then return noop end
  local input = context.input
  local ascii_mode = context:get_option('ascii_mode')
  if code == 0x20 and key:ctrl() and key:shift() and not (key:alt() or key:super()) then
    if input ~= '' then env.engine:commit_text(render(input)) end
    context:clear()
    context:set_option('_vi_long_token', false)
    context:set_option('ascii_mode', not ascii_mode)
    return accepted
  end
  if ascii_mode then return noop end
  local shortcut = key:ctrl() or key:alt() or key:super()
  local character = code < 128 and string.char(code)
  if not shortcut and character and character:match('[A-Za-z0-9_]') then
    if #input >= limit then
      env.engine:commit_text(input .. character)
      context:clear()
      context:set_option('_vi_long_token', true)
    elseif not context:get_option('_vi_long_token') then
      context:push_input(character)
    else
      return noop
    end
    return accepted
  end
  context:set_option('_vi_long_token', false)
  if input == '' then return noop end
  if not shortcut and code == 0xff08 then
    context:pop_input(1)
    return accepted
  end
  if not shortcut and code == 0xff1b then
    context:clear()
    return accepted
  end
  if not shortcut and code >= 0x20 and code < 0x7f then
    env.engine:commit_text(render(input, code == 0x20 and key:shift()) .. character)
    context:clear()
    return accepted
  end
  env.engine:commit_text(render(input))
  context:clear()
  return noop
end

local function translator(input, segment)
  local text = render(input)
  local candidate = Candidate('vi_telex', segment.start, segment._end, text, '')
  candidate.preedit = text
  yield(candidate)
end

return {processor = processor, translator = translator}
