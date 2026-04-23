local ccr = require("/lib/ccr")
local db = ccr.loaddb()
local ldb = ccr.loadldb()

local plist = {}
for k,v in pairs(db) do
	plist[#plist+1] = k
end

local lplist = {}
for k,v in pairs(ldb) do
	lplist[#lplist+1]=k
end

local aplistI = {}
for k,v in pairs(plist) do
	aplistI[v] = true
end
for k,v in pairs(lplist) do
	aplistI[v] = true
end
local aplist = {}
for k,v in pairs(aplistI) do
	table.insert(aplist,k)
end
aplistI = nil


local olist={"install ","installLocal ","remove ","purge ","update","info ","list","listall"}

local function complete(shell,index,argu,prev)
	local len=string.len(argu)
	if index==1 then
		local out={}
		for k,v in pairs(olist) do
			if string.sub(v,1,len)==argu then
				out[#out+1]=string.sub(v,len+1,-1)
			end
		end
		return out
	elseif index>=2 then
		if prev[2]=="install" then
			local out={}
			for k,v in pairs(plist) do
				local c=true
				for n=2,index do
					if v==prev[n] then c=false end
				end
				if c and string.sub(v,1,len)==argu then
					out[#out+1]=string.sub(v,len+1,-1).." "
				end
			end
			return out
		elseif prev[2]=="info" or prev[2]=="purge" then
			local out={}
			for k,v in pairs(aplist) do
				local c=true
				for n=2,index do
					if v==prev[n] then c=false end
				end
				if c and string.sub(v,1,len)==argu then
					out[#out+1]=string.sub(v,len+1,-1).." "
				end
			end
			
			if prev[2]=="info" then
				local outAdd = fs.complete(argu,"/",{ include_dirs = false, include_files = false, include_hidden = false })
				if argu == "" and outAdd[1] == "../" then table.remove(outAdd,1) end
				for _,v in pairs(outAdd) do table.insert(out,v) end
			end
			
			return out
		elseif prev[2]=="remove" then
			local out={}
			for k,v in pairs(lplist) do
				local c=true
				for n=2,index do
					if v==prev[n] then c=false end
				end
				if c and string.sub(v,1,len)==argu then
					out[#out+1]=string.sub(v,len+1,-1).." "
				end
			end
			return out
		elseif index==2 and prev[2]=="installLocal" then
			local out = fs.complete(argu,"/",{ include_dirs = false, include_files = false, include_hidden = false })
			if argu == "" and out[1] == "../" then table.remove(out,1) end
			return out
		else
			return {}
		end
	else
		return {}
	end
end

shell.setCompletionFunction("ccr.lua",complete)
