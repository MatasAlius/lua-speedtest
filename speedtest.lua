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

-- speed test upload using curl
-- writes data to file speedtest_up.txt
function M.speedTestUpload(size, url)
	os.execute('rm /tmp/speedtest_up.txt &')

	os.execute('head -c '..size..' /dev/urandom > /tmp/temp.txt')

	local post = cURL.form()
		:add_file  ("name", "/tmp/temp.txt", "text/plain")

	f = io.open("/tmp/speedtest_up.txt", "w")
	f:write('0,0,0,0,0\n')
	f:flush()

	local start_time = os.clock()
	local end_time = os.clock()

	local c = cURL.easy()
		:setopt_url(url)
		:setopt_httppost(post)
		:setopt_timeout(8)
		:setopt_connecttimeout(2)
		:setopt_accepttimeout_ms(2)
		:setopt_noprogress(false)
		:setopt_progressfunction(function(dltotal, dlnow, ultotal, ulnow)
			end_time = os.clock()
			local elapsed_time = end_time - start_time
			local up_speed = ulnow / 1000000 / elapsed_time
			f:seek("set") 
			f:write(elapsed_time, ',', ultotal, ',', ulnow, ',', up_speed, ',0', '\n')
			f:flush()
			return 1
		end)

	local ok, err = pcall(function() c:perform() end)
	print('---')
	print(ok)
	print(err)
	if ok then
		if c:getinfo_response_code() == 200 then
			print(c:getinfo_total_time())
			print(c:getinfo_size_upload())
			print(c:getinfo_speed_upload())
			print('---')
		else
			ok = false
		end
	end
	f:seek("set") 
	f:write('-1,-1,-1,-1,1\n')
	f:flush()
	f:close()
	return ok, err
end

-- speed test download using curl
-- writes data to file speedtest_down.txt
function M.speedTestDownload(url)
	os.execute('rm /tmp/speedtest_down.txt &')

	f = io.open("/tmp/speedtest_down.txt", "w")
	f:write('0,0,0,0,0\n')
	f:flush()

	local start_time = os.clock()
	local end_time = os.clock()

	local c = cURL.easy()
		:setopt_url(url)
		:setopt_useragent('Mozilla/4.0 (compatible; MSIE 5.01; Windows NT 5.0)')
		:setopt_timeout(8)
		:setopt_connecttimeout(2)
		:setopt_accepttimeout_ms(2)
		:setopt_noprogress(false)
		:setopt_progressfunction(function(dltotal, dlnow, ultotal, ulnow)
			end_time = os.clock()
			local elapsed_time = end_time - start_time
			local down_speed = dlnow / 1000000 / elapsed_time
			f:seek("set") 
			f:write(elapsed_time, ',', dltotal, ',', dlnow, ',', down_speed, ',0', '\n')
			f:flush()
			return 1
		end)

	local ok, err = pcall(function() c:perform() end)
	print('---')
	print(ok)
	print(err)
	print('---')
	if ok then
		if c:getinfo_response_code() == 200 then
			print(c:getinfo_total_time())
			print(c:getinfo_size_download())
			print(c:getinfo_speed_download())
			print('---')
		else
			ok = false
		end
	end
	f:seek("set") 
	f:write('-1,-1,-1,-1,1\n')
	f:flush()
	f:close()
	return ok, err
end

print("------")
-- print(M.getServerList("/tmpserverlist.txt"))
-- print(M.readFile("/tmp/serverlist.txt"))
-- print(M.pingIp('speedtest.litnet.lt:8080'))
-- print(M.speedTest(1024))
-- print(M.speedTestUpload(10485760,'http://speedtest.litnet.lt/speedtest/upload.php'))
print(M.speedTestDownload('http://speedtest.litnet.lt:8080/download'))

return M