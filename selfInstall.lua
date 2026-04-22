

if http==nil then
	print("Your server settings do not allow the http library")
	print("CCRepo requires the http library")
	return false
end



local function CsaveFile(path,value)
	local f=fs.open(path,'w')
	if not f then return false end
	f.write(textutils.serialize(value))
	f.close()
	return true
end

local function CloadFile(path)
	local f=fs.open(path,'r')
	if not f then return nil end
	local value = f.readAll()
	f.close()
	return textutils.deserialize(value)
end

local function wget(rootUrl, rootPath, filePath)
	local request = http.get(rootUrl..filePath)
	if not request then return false end
	local file = fs.open(rootPath..filePath,'w')
	if not file then return false end
	
	file.write(request.readAll())
	file.close()
	
	return true
end

local function wgetVar(url)
	local response = http.get(url)
	if not response then return nil, "No Response" end
	local out = response.readAll()
	response.close()
	
	local out = textutils.unserialize(out)
	if out == nil then return nil, "Bad Response" end
	
	return out
end

local function download(pkg, db) --download a package to /tmp/ccr, deleting an existing package if it was downloaded
	print("Downloading '"..pkg.."'")
	
	if not db[pkg] then
		error("'"..pkg.."' package does not exist.")
	end
	
	local tmpDir = "/tmp/ccr/"..pkg
	local downloadDir = db[pkg].url
	fs.delete(tmpDir)
	
	for k,v in pairs(db[pkg].provides) do
		if not wget(downloadDir, tmpDir, v) then 
			error("File '"..v.."' could not be downloaded")
		end
	end
	if not wget(downloadDir, tmpDir, "/pkg") then
		error("pkg file could not be downloaded")
	end
	
	return true
end

local function install(pkg, ldb, dep)
	local pkgPath = "/tmp/ccr/"..pkg
	if not fs.exists(pkgPath.."/pkg") then
		return false, "'"..pkg.."' package does not exist."
	end
	print("Installing '"..pkg.."'")
	
	local pkgInfo = loadfile(pkgPath.."/pkg")
	local succ, pkgInfo = pcall(pkgInfo)
	if not succ then error("Bad pkg file") end
	
	if type(pkgInfo.version) ~= "string" then pkgInfo.version = "0" end
	if type(pkgInfo.description) ~= "string" then pkgInfo.description = "No description provided." end
	if type(pkgInfo.provides) ~= "table" then pkgInfo.provides = {} end
	if type(pkgInfo.depends) ~= "table" then pkgInfo.depends = {} end
	if type(pkgInfo.optDepends) ~= "table" then pkgInfo.optDepends = {} end
	pkgInfo.explicit = not dep
	
	for k,v in pairs(pkgInfo.provides) do
		fs.delete(v)
		fs.move(pkgPath..v, v)
	end
	
	
	
	ldb[pkg]=pkgInfo
	return true
end


local repair = false
if fs.exists("/cfg/ccr/ldb") then
	--shell.run("/startup/000loadlib.lua")
	--for _,f in pairs(fs.list("/startup")) do
	--	if f~="000loadlib.lua" then shell.run("/startup/"..f) end
	--end
	print("CCRepo already installed. Repairing...")
	repair = true
end




print("Syncing with database")

-- Get gdb, Global DataBase
local gdb, failReason = wgetVar("https://github.com/TheJuiceFR/cc-repository/raw/main/repository.lua")
if not gdb then
	if verb>0 then print(failReason .. " from main database") end
	return false
end

-- Lookup each package in the gdb
-- build full db
local db = {}
for k,v in pairs(gdb) do
	local sdb, failReason = wgetVar(v.."/pkg")
	if not sdb then
		if verb>0 then print(failReason .. " from " .. k .. " package source") end
		return false
	end
	
	sdb.url = v
	if type(sdb.version) ~= "string" then sdb.version = "0" end
	if type(sdb.description) ~= "string" then sdb.description = "No description provided." end
	if type(sdb.provides) ~= "table" then sdb.provides = {} end
	if type(sdb.depends) ~= "table" then sdb.depends = {} end
	if type(sdb.optDepends) ~= "table" then sdb.optDepends = {} end
	
	db[k] = sdb
end

print("Saving database")
CsaveFile("/cfg/ccr/db",db)




local ldb
if repair then
	print("Loading existing install database")
	
	ldb = CloadFile("/cfg/ccr/ldb")
	
	if not succ then
		print("WARNING: existing local database corrupted")
		print("[C] Cancel repair\n[E] Erase existing database and continue")
		
		local response = ""
		print()
		repeat
			local x,y = term.getCursorPos()
			term.setCursorPos(1,y-1)
			term.clearLine()
			response = io.read()
		until response == "C" or response == "E"
		
		if response == "E" then
			ldb = {}
		else
			return
		end
	end
else
	ldb={}
end

print("Installing...")

download("ccr", db)
install("ccr", ldb)

print("Saving local database")
CsaveFile("/cfg/ccr/ldb",ldb)

if repair then
	print("Repair Complete!")
else
	print("Installation complete!")
end

shell.run("/startup/ccr.lua")
