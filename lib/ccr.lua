local ccr = {}


-------------------------------
---     local functions     ---

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
	return textutils.unserialize(value)
end

local function saveldb(ldb)
	return CsaveFile("/cfg/ccr/ldb",ldb)
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

local function wgetVar(url)
	local response = http.get(url)
	if not response then return nil, "No Response" end
	local out = response.readAll()
	response.close()
	
	local out = textutils.unserialize(out)
	if out == nil then return nil, "Bad Response" end
	
	return out
end

---     local functions     ---
-------------------------------
---     query functions     ---

function ccr.loaddb()
	local f = CloadFile("/cfg/ccr/db")
	if f then
		return f
	else
		ccr.sync()
		f = CloadFile("/cfg/ccr/db")
		if f then 
			return f
		else
			return {}
		end
	end
end

function ccr.loadldb()
	local f = CloadFile("/cfg/ccr/ldb")
	if f then 
		return f
	else
		return {}
	end
end

function ccr.resolve(verb)	--determines what packages need updating.
	if type(verb) ~= "number" then verb = 0 end
	if verb>0 then print("Finding old packages") end
	local db=ccr.loaddb()
	local ldb=ccr.loadldb()
	local out={}
	
	for k,v in pairs(ldb) do
		if db[k] and v.version~=db[k].version then
			table.insert(out, k)
		end
	end
	
	return out
end

---     query functions     ---
-------------------------------
---     action functions    ---

function ccr.clearCache(verb)
	if type(verb) ~= "number" then verb = 0 end
	if verb>0 then print("Clearing cache") end
	fs.delete("/tmp/ccr")
	return true
end

function ccr.sync(verb)
	if type(verb) ~= "number" then verb = 0 end
	if verb >= 2 then print("Syncing with database") end
	
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
	
	return CsaveFile("/cfg/ccr/db",db)
end

function ccr.download(pkg,verb) --download a package to /tmp/ccr, deleting an existing package if it was downloaded
	if type(verb) ~= "number" then verb = 0 end
	if verb>0 then print("Downloading '"..pkg.."'") end
	
	local db=ccr.loaddb()
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

function ccr.install(pkg,verb,dep)	--installs or upgrades a single package.
	if type(verb) ~= "number" then verb = 0 end
	
	local ldb=ccr.loadldb()										--	[verb] sets level of verbosity	
	local pkgPath = "/tmp/ccr/"..pkg							--		0:slient 1:succinct 2:verbose
	if not fs.exists(pkgPath.."/pkg") then						--	[dep] declares the package as a dependency.
		return false, "'"..pkg.."' package does not exist."
	end
	if verb>0 then print("Installing '"..pkg.."'") end
	
	local pkgInfo = CloadFile(pkgPath.."/pkg")
	if not pkgInfo then return false, "Bad pkg file" end
	
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

function ccr.remove(pkg,verb,force)			--removes a package
	if type(verb) ~= "number" then verb = 0 end
	local ldb=ccr.loadldb()					--	[force] forces a dependency to be removed
	if not ldb[pkg] then
		return false, "'"..pkg.."' package is not installed."
	end
	if not force then
		for k,v in pairs(ldb) do
			for k2,v2 in pairs(v.depends) do
				if v2==pkg then return false, "'"..pkg.."' is required by '"..k.."'" end
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

function ccr.installTree(pkg, verb)						--Downloads and installs a package and it's dependancy tree
	if type(verb) ~= "number" then verb = 0 end		--Add an [asNeeded] string to install this package as a dep of asNeeded
	local neededDeps = {}
	local db = ccr.loaddb()
	local ldb = ccr.loadldb()
	if verb > 0 then print("Installing '"..pkg.."' with dependancies") end
	
	succ, res = depTree(pkg,db,neededDeps)
	if not succ then return false, res end
	
	for k,v in pairs(ldb) do neededDeps[k] = nil end	--Remove already installed programs from list
	
	succ, res = ccr.download(pkg, verb-1)
	if not succ then return false, pkg..": "..res end
	for k,v in pairs(neededDeps) do
		succ, res = ccr.download(k, verb-1)
		if not succ then return false, k..": "..res end
	end
	
	succ, res = ccr.install(pkg, verb-1, false)
	if not succ then return false, pkg..": "..res end
	for k,v in pairs(neededDeps) do
		succ, res = ccr.install(k, verb-1, true)
		if not succ then return false, k..": "..res end
	end
	
	return true
end

function ccr.purge(pkg,verb) --Purges any files related to <pkg>
	if type(verb) ~= "number" then verb = 0 end
	if verb>0 then print("purging '"..pkg.."'") end
	local db=ccr.loaddb()
	local ldb=ccr.loadldb()
	
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

--[[function autoremove()		--removes all uneeded dependencies

end]]

---     action functions    ---
-------------------------------

return ccr
