
-- [source](https://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/lua/common/wrap.lua)
-- Very primitive, but works. So who cares, please write it yourself..
function wrap72( str )
    str = str
        :gsub("(........................................................................)", "%1\n")
        :gsub("\n$", "")
    if str:byte(str:len()) ~= 0x10 then str = str.."\n" end
    return str
end

