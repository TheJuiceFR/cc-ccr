


-------------------------------
---     local functions     ---

local function saveldb(ldb)
	local f=fs.open("/cfg/ccr/ldb",'w')
	f.write("local database=")
	f.write(textutils.serialize(ldb))
	f.write("\n\nreturn database")
	f.close()
	return true
end

--Downloads a file from rootUrl..filePath
--Stores it in rootPath..filePath
local function wget(rootUrl, rootPath, filePath)
	local request = http.get(rootUrl..filePath)
	if not request then return false end
	local file = fs.open(rootPath..filePath,'w')
	if not file then return false end
	
	file.write(request.readAll())
	file.close()
	
	return true
end

---     local functions     ---
-------------------------------
---     query functions     ---

function loaddb()
	local succ, f = pcall(loadfile("/cfg/ccr/db"))
	if succ then 
		return f
	else
		sync()
		local succ, f = pcall(loadfile("/cfg/ccr/db"))
		if succ then 
			return f
		else
			return {}
		end
	end
end

function loadldb()
	local succ, f = pcall(loadfile("/cfg/ccr/ldb"))
	if succ then 
		return f
	else
		return {}
	end
end

function resolve(pkg,verb)	--determines what packages need updating.
	if type(verb) ~= "number" then verb = 0 end
	if verb>0 then print("Finding old packages") end
	local db=loaddb()
	local ldb=loadldb()
	local out={}
	
	for k,v in pairs(ldb) do
		if db[k] and v.version~=db[k].version then
			out[#out+1]=k
		end
	end
	
	return out
end

---     query functions     ---
-------------------------------
---     action functions    ---

function clearCache(verb)
	if type(verb) ~= "number" then verb = 0 end
	if verb>0 then print("Clearing cache") end
	fs.delete("/tmp/ccr")
	return true
end

function sync(verb)
	if type(verb) ~= "number" then verb = 0 end
	if verb>0 then print("Syncing with database") end
	
	-- Get gdb, Global DataBase
	local response=http.get("https://github.com/TheJuiceFR/cc-repository/raw/main/repository.lua")
	if not response then 
		if verb>0 then print("No response from main database") end
		return false
	end
	local gdb=response.readAll()
	response.close()
	
	local succ1, gdb = pcall(loadstring,gdb)
	local succ2, gdb = pcall(gdb)
	if not succ1 or not succ2 then
		if verb>0 then print("Bad response from database") end
		return false
	end
	
	local db = {}
	-- Lookup each package in the gdb
	-- build full db
	for k,v in pairs(gdb) do
		local response=http.get(v.."/pkg")
		if not response then 
			if verb>0 then print("No response from "..k.." database") end
			return false
		end
		local sdb = response.readAll()
		response.close()
		
		local succ1, sdb = pcall(loadstring,sdb)
		local succ2, sdb = pcall(sdb)
		if not succ1 or not succ2 then
			if verb>0 then print("Bad response from "..k.." database") end
			return false
		end
		
		sdb.url = v
		
		db[k] = sdb
	end
	
	local dbf=fs.open("/cfg/ccr/db",'w')
	dbf.write("local database=")
	dbf.write(textutils.serialize(db))
	dbf.write("\n\nreturn database")
	dbf.close()
	
	return true
end

function download(pkg,verb) --download a package to /tmp/ccr, deleting an existing package if it was downloaded
	if type(verb) ~= "number" then verb = 0 end
	if verb>0 then print("Downloading '"..pkg.."'") end
	
	local db=loaddb()
	if not db[pkg] then
		return false, "'"..pkg.."' package does not exist."
	end
	
	local tmpDir = "/tmp/ccr/"..pkg
	local downloadDir = db[pkg].url
	fs.delete(tmpDir)
	
	for k,v in pairs(db[pkg].provides) do
		if not wget(downloadDir, tmpDir, v) then return false, "File '"..v.."' could not be downloaded" end
	end
	if not wget(downloadDir, tmpDir, "/pkg") then return false, "pkg file could not be downloaded" end
	
	return true
end

function install(pkg,verb,dep)	--installs or upgrades a single package.
	if type(verb) ~= "number" then verb = 0 end
	
	local ldb=loadldb()										--	[verb] sets level of verbosity	
	local pkgPath = "/tmp/ccr/"..pkg							--		0:slient 1:succinct 2:verbose
	if not fs.exists(pkgPath.."/pkg") then						--	[dep] declares the package as a dependency.
		return false, "'"..pkg.."' package does not exist."
	end
	if verb>0 then print("Installing '"..pkg.."'") end
	
	local pkgInfo = loadfile(pkgPath.."/pkg")
	local succ, pkgInfo = pcall(pkgInfo)
	if not succ then return false, "Bad pkg file" end
	
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
	saveldb(ldb)
	return true
end

function remove(pkg,verb,force)			--removes a package
	if type(verb) ~= "number" then verb = 0 end
	local ldb=loadldb()					--	[force] forces a dependency to be removed
	if not ldb[pkg] then
		return false, "'"..pkg.."' package is not installed."
	end
	if not force then
		for k,v in pairs(ldb) do
			for k2,v2 in pairs(v.depends) do
				if v2==pkg then return false, "'"..pkg.."' is required by '"..v.."'" end
			end
		end
	end
	if verb>0 then print("Removing '"..pkg.."'") end
	for k,v in pairs(ldb[pkg].provides) do
		fs.delete(v)
		fs.delete(v..".lua")
	end
	
	ldb[pkg]=nil
	saveldb(ldb)
	return true
end

local function depTree(pkg,db,out) --accessory function of installTree. Creates a list of recursive dependancies of <pkg>.
	if not db[pkg] or type(db[pkg].depends) ~= "table" then return false, "Package '"..pkg.."' does not exist in db" end
	for k,v in pairs(db[pkg].depends) do
		out[v] = true
		succ, res =  depTree(v,db,out)
		if not succ then return false, res end
	end
	return true
end

function installTree(pkg, verb)						--Downloads and installs a package and it's dependancy tree
	if type(verb) ~= "number" then verb = 0 end		--Add an [asNeeded] string to install this package as a dep of asNeeded
	local neededDeps = {}
	local db = loaddb()
	local ldb = loadldb()
	if verb > 0 then print("Installing '"..pkg.."' with dependancies") end
	
	succ, res = depTree(pkg,db,neededDeps)
	if not succ then return false, res end
	
	for k,v in pairs(ldb) do neededDeps[k] = nil end	--Remove already installed programs from list
	
	succ, res = download(pkg, verb-1)
	if not succ then return false, pkg..": "..res end
	for k,v in pairs(neededDeps) do
		succ, res = download(k, verb-1)
		if not succ then return false, k..": "..res end
	end
	
	succ, res = install(pkg, verb-1, false)
	if not succ then return false, pkg..": "..res end
	for k,v in pairs(neededDeps) do
		succ, res = install(k, verb-1, true)
		if not succ then return false, k..": "..res end
	end
	
end

function purge(pkg,verb) --Purges any files related to <pkg>
	if type(verb) ~= "number" then verb = 0 end
	if verb>0 then print("purging '"..pkg.."'") end
	local db=loaddb()
	local ldb=loadldb()
	
	if ldb[pkg] then
		for k,v in pairs(ldb[pkg].provides) do
			fs.delete("/cfg/"..v)
			fs.delete("/tmp/"..v)
			fs.delete("/var/"..v)
			fs.delete("/home/.config/"..v)
			fs.delete("/home/"..v)
			fs.delete("/home/."..v)
		end
	end
	if db[pkg] then
		for k,v in pairs(db[pkg].provides) do
			fs.delete("/cfg/"..v)
			fs.delete("/tmp/"..v)
			fs.delete("/var/"..v)
			fs.delete("/home/.config/"..v)
			fs.delete("/home/"..v)
			fs.delete("/home/."..v)
		end
	end
	
	return true
end

--[[function repair(pkg,verb,recurse)	--force removes a package and reinstalls, optionally repairs dependancy tree as well, recursively
	
end]]

--[[function repairAll(verb)			--repairs all packages one by one
	
end]]

--[[function autoremove()		--removes all uneeded dependencies

end]]

---     action functions    ---
-------------------------------
