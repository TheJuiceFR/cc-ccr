local tArgs={...}

local option=tArgs[1]

local function usageText()
print([[Usage: ccr <option> [arguments]
	ccr install <package1> [package2]...
		installs listed package(s)
	ccr remove <package1> [package2]...
		removes listed package(s)
	ccr purge <package1> [package2]..
		removes listed package(s) and it's config files
	ccr update
		updates all packages
	ccr info <package>
		gives info about package
	ccr list
		lists installed packages
	ccr listall
		lists all available packages
	ccr bootstrap [side/drive]
		bootstraps ccr onto disk in drive [side/drive]
]])
end


if option=="install" then
	if tArgs[2]==nil then
		print("No package name given")
		return
	end
	ccr.sync(1)
	
	tArgs[1]=nil
	for k,v in pairs(tArgs) do
		ccr.install(v,1)
	end
	ccr.clearCache(0)
elseif option=="remove" then
	if tArgs[2]==nil then
		print("No package name given")
		return
	end
	
	tArgs[1]=nil
	for k,v in pairs(tArgs) do
		ccr.remove(v,1)
	end
elseif option=="purge" then
	if tArgs[2]==nil then
		print("No package name given")
		return
	end
	
	tArgs[1]=nil
	for k,v in pairs(tArgs) do
		ccr.purge(v,1)
	end
elseif option=="update" then
	ccr.sync(0)
	
	local db=ccr.loaddb()
	local ldb=ccr.loadldb()
	
	for k,v in pairs(ldb) do
		if not db[k] then
			print("'"..k.."' is not in main database; skipping")
		elseif v.version~=db[k].version then
			print(k..": "..v.version.." > "..db[k].version)
			ccr.install(k)
		end
	end
elseif option=="info" then
	if tArgs[2]==nil then
		print("No package name given")
		return
	end
	ccr.sync(0)
	
	local db=ccr.loaddb()
	local ldb=ccr.loadldb()
	
	tArgs[1]=nil
	for k,v in pairs(tArgs) do
		if db[v] then
			print(v..":")
			print("version: "..db[v].version)
			print("description: "..db[v].description)
			if db[v].provides[1] then
				write("provides: ")
				for k2,v2 in pairs(db[v].provides) do
					write(v2..", ")
				end
				print("")
			end
			if db[v].depends[1] then
				write("requires: ")
				for k2,v2 in pairs(db[v].depends) do
					write(v2..", ")
				end
				print("")
			end
			if db[v].optDepends[1] then
				print("Optional packages: ")
				for k2,v2 in pairs(db[v].optDepends) do
					print(v2[1]..": "..v2[2])
				end
			end
		else
			print("'"..v"' is not in main database")
		end
		if ldb[v] and (db[v]==nil or ldb[v].version~=db[v].version) then
			print("local version: "..ldb[v].version)
		else
			print("'"..v.."' is not installed locally")
		end
	end
elseif option=="list" then
	local ldb=ccr.loadldb()
	
	for k,v in pairs(ldb) do
		print(k..":",v.version)
	end
	
elseif option=="listall" then
	ccr.sync(0)
	local db=ccr.loaddb()
	for k,v in pairs(db) do
		print(k..":",v.version)
	end
elseif option=="bootstrap" then
	local ldb=ccr.loadldb()
	local d
	if tArgs[2] then
		d=peripheral.wrap(tArgs[2])
		if d==nil then
			print("Drive not found")
			return
		end
	else
		d=peripheral.find("drive")
		if d==nil then
			print("No drive given, no drive found")
			return
		end
	end
	if d.getDiskID() then
		print("Floppy disk found. Bootstrap option is intended to be used on computers.")
		return
	end
	
	local m=d.getMountPath()
	if m==nil then
		print("Drive is empty")
		return
	end
	
	local items={"/ccr.lua","/startup/ccr.lua","/lib/ccr.lua","/lib/pack.lua","/startup/000loadlib.lua","/loadlib.lua"}
	for k,v in ipairs(items) do
		if pcall(fs.copy,v,m..v) then
			print("Copied "..v)
		else
			print(v.." not copied")
		end
	end
	print("Creating local database")
	local newldb={}
	newldb.ccr=ldb.ccr
	newldb.pack=ldb.pack
	newldb.ccinit=ldb.ccinit
	
	local f=fs.open(m.."/cfg/ccr/ldb",'w')
	f.write("local database=")
	f.write(textutils.serialize(newldb))
	f.write("\n\nreturn database")
	f.close()
	
	print("Bootstrapping complete")
else
	usageText()
end









