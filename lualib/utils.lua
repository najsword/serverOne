local M = {}

function M.Sleep(n)
    local t0 = os.clock()
    while os.clock() - t0 <= n do end
 end

function M.str_2_table(str)
    local func_str = "return "..str
    local func = load(func_str)
    return func()
end

local function serialize(obj)
    local lua = ""
    local t = type(obj)
    if t == "number" then
        lua = lua .. obj
    elseif t == "boolean" then
        lua = lua .. tostring(obj)
    elseif t == "string" then
        lua = lua .. string.format("%q", obj)
    elseif t == "table" then
        lua = lua .. "{"
        for k, v in pairs(obj) do
            lua = lua .. "[" .. serialize(k) .. "]=" .. serialize(v) .. ","
        end
        local metatable = getmetatable(obj)
        if metatable ~= nil and type(metatable.__index) == "table" then
            for k, v in pairs(metatable.__index) do  
                lua = lua .. "[" .. serialize(k) .. "]=" .. serialize(v) .. ","
            end
        end
        lua = lua .. "}"
    elseif t == "nil" then
        return "nil"
    elseif t == "userdata" then
        return "userdata"
    elseif t == "function" then
        return "function"
    elseif t == "thread" then
        return "thread"
    else
        error("can not serialize a " .. t .. " type.")
    end
    return lua
end

M.table_2_str = serialize

function M.print(o)
    print(serialize(o))
end

function M.printSky(o)
    --print(serialize(o))
    return serialize(o)
end

function M.print_array(o)
    local str = "{"
    for k,v in ipairs(o) do
        str = str .. serialize(v) .. ","
    end
    str = str .. "}"
    print(str)
end

function M.dump_table_2_file(tbl, name)
    local str = M.table_2_str(tbl)

    str = "return "..str
    local file = io.open(name, "w");
    file:write(str)
    file:close()
end

function M.copy_array(t)
    local tmp = {}
    for _,v in ipairs(t) do
        table.insert(tmp, v)
    end

    return tmp
end

--打印table
function M.print_r ( t )
    local print_r_cache={}
    local function sub_print_r(t,indent)
        if (print_r_cache[tostring(t)]) then
            print(indent.."*"..tostring(t))
        else
            print_r_cache[tostring(t)]=true
            if (type(t)=="table") then
                for pos,val in pairs(t) do
                    if (type(val)=="table") then
                        print(indent.."["..pos.."] => "..tostring(t).." {")
                        sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
                        print(indent..string.rep(" ",string.len(pos)+6).."}")
                    elseif (type(val)=="string") then
                        print(indent.."["..pos..'] => "'..val..'"')
                    else
                        print(indent.."["..pos.."] => "..tostring(val))
                    end
                end
            else
                print(indent..tostring(t))
            end
        end
    end
    if (type(t)=="table") then
        print(tostring(t).." {")
        sub_print_r(t,"  ")
        print("}")
    else
        sub_print_r(t,"  ")
    end
    print()
end

function M.removebyvalue(array, value, removeadll)
    --    deleteNum用于接收/返回删除个数; i/max 构成控制while循环
    local deleteNum,i,max=0,1,#array
    while i<=max do
        if array[i] == value then
            --    通过索引操作表的删除元素
            table.remove(array,i)
            --    标记删除次数
            deleteNum = deleteNum+1 
            i = i-1
            --    控制while循环操作
            max = max-1
            --    判断是否删除所有相同的value值
            if not removeadll then break end
        end
        i= i+1
    end
    --    返回删除次数
    return deleteNum
end

function M.SleepSleep(n)
    os.execute("sleep " .. n)
 end

return M
