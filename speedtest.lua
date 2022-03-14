local M = {}
local cURL = require("cURL")

-- get current location by IP address
function M.getLocation(params)
	headers = {
		"Accept: text/*",
		"Accept-Language: en",
		"Accept-Charset: iso-8859-1,*,utf-8",
		"Cache-Control: no-cache"
	}

	-- ip_url = "http://ipwhois.app/json/8.8.8.8"
	-- without IP it will use the current IP address
	ip_url = "http://ipwhois.app/json/"
	local results

	c = cURL.easy{
	url            = ip_url,
	ssl_verifypeer = false,
	ssl_verifyhost = false,
	httpheader     = headers,
	writefunction  = function(str)
		succeed = succeed or (string.find(str, "srcId:%s+SignInAlertSupressor--"))
		results = str
	end
	}
	c:perform()
	return results
end

-- get list of speed test servers
function M.getServerList(file)

	f = io.open(file, "w")
	-- speed test server list
	list_url = "https://gist.githubusercontent.com/autos/6f11ffa74a414fa58d4587a77d1f7ea7/raw/63bcfe0889798653d679be6fc17efc3f60dc4714/speedtest.php"
	
	c = cURL.easy{
		url            = list_url,
		ssl_verifypeer = false,
		ssl_verifyhost = false,
		writefunction  = function(str)
			f:write(str)
		end
	}
	c:perform()
	f:close()
	local results = c:getinfo_response_code()
	return results
end

-- read specific file,
-- path - serverlist.txt file path
function M.readFile(path)
	local count = 0
	local lines = {}
	for line in io.lines(path) do
			lines[#lines+1] = line
			count = count+1
	end
	print(count)
	return lines[count]
end

-- ping ip 3 times and return average latency
function M.pingIp(ip)
	-- local handler = io.popen("ping -c 3 '"..ip.."' | tail -1") -- returns full last line (min,average,max)
	local handler = io.popen("ping -c 3 '"..ip.."' | tail -1 | awk '{print $4}' | cut -d '/' -f 2")
	local response = handler:read("*a")
	return response
end

print("------")
print(M.getServerList("serverlist.txt"))
print(M.readFile("/tmp/serverlist.txt"))
print("------")
print(M.pingIp('speed-klaipeda.telia.lt:8080'))

return M