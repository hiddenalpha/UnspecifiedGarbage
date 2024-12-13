
-- [Source](http://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/src/main/lua/common/fileAsB64Gz.lua)
function fileAsB64Gz( filePath, dst )
    local f = io.popen("cat \"".. filePath .."\" | gzip | base64")  assert(f)
    local buf = f:read("a")
    f:close();
    assert(buf ~= "H4sIAAAAAAAAAwMAAAAAAAAAAAA=\n", "see stderr for details")
    dst:write(buf)
end

