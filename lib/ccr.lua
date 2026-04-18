


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

---     local functions     ---
-------------------------------
---     global functions    ---

function loaddb()
	local f=loadfile("/cfg/ccr/db")
	if f then 
		return f()
	end
	sync()
	local f=loadfile("/cfg/ccr/db")
	if f then 
		return f()
	else
		return {}
	end
end

function loadldb()
	local f=loadfile("/cfg/ccr/ldb")
	if f then 
		return f()
	else
		return {}
	end
end

function clearCache(verb)
	if verb and verb>0 then print("Clearing cache") end
	fs.delete("/tmp/ccr")
	return true
end

function sync(verb)
	if verb and verb>0 then print("Syncing with database") end
	local response=http.get("https://github.com/TheJuiceFR/CCRepo/raw/main/database")
	if not response then return false end
	local dbf=fs.open("/cfg/ccr/db",'w')
	repeat
		local rl=response.read(20)
		if rl then dbf.write(rl) end
	until rl==nil
	dbf.close()
	return true
end

function resolve(pkg,verb)	--determines what packages need updating.
	if verb and verb>0 then print("Finding old packages") end
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

function install(pkg,verb,dep)	--installs or upgrades a package.
	assert(pack~=nil,"Pack API not loaded")
	local db=loaddb()			--	[verb] sets level of verbosity
	local ldb=loadldb()			--		0:slient 1:succinct 2:verbose
	if not db[pkg] then			--	[dep] declares the package as a dependency.
		return false, "'"..pkg.."' package does not exist."
	end
	if verb and verb>1 then print("Preparing to install '"..pkg.."'") end
	
	for k,v in pairs(db[pkg].depends) do
		if not ldb[v] then
			if not install(v,verb,true) then return false, "Dependency '"..v.."' could not be installed." end
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
	
	remove(pkg,verb and verb-1,true)
	
	if verb and verb>0 then print("installing '"..pkg.."'") end
	pack.packdown(path,"/")
	
	ldb[pkg]=db[pkg]
	ldb[pkg].explicit=not dep
	saveldb(ldb)
	return true
end

function remove(pkg,verb,force)			--removes a package
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
	if verb and verb>0 then print("Removing '"..pkg.."'") end
	for k,v in pairs(ldb[pkg].provides) do
		fs.delete(v)
		fs.delete(v..".lua")
	end
	
	ldb[pkg]=nil
	saveldb(ldb)
	return true
end

function purge(pkg,verb)
	if verb and verb>0 then print("purging '"..pkg.."'") end
	local db=loaddb()
	local ldb=loadldb()
	
	if ldb[pkg] then
		for k,v in pairs(ldb[pkg].provides) do
			fs.delete("/cfg/"..v)
			fs.delete("/home/.config/"..v)
			fs.delete("/home/"..v)
			fs.delete("/home/."..v)
		end
	end
	if db[pkg] then
		for k,v in pairs(db[pkg].provides) do
			fs.delete("/cfg/"..v)
			fs.delete("/home/.config/"..v)
			fs.delete("/home/"..v)
			fs.delete("/home/."..v)
		end
	end
	
	remove(pkg)
	return true
end

--[[function autoremove()		--removes all uneeded dependencies

end]]

---     global functions    ---
-------------------------------
