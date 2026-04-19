if fs.exists("/ccr.lua") then
	--shell.run("/startup/000loadlib.lua")
	--for _,f in pairs(fs.list("/startup")) do
	--	if f~="000loadlib.lua" then shell.run("/startup/"..f) end
	--end
	print("CCRepo already installed. Skipping...")
	return
end

if http==nil then
	print("Your server settings do not allow the http library")
	print("CCRepo requires the http library")
	return false
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



print("Syncing with database")

-- Get gdb, Global DataBase
local response=http.get("https://github.com/TheJuiceFR/cc-repository/raw/main/repository.lua")
if not response then 
	print("No response from main database")
	return false
end
local gdb=response.readAll()
response.close()

local succ1, gdb = pcall(loadstring,gdb)
local succ2, gdb = pcall(gdb)
if not succ1 or not succ2 then
	print("Bad response from database")
	return false
end

local db = {}
-- Lookup each package in the gdb
-- build full db
for k,v in pairs(gdb) do
	local response=http.get(v.."/pkg")
	if not response then 
		print("No response from "..k.." database")
		return false
	end
	local sdb = response.readAll()
	response.close()
	
	local succ1, sdb = pcall(loadstring,sdb)
	local succ2, sdb = pcall(sdb)
	if not succ1 or not succ2 then
		print("Bad response from "..k.." database")
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

print("Initiating and testing database")

local dbf=fs.open("/cfg/ccr/db",'w')
dbf.write("local database=")
dbf.write(textutils.serialize(db))
dbf.write("\n\nreturn database")
dbf.close()

db=loadfile("/cfg/ccr/db")()


local ldb={}

print("Installing...")

download("ccinit", db)
download("ccr", db)
install("ccinit", ldb, true)
install("ccr", ldb)

print("Creating local database")

local f=fs.open("/cfg/ccr/ldb",'w')
f.write("local database=")
f.write(textutils.serialize(ldb))
f.write("\n\nreturn database")
f.close()

print("Installation complete!")
print("Rebooting...")
os.sleep(2)
os.reboot()
