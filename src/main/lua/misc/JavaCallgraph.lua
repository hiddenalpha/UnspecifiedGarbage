
local SL = require("scriptlee")
local newJavaClassParser = SL.newJavaClassParser
local objectSeal = SL.objectSeal
SL = nil

local snk = io.stdout

local main


function initParser( app )
    app.parser = newJavaClassParser{
        cls = app,
        onMagic = function(m, app) assert(m == "\xCA\xFE\xBA\xBE") end,
        onClassfileVersion = function(maj, min, app) assert(maj == 55 and min == 0) end,
        onConstPoolClassRef = function(i, idx, app)
            app.constPool[i] = objectSeal{ type = "CLASS_REF", classNameIdx = idx, className = false, }
        end,
        onConstPoolIfaceMethodRef = function(i, nameIdx, nameAndTypeIdx, app)
            app.constPool[i] = objectSeal{
                type = "IFACE_METHOD_REF", nameIdx = nameIdx, nameAndTypeIdx = nameAndTypeIdx,
                className = false, methodName = false, methodType = false,
            }
        end,
        onConstPoolMethodRef = function(i, classIdx, nameAndTypeIdx, app)
            app.constPool[i] = objectSeal{
                type = "METHOD_REF", classIdx = classIdx, nameAndTypeIdx = nameAndTypeIdx,
                className = false, methodName = false, signature = false,
            }
        end,
        onConstPoolMethodType = function(i, descrIdx, app)
            app.constPool[i] = objectSeal{
                type = "METHOD_TYPE", descrIdx = descrIdx, descrStr = false,
            }
        end,
        onConstPoolNameAndType = function(i, nameIdx, typeIdx, app)
            app.constPool[i] = objectSeal{
                type = "NAME_AND_TYPE", nameIdx = nameIdx, typeIdx = typeIdx, nameStr = false, typeStr = false,
            }
        end,
        onConstPoolUtf8 = function(i, str, app)
            app.constPool[i] = objectSeal{ type = "UTF8", str = str, }
        end,

        onConstPoolInvokeDynamic = function(i, bootstrapMethodAttrIdx, nameAndTypeIdx, app)
            app.constPool[i] = objectSeal{
                type = "INVOKE_DYNAMIC", bootstrapMethodAttrIdx = bootstrapMethodAttrIdx, nameAndTypeIdx = nameAndTypeIdx,
                methodName = false, methodType = false, factoryClass = false, factoryMethod = false, factoryType = false,
            }
        end,
        onConstPoolFieldRef = function(i, nameIdx, nameAndTypeIdx, that)
            app.constPool[i] = objectSeal{
                type = "FIELD_REF", nameIdx = nameIdx, nameAndTypeIdx = nameAndTypeIdx,
                className = false, methodName = false, methodType = false,
            }
        end,
        --onConstPoolMethodHandle = function(i, refKind, refIdx, app)
        --    app.constPool[i] = objectSeal{ type = "METHOD_HANDLE", refKind = refKind, refIdx = refIdx, }
        --end,
        --onConstPoolStrRef = function(i, dstIdx, app)
        --    print("ConstPool["..i.."] <StrRef> #"..dstIdx)
        --end,
        --onThisClass = function(nameIdx, app)
        --    -- TODO print("onThisClass(#"..nameIdx..")")
        --end,
        --onField = function(iField, accessFlags, nameIdx, descrIdx, numAttrs, app)
        --    print(string.format("onField(0x%04X, #%d, #%d, %d)",accessFlags,nameIdx,descrIdx,numAttrs))
        --end,
        --onMethod = function(accessFlags, nameIdx, descrIdx, app)
        --    print(string.format("onMethod(0x%04X, #%d, #%d)",accessFlags,nameIdx,descrIdx))
        --end,

        onConstPoolEnd = function( app )
            -- 1st run
            for i, cpe in pairs(app.constPool) do
                if false then
                elseif cpe.type == "CLASS_REF" then
                    local tmp
                    tmp = assert(cpe.classNameIdx)
                    tmp = assert(app.constPool[cpe.classNameIdx], cpe.classNameIdx)
                    tmp = assert(tmp.str, tmp)
                    cpe.className = assert(tmp)
                elseif cpe.type == "METHOD_TYPE" then
                    cpe.descrStr = assert(app.constPool[cpe.descrIdx].str)
                elseif cpe.type == "NAME_AND_TYPE" then
                    cpe.nameStr = assert(app.constPool[cpe.nameIdx].str);
                    cpe.typeStr = assert(app.constPool[cpe.typeIdx].str);
                end
            end
            -- 2nd run
            for i, cpe in pairs(app.constPool) do
                if false then
                elseif cpe.type == "FIELD_REF" then
                    local nameAndType = assert(app.constPool[cpe.nameAndTypeIdx])
                    cpe.className = assert(app.constPool[cpe.nameIdx].className);
                    cpe.methodName = assert(app.constPool[nameAndType.nameIdx].str);
                    cpe.methodType = assert(app.constPool[nameAndType.typeIdx].str);
                elseif cpe.type == "METHOD_REF" then
                    local nameAndType = app.constPool[cpe.nameAndTypeIdx]
                    cpe.className = assert(app.constPool[cpe.classIdx].className)
                    cpe.methodName = assert(app.constPool[nameAndType.nameIdx].str)
                    cpe.signature = assert(app.constPool[nameAndType.typeIdx].str)
                elseif cpe.type == "IFACE_METHOD_REF" then
                    local classRef = assert(app.constPool[cpe.nameIdx])
                    local nameAndType = assert(app.constPool[cpe.nameAndTypeIdx])
                    cpe.className = assert(classRef.className)
                    cpe.methodName = assert(app.constPool[nameAndType.nameIdx].str)
                    cpe.methodType = assert(app.constPool[nameAndType.typeIdx].str)
                elseif cpe.type == "INVOKE_DYNAMIC" then
                    local nameAndType = assert(app.constPool[cpe.nameAndTypeIdx])
                    local bootstrapMethod = assert(app.constPool[cpe.bootstrapMethodAttrIdx], cpe.bootstrapMethodAttrIdx);
                    cpe.methodName = assert(app.constPool[nameAndType.nameIdx].str)
                    cpe.methodType = assert(app.constPool[nameAndType.typeIdx].str)
                    --cpe.factoryClass = ;
                    --cpe.factoryMethod = ;
                    --cpe.factoryType = ;
                end
            end
            -- debug-print
            snk:write("\n")
            for _,cpIdx in pairs{ 13, 14, 15, 227, 230, 236, 704, 709, 717 }do
                snk:write("CONST_POOL @ ".. cpIdx .."\n")
                for k,v in pairs(app.constPool[cpIdx])do print("X",k,v)end
            end
            for i, cpe in pairs(app.constPool) do
                if false then
                --elseif cpe.type == "CLASSREF" then
                --    snk:write("CLASS \"".. cpe.className .."\"\n")
                end
            end
        end,
    }
end


function main()
    local app = objectSeal{
        parser = false,
        constPool = {},
    }

    initParser(app)

    -- Read 1st arg as a classfile and pump it into the parser.
    local src = arg[1] and io.open( arg[1], "rb" ) or nil
    if not src then
        print("ERROR: Failed to open file from 1st arg: "..(arg[1]or"nil")) return
    end
    while true do
        local buf = src:read(8192)
        if not buf then break end
        app.parser:write(buf)
    end
    app.parser:closeSnk()
end


main()
