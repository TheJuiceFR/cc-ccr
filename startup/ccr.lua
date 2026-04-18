local db=ccr.loaddb()

local plist={}

for k,v in pairs(db) do
	plist[#plist+1]=k
end

local ldb=ccr.loaddb()

local lplist={}

for k,v in pairs(ldb) do
	lplist[#lplist+1]=k
end

local olist={"install ","remove ","purge ","update","info ","list","listall"}

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
		if prev[2]=="install" or prev[2]=="info" then
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
		elseif prev[2]=="remove" or prev[2]=="purge" then
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
		else
			return {}
		end
	else
		return {}
	end
end

shell.setCompletionFunction("ccr.lua",complete)