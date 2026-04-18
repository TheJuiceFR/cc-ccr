if fs.exists("/ccr.lua") then
	shell.run("/startup/000loadlib.lua")
	for _,f in pairs(fs.list("/startup")) do
		if f~="000loadlib.lua" then shell.run("/startup/"..f) end
	end
	print("CCRepo already installed. Skipping...")
	return
end

local function parseTree(pack,outfil)
	repeat
		local out=pack.readLine()
		if out and out~="" then
			fs.makeDir(outfil.."/"..out)
		end
	until out==""
end

local function parseDump(pack,outfil)
	repeat
		local out=pack.read(1)
		local fil=""
		while out and out~=">" do
			fil=fil..out
			out=pack.read(1)
		end
		
		out=pack.read(1)
		local len=""
		while out and out~=">" do
			len=len..out
			out=pack.read(1)
		end
		len=tonumber(len)
		
		if type(len)=="number" then
			local ff=fs.open(outfil.."/"..fil,'w')
			for n=1,len do
				ff.write(pack.read(1))
			end
			ff.close()
		end
	until out==nil
end

function packdown(infil,outfil)
	assert(pcall(fs.makeDir,outfil),"Output path invalid")
	local pack=fs.open(infil,'r')
	assert(pack,"Pack file does not exist, or is inaccessable")
	
	assert(pcall(parseTree,pack,outfil),"Error parsing pack tree")
	assert(pcall(parseDump,pack,outfil),"Error parsing pack dump")
	
	pack.close()
end

local function install(pkg,verb,dep,db,ldb)
	if not db[pkg] then
		return false, "'"..pkg.."' package does not exist."
	end
	if verb and verb>1 then print("Preparing to install '"..pkg.."'") end
	
	for k,v in pairs(db[pkg].depends) do
		if not ldb[v] then
			if not install(v,verb,true,db,ldb) then return false, "Dependency '"..v.."' could not be installed." end
		end
	end
	
	if verb and verb>1 then print("Downloading '"..pkg.."'") end
	local path="/tmp/ccr/"..pkg.."_"..db[pkg].version..".pack"
	local response=http.get(db[pkg].package)
	if not response then return false,"Error retrieving '"..pkg.."' package from \""..db[pkg].package..'"' end
	
	local f=fs.open(path,'w')
	repeat
		local rl=response.read(20)
		if rl then f.write(rl) end
	until rl==nil
	f.close()
	
	if verb and verb>0 then print("installing '"..pkg.."'") end
	packdown(path,"/")
	
	ldb[pkg]=db[pkg]
	ldb[pkg].explicit=not dep
	return true
end

if http==nil then
	print("Your server settings do not allow the http library")
	print("CCRepo requires the http library")
	return false
end

print("Creating database file")
local response=http.get("https://github.com/TheJuiceFR/CCRepo/raw/main/database")
if not response then
	print("Cannot retrieve database file")
	return false
end
local dbf=fs.open("/cfg/ccr/db",'w')
repeat
	local rl=response.read(20)
	if rl then dbf.write(rl) end
until rl==nil
dbf.close()
local db=loadfile("/cfg/ccr/db")()
local ldb={}

install("ccr",3,false,db,ldb)

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
