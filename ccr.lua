local tArgs={...}
local ccr = require("/lib/ccr")

local option=tArgs[1]

local function usageText()

end


if option=="install" then
	if tArgs[2]==nil then
		print("No package name given")
		return
	end
	if not ccr.sync(2) then print("Bad response from database"); return end
	
	local needed = ccr.resolve(0)
	if #needed ~= 0 then
		print("Some packages need to be updated first; running an update for you..")
		shell.run("ccr update")
	end
	
	tArgs[1]=nil
	for k,v in pairs(tArgs) do
		local succ, reason = ccr.installTree(v,2) --TODO doesn't work properly when a needed dependancy is only installed locally
		if not succ then print(reason) end
	end
	ccr.clearCache(0)
	shell.run("/startup/ccr.lua")
elseif option=="remove" then
	if tArgs[2]==nil then
		print("No package name given")
		return
	end
	
	tArgs[1]=nil
	for k,v in pairs(tArgs) do
		local succ, reason = ccr.remove(v,1)
		if not succ then print(reason) end
	end
	shell.run("/startup/ccr.lua")
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
	if not ccr.sync(2) then print("Bad response from database"); return end
	
	local needed = ccr.resolve(1) --TODO Add check for dependancies added in updates
	local ldb = ccr.loadldb()
	
	if #needed == 0 then
		print("All up-to-date!")
		return
	end
	
	print("Packages to be updated:")
	for _,package in pairs(needed) do
		write(package)
		write(", ")
	end
	print()
	print("Continue with installation [y/n]?")
	repeat
		local _, key = os.pullEvent("key")
		if key == 49 then os.sleep(1); return end
	until key == 21
	
	for k,v in pairs(needed) do
		succ, res = ccr.download(v, 1)
		if not succ then return false, v..": "..res end
	end
	
	for k,v in pairs(needed) do
		succ, res = ccr.install(v, 1, not ldb[v].explicit)
		if not succ then return false, v..": "..res end
	end
	
	--TODO Autoremove unneeded deps
	print("All done!")
	ccr.clearCache(0)
	shell.run("/startup/ccr.lua")
elseif option=="info" then	--TODO option doesn't give info about local-only packages
	if tArgs[2]==nil then	--TODO tab completion doesn't show local-only packages
		print("No package name given") --TODO Doesn't filter input, throws error when unknown package names are given
		return
	end
	ccr.sync(2)
	
	local db=ccr.loaddb()
	local ldb=ccr.loadldb()
	
	tArgs[1]=nil
	for k,v in pairs(tArgs) do
		local entry
		local localPkg = false
		local filePkg = false
		if db[v] then
			entry = db[v]
		elseif fs.isDir(v) then
			local f=fs.open(fs.combine(v,"pkg"),'r')
			local value
			if f then
				value = f.readAll()
				f.close()
			end
			
			if value then entry = textutils.unserialize(value) end
			
			if entry then
				if type(entry.version) ~= "string" then entry.version = "Unspecified" end
				if type(entry.description) ~= "string" then entry.description = "No description provided." end
				if type(entry.provides) ~= "table" then entry.provides = {} end
				if type(entry.depends) ~= "table" then entry.depends = {} end
				if type(entry.optDepends) ~= "table" then entry.optDepends = {} end
				v = fs.getName(v)
				filePkg = true
			end
		end
		if not entry and ldb[v] then
			entry = ldb[v]
			localPkg = true
		end
		
		if entry then
			write(">> '"..v.."'")
			if localPkg then write("(Local Package)") end
			if filePkg then write("(File Package)") end
			print(":")
			
			print("Version: "..entry.version)
			print("Description: "..entry.description)
			if entry.provides[1] then
				write("Provides: ")
				for k2,v2 in pairs(entry.provides) do
					write(v2..", ")
				end
				print("")
			end
			if entry.depends[1] then
				write("Requires: ")
				for k2,v2 in pairs(entry.depends) do
					write(v2..", ")
				end
				print("")
			end
			if entry.optDepends[1] then
				print("Optional packages: ")
				for k2,v2 in pairs(entry.optDepends) do
					print("\7"..v2[1]..": "..v2[2])
				end
			end
			if not localPkg then
				local LVersion = "[not installed]"
				if ldb[v] then LVersion = ldb[v].version end
				print("local version: "..LVersion)
			end
		else
			print(">> '"..v.."': does not exist.")
		end
	end
elseif option=="list" then
	local ldb=ccr.loadldb()
	
	for k,v in pairs(ldb) do
		print(k..":",v.version)
	end
	
elseif option=="listall" then
	local db=ccr.loaddb()
	for k,v in pairs(db) do
		print(k..":",v.version)
	end

elseif option=="installLocal" then --TODO Add dependancy check and autoinstall
	local path = tArgs[2]
	if fs.isDir(path) then
		if not fs.exists(fs.combine(path,"pkg")) then
			print("'"..fs.getName(path).."' is not a valid package")
			return
		end
	else
		if fs.getName(path) == "pkg" then
			path = string.gsub(path,"/pkg$","") -- Point to the parent folder instead
		else
			print("'"..fs.getName(path).."' is not a pkg file or package folder")
			return
		end
	end
	
	fs.delete(fs.combine("/tmp/ccr",fs.getName(path)))
	fs.copy(path,fs.combine("/tmp/ccr",fs.getName(path)))
	
	local res, failReason = ccr.install(fs.getName(path),2)
	
	if not res then print("Failed to install package:\n"..failReason); return end
	
	print("Success!")
	ccr.clearCache(0)
	shell.run("/startup/ccr.lua")

--[[elseif option=="bootstrap" then
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
	
	local items={"/ccr.lua","/startup/ccr.lua","/lib/ccr.lua","/startup/000loadlib.lua","/loadlib.lua"}
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
	newldb.ccinit=ldb.ccinit
	
	local f=fs.open(m.."/cfg/ccr/ldb",'w')
	f.write("local database=")
	f.write(textutils.serialize(newldb))
	f.write("\n\nreturn database")
	f.close()
	
	print("Bootstrapping complete")]]
else
	print(
[[Usage: ccr <option> [arguments]
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
]])
end


--[[
	ccr bootstrap [side/drive]
		bootstraps ccr onto disk in drive [side/drive]
]]







