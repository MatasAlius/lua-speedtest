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

-- checks if file exists
function M.fileExists(path)
	local f = io.open(path,"r")
	if f ~= nil then 
		io.close(f)
		return 1
	else
		return 0
	end
end

-- get list of speed test servers
function M.getServerList(file)

	f = io.open(file, "w")

	local exists = M.fileExists('/tmp/serverlist.txt')
	local response = 404
	
	if exists == 0 then
		headers = {
			"Accept: application/xml",
			"Accept-Language: en",
			"Accept-Charset: iso-8859-1,*,utf-8",
			"Cache-Control: no-cache"
		}

		f = io.open("/tmp/serverlist_orig.txt", "w")
		local results

		c = cURL.easy{
			-- speed test server list
			url = "https://gist.githubusercontent.com/autos/6f11ffa74a414fa58d4587a77d1f7ea7/raw/63bcfe0889798653d679be6fc17efc3f60dc4714/speedtest.php",
			ssl_verifypeer = false,
			ssl_verifyhost = false,
			httpheader     = headers,
			writefunction  = function(str)
				results = str
				f:write(str)
			end
		}
		c:perform()
		f:close()
		response = c:getinfo_response_code()
		os.execute('sed "1,2d" /tmp/serverlist_orig.txt | head -n-2 > /tmp/serverlist.txt')
	else
		response = 202
	end
	return response
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

-- speed test using bash
-- prints time_connect, time_starttransfer, time_total
function M.speedTest(params)
	os.execute('head -c '..params..' /dev/urandom > temp.txt')
	os.execute('curl -X POST -d @temp.txt http://speedtest.litnet.lt/speedtest/upload.php -w "\n%{time_connect},%{time_starttransfer},%{time_total}\n"')
end

-- speed test using curl
-- returns response_code, connect_time, total_time, upload_speed
function M.speedTestCurl(params)
	os.execute('head -c '..params..' /dev/urandom > temp.txt')
	local post = cURL.form()
  	:add_file  ("name", "temp.txt", "text/plain")

	local response = -1
	local connect = -1
	local total = -1
	local c = cURL.easy()
		:setopt_url("http://speedtest.litnet.lt/speedtest/upload.php")
		:setopt_httppost(post)
		:setopt_timeout(2)
		:setopt_connecttimeout(2)

	local ok, err = pcall(function() c:perform() end)
	if ok then
		response = c:getinfo_response_code()
		if response == 200 then
			connect = c:getinfo_connect_time()
			total = c:getinfo_total_time()
			upload = c:getinfo_speed_upload()
		end
	end
	c:close()
	return ok, err, response, connect, total
end

print("------")
-- print(M.getServerList("/tmpserverlist.txt"))
-- print(M.readFile("/tmp/serverlist.txt"))
-- print(M.pingIp('speedtest.litnet.lt:8080'))
-- print(M.speedTest(1024))
print(M.speedTestCurl(1024))

return M