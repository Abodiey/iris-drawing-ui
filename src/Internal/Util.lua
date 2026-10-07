local Util = {}
function Util.clamp(n, a, b) return math.max(a, math.min(b, n)) end
function Util.number(n, name)
    assert(type(n) == 'number' and n == n and math.abs(n) < math.huge, name .. ' must be finite')
    return n
end
function Util.copy(v)
    if typeof(v) ~= 'table' then return v end
    local result = {}
    for k, item in pairs(v) do result[k] = Util.copy(item) end
    return result
end
function Util.equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end
    for k, v in pairs(a) do if not Util.equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
function Util.string(s, name)
    assert(type(s) == 'string', name .. ' must be a string')
    assert(utf8.len(s), name .. ' must be valid UTF-8')
    return s
end
function Util.clean(s, limit)
    s = Util.string(s, 'Text'):gsub('[%c]', ' ')
    local length = utf8.len(s)
    if length > limit then s = s:sub(1, utf8.offset(s, limit + 1) - 1) end
    return s
end
function Util.prefix(s, length)
    if length <= 0 then return '' end
    return s:sub(1, (utf8.offset(s, length + 1) or (#s + 1)) - 1)
end
function Util.rect(x, y, w, h) return {x=x, y=y, w=w, h=h} end
function Util.intersect(a, b)
    if not b then return a end
    local x, y = math.max(a.x, b.x), math.max(a.y, b.y)
    local right, bottom = math.min(a.x+a.w,b.x+b.w), math.min(a.y+a.h,b.y+b.h)
    if right <= x or bottom <= y then return nil end
    return Util.rect(x,y,right-x,bottom-y)
end
function Util.inside(r, p)
    return r and p.X >= r.x and p.Y >= r.y and p.X < r.x+r.w and p.Y < r.y+r.h
end
function Util.contains(a, b)
    return not b or (a.x >= b.x and a.y >= b.y and a.x+a.w <= b.x+b.w and a.y+a.h <= b.y+b.h)
end
function Util.safe(callback, ...)
    if callback then
        local ok, message = pcall(callback, ...)
        if not ok then warn('[Iris Drawing callback] ' .. tostring(message)) end
    end
end
function Util.options(list)
    assert(type(list) == 'table', 'Options must be an array')
    local result, seen = {}, {}
    for key in pairs(list) do assert(type(key)=='number' and key%1==0 and key>=1 and key<=#list, 'Options must be a dense array') end
    assert(#list <= 500, 'Options supports at most 500 items')
    for i, name in ipairs(list) do
        Util.string(name, 'Option')
        assert(#name > 0 and not seen[name], 'Options must be unique nonempty strings')
        result[i], seen[name] = name, true
    end
    return result
end
function Util.live(ui) assert(not ui._destroyed, 'Iris Drawing has been destroyed') end
return Util
