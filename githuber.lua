require("stream")
require("dataparser");
require("process");
require("terminal")
require("strutil")
require("net")
require("time")


-- program version
VERSION="1.3"

--        USER CONFIGURABLE STUFF STARTS HERE       --
-- Put your username here, or leave bland and use environment variable GITHUB_USER instead
GithubUser=""

-- You can put your github password here, but I strongly advise you to go to 'Settings->Developer Settings->Personal Access Tokens' 
-- on github and create a personal access token instead. This will allow you to specify exactly the permissions you want this script
-- to have

-- You can leave this blank and use environment variable GITHUB_AUTH instead
GithubAuth=""

-- Instead of putting Username and Credentials into this script, you can put them in environment variables
if strutil.strlen(GithubUser) == 0 then GithubUser=process.getenv("GITHUB_USER") end
if strutil.strlen(GithubAuth) == 0 then GithubAuth=process.getenv("GITHUB_AUTH") end


--default User-agent. All github requests must supply a user-agent header
process.lu_set("HTTP:UserAgent","githuber-"..VERSION);

--uncomment this to see HTTP headers
--process.lu_set("HTTP:Debug","y");



--[[
Use a proxy. Proxy format is:

<type>:<user>:<password>@<host>:<port>

'type' can be

sshtunnel  - use ssh tunneling (-L option)
socks4     - socks 4 protocol
socks5     - socks 5 protocol (this works with 'ssh -D *:<port>' mode)
https      - https CONNECT proxy

for sshtunnel connections .ssh/config style aliases can be used in the place of 'host'
]]--

GithubProxy=""

if strutil.strlen(GithubProxy) == 0 then GithubProxy=process.getenv("SOCKS_PROXY") end
if strutil.strlen(GithubProxy) == 0 then GithubProxy=process.getenv("socks_proxy") end
if strutil.strlen(GithubProxy) == 0 then GithubProxy=process.getenv("HTTPS_PROXY") end
if strutil.strlen(GithubProxy) == 0 then GithubProxy=process.getenv("https_proxy") end
if strutil.strlen(GithubProxy) == 0 then GithubProxy=process.getenv("all_proxy") end



--[[
Color setup. Available colors are:

~r  red
~g  green
~b  blue
~c  cyan
~y  yellow
~m  magenta
~n  black (noir)
~w  white

]]--

issue_color="~r"
comment_color="~y"
title_color="~c"
starred_color="~b"
fork_color="~m"
create_color="~g"
pullreq_color="~r"
url_color="~c"

--        USER CONFIGURABLE STUFF ENDS       --




function ParseArg(args, i)
local val

val=args[i];
args[i]=""
return(val)
end


function ParseIssueEvent(I)
local Issue={}

if strutil.strlen(I:value("id")) ==0 then return nil end

Issue.id=string.format("%- 9s", I:value("id"))
Issue.who=I:value("actor/login")
if strutil.strlen(Issue.who) == 0 then Issue.who=I:value("user/login") end
Issue.what=I:value("type")
Issue.where=I:value("repository/name")
if strutil.strlen(Issue.where) == 0 then Issue.where=I:value("repo/name") end
Issue.when=time.tosecs("%Y-%m-%dT%H:%M:%S", I:value("created_at"))
Issue.why=I:value("title")
if strutil.strlen(Issue.who) == 0 then Issue.why=I:value("payload/issue/title") end
Issue.state=I:value("payload/issue/state")
Issue.no_of_comments=I:value("comments")
if strutil.strlen(Issue.no_of_comments) == 0  then Issue.no_of_comments=I:value("payload/issue/comments") end
if Issue.what == "IssueCommentEvent"
then
Issue.details=I:value("payload/comment/body")
else
Issue.details=I:value("payload/issue/body")
Issue.comments={}
end

return Issue
end




function GithubNotifications(user, filter)
local S, doc, url, P, N, M, I, event, when, secs
local day=3600 * 24

url="https://api.github.com/users/"..user.."/received_events";
S=stream.STREAM(url);
doc=S:readdoc();

P=dataparser.PARSER("json",doc);

N=P:open("/")
M=N:first()
I=M:first()
while I ~= nil
do

secs=time.tosecs("%Y-%m-%dT%H:%M:%S", I:value("created_at"))
-- if secs is zero, it means we got an item that's not a notification
if secs > 0
then
if (time.secs() - secs) < day then when="~e"..time.formatsecs("%Y_%m_%d %H:%M", secs).."~0"
elseif (time.secs() - secs) < day * 2 then when="~y"..time.formatsecs("%Y_%m_%d %H:%M", secs).."~0"
else when="~c"..time.formatsecs("%Y_%m_%d %H:%M", secs).."~0" end

event=I:value("type");
if 
(filter == nil) or 
(filter =="stars" and event == "WatchEvent") or
(filter =="forks" and event == "ForkEvent") or
(filter =="pulls" and event == "PullRequestEvent") or
(filter =="issues" and event == "IssuesEvent") 
then 
	if event=="WatchEvent" then event=starred_color.."starred~0" end
	if event=="CreateEvent" then event=create_color.."created~0" end
	if event=="ForkEvent" then event=fork_color.."forked~0" end
	if event=="PullRequestEvent" then event=pullreq_color.."pull request~0" end

	if event == "IssuesEvent"
	then
		Out:puts(when.."  ".. I:value("actor/login").. "  "..issue_color .. I:value("payload/action") .. "  issue~0"..title_color.."'" .. I:value("payload/issue/title") .. "'~0 " .. I:value("repo/name") .. "\r\n");
	elseif I:value("type")=="IssueCommentEvent"
	then
		Out:puts(when.."  ".. I:value("payload/comment/user/login").. "  ~rcommented on issue~0 "..title_color.."'" .. I:value("payload/issue/title") .. "'~0 " .. I:value("repo/name") .. "\r\n");
	else
	
		Out:puts(when.."  "..I:value("actor/login").. "  " .. event .. "  ".. I:value("repo/name") .. "\r\n");
	end
end
end
I=M:next()
end

end



function GithubIssues(user)
local S, doc, url, P, N, M, I, key
local Issues={}
local Event

url="https://" .. GithubUser .. ":" .. GithubAuth .. "@api.github.com/issues?filter=all";
S=stream.STREAM(url, "r hostauth");
doc=S:readdoc();

P=dataparser.PARSER("json",doc);

N=P:open("/")
M=N:first()
I=M:first()
while I ~= nil
do
Event=ParseIssueEvent(I)
if Event ~= nil then Issues[Event.id]=Event; end

I=M:next()
end

for key,Event in pairs(Issues)
do
	if Event.state ~="closed" then Out:puts(Event.id .." ~rOPEN~0 since " .. time.formatsecs("%Y/%m/%d",Event.when) .. " by ".. string.format("%- 15s", Event.who) .. "  " .. Event.where .. "  " .. title_color .. "'" .. Event.why.."~0'  ".. "comments: "..Event.no_of_comments.."\r\n") end
end


--[[
Out:puts("state: "..I:value("payload/issue/state").."\r\n")
if ShowDetail
then
if strutil.strlen(event_text) > 0 
then 
event_text=strutil.unQuote(event_text)
event_text=strutil.stripCRLF(event_text)
Out:puts(event_text.."\r\n") 
end
Out:puts("\r\n")
end
]]--

end




function GithubRepoTraffic(user, repo)
local S, doc, url, P, clones

url="https://" .. GithubUser .. ":" .. GithubAuth .. "@" .. "api.github.com/repos/"..user.."/"..repo.."/traffic/clones";

S=stream.STREAM(url, "r hostauth");
doc=S:readdoc();
P=dataparser.PARSER("json",doc);
clones=P:value("count");
uniques=P:value("uniques");

return clones,uniques
end


function GithubRepoReferers(user, repo)
local S, doc, url, P, clones

url="https://" .. GithubUser .. ":" .. GithubAuth .. "@" .. "api.github.com/repos/"..user.."/"..repo.."/traffic/popular/referrers";
S=stream.STREAM(url, "r hostauth");
doc=S:readdoc();
P=dataparser.PARSER("json",doc);
clones=P:value("/count");

return(clones);
end


function GithubRepoReleasesList(user, repo)
local S, doc, url, P, item

url="https://" .. GithubUser .. ":" .. GithubAuth .. "@" .. "api.github.com/repos/"..user.."/"..repo.."/releases";
S=stream.STREAM(url);
doc=S:readdoc();
P=dataparser.PARSER("json",doc);

item=P:next()
while item ~= nil
do
Out:puts("\n")
Out:puts("~e"..item:value("id").." ~y"..item:value("tag_name").."~0  "..item:value("name").."\n")
Out:puts(url_color..item:value("url").."~0\n")
Out:puts("~mtar: "..item:value("tarball_url").."~0\n")
Out:puts("~mzip: "..item:value("zipball_url").."~0\n")
item=P:next()
end

end


function GithubRepoReleasesNew(user, repo, tag, name, body) 
local S, doc, url, P, item, len

url="https://" .. GithubUser .. ":" .. GithubAuth .. "@" .. "api.github.com/repos/"..user.."/"..repo.."/releases";

doc='{"tag_name": "'..strutil.quoteChars(tag,'"')..'", "name": "'..strutil.quoteChars(name,'"')..'", '..'"body": "'..strutil.quoteChars(body,'"')..'"}'
len=strutil.strlen(doc);
S=stream.STREAM(url, "w hostauth content-type=application/json content-length="..len)

if S ~= nil
then
	S:writeln(doc)
	S:commit()
	doc=S:readdoc();
	P=dataparser.PARSER("json",doc);

	if S:getvalue("HTTP:ResponseCode")=="201"
	then
		Out:puts("~gOKAY~0 Release created successfully\n")
	else
		Out:puts("~rFAIL~0 Release creation failed: " ..P:value("message").."\n")
	end
else	
	Out:puts("~rFAIL~0 No connection to github.com\n")
end

end




function GithubRepoReleasesDelete(user, repo, tag) 
local S, doc, url, P, item

url="https://" .. GithubUser .. ":" .. GithubAuth .. "@" .. "api.github.com/repos/"..user.."/"..repo.."/releases";
S=stream.STREAM(url)
doc=S:readdoc()
S:close()
P=dataparser.PARSER("json",doc);

item=P:next()
while item ~= nil
do

if item:value("tag_name")==tag
then
url="https://" .. GithubUser .. ":" .. GithubAuth .. "@" .. "api.github.com/repos/"..user.."/"..repo.."/releases/"..item:value("id");
S=stream.STREAM(url, "D hostauth")
doc=S:readdoc()
S:close()
break
end

item=P:next()
end


end

function GithubRepoReleases(user, repo, args)
local arg
local name=""
local tag="" 
local desc=""

if args[3]=="create" or args[3]=="new"
then 
	GithubRepoReleasesNew(user, repo, args[4], args[5], args[6]) 
elseif args[3]=="rm" or args[3]=="del" or args[3]=="delete"
then 
	GithubRepoReleasesDelete(user, repo, args[3]) 
else
	GithubRepoReleasesList(user, repo) 
end

end


function GithubRepoCreate(user, repo, description) 
local S, doc, url, P, item, len

url="https://"..GithubUser..":"..GithubAuth.."@api.github.com/user/repos"

doc='{"name": "'..strutil.quoteChars(repo,'"')..'", '..'"description": "'..strutil.quoteChars(description,'"')..'"}'
len=strutil.strlen(doc);
S=stream.STREAM(url, "w hostauth content-type=application/json content-length="..len)
--S=stream.STREAM(url, "w content-type=application/json content-length="..len.." 'Authorization=token "..GithubAuth.."'");
if S ~= nil
then
	S:writeln(doc);
	S:commit()
	if S:getvalue("HTTP:ResponseCode")=="201"
	then
		Out:puts("~gOKAY~0 Repo created successfully\n")
		doc=S:readdoc();
		--P=dataparser.PARSER("json",doc);
	else
		Out:puts("~rFAIL~0 Repo creation failed\n")
	end
else	
Out:puts("~rFAIL~0 No connection to github.com\n")
end

end


function GithubRepoDelete(user, repo)
local S, doc, url, P, item, len

url="https://"..GithubUser..":"..GithubAuth.."@api.github.com/repos/"..user.."/"..repo

S=stream.STREAM(url, "D hostauth");
if S ~= nil
then
	doc=S:readdoc();

	if S:getvalue("HTTP:ResponseCode")=="204"
	then
		Out:puts("~gOKAY~0 Repo removed successfully\n")
	else
		Out:puts("~rFAIL~0 Repo removal failed\n")
	end
else
		Out:puts("~rFAIL~0 No connection to github.com\n")
end

end

function GithubRepoSet(user, repo, key, value)
local S, doc, url, P, item, len

url="https://"..GithubUser..":"..GithubAuth.."@api.github.com/repos/"..user.."/"..repo

doc='{"name": "'..strutil.quoteChars(repo,'"')..'", '
if key=="description" then doc=doc..'"description": "'..strutil.quoteChars(value,'"') end
if key=="homepage" then doc=doc..'"homepage": "'..strutil.quoteChars(value,'"') end
doc=doc..'"}'

len=strutil.strlen(doc)
S=stream.STREAM(url, "P hostauth content-type=application/json content-length="..len)

if S ~= nil
then
	S:writeln(doc)
	S:commit()

	doc=S:readdoc();

	if S:getvalue("HTTP:ResponseCode")=="200"
	then
		Out:puts("~gOKAY~0 Repo updated successfully\n")
	else
		Out:puts("~rFAIL~0 Repo update failed\n")
	end
else
		Out:puts("~rFAIL~0 No connection to github.com\n")
end

end


function GithubRepoListWatchers(user, repo)
local S, doc, url, P, item, len

url="https://"..GithubUser..":"..GithubAuth.."@api.github.com/repos/"..user.."/"..repo.."/stargazers"

S=stream.STREAM(url, "r hostauth");
if S ~= nil
then
	doc=S:readdoc();

	if S:getvalue("HTTP:ResponseCode")=="200"
	then
		P=dataparser.PARSER("json",doc);
		item=P:next()
		while item ~=nil
		do
		Out:puts("~e"..item:value("login").."~0  "..url_color..item:value("html_url").."~0\r\n")
		item=P:next()
		end
	end
else
		Out:puts("~rFAIL~0 No connection to github.com\n")
end

end


-- color is only applied if attribute is greater than 0
function FormatNumericValue(name, value, color)
local str=""
local valnum

valnum=tonumber(value)
if valnum==nil then valnum=0 end

if (valnum > 0) then str="~e"..name..": "..color..value.."~0  "
else str=name..": "..value.."  "
end

return(str)
end


function GithubRepoList(user)
local S, doc, url, P, N, M, I, name, desc, event, clones, uniques

url="https://api.github.com/users/"..user.."/repos";
S=stream.STREAM(url);
doc=S:readdoc();
print(doc)
P=dataparser.PARSER("json",doc);

N=P:open("/")
M=N:first()
I=M:first()
while I ~= nil
do
	name=I:value("name")
	if strutil.strlen(name) > 0 
	then
		desc=I:value("description");
		clones,uniques=GithubRepoTraffic(user, name);
		if strutil.strlen(desc) == 0 or desc == "null" then desc=issue_color.."no description~0" end
		str="~m~e" .. I:value("name") .. "~0  " 
		str=str.. FormatNumericValue("stars", I:value("stargazers_count"), starred_color)
		str=str.. FormatNumericValue("forks", I:value("forks_count"), fork_color)
		str=str.. FormatNumericValue("issues", I:value("open_issues"), issue_color)
		str=str.. FormatNumericValue("clones", clones, fork_color)
		str=str.. FormatNumericValue("uniques", uniques, fork_color)
		str=str.."\r\n" .. desc .. "\r\n\n"
		
		Out:puts(str)
	end
	
	I=M:next()
end

end



function GithubRepositories(user, args)

if args[2]=="create" or args[2]=="new"
then
GithubRepoCreate(user, args[3], args[4]) 
elseif args[2]=="del" or args[2]=="delete" or args[2]=="rm"
then
GithubRepoDelete(user, args[3]) 
elseif args[2]=="set"
then
GithubRepoSet(user, args[3], args[4], args[5]) 
elseif args[2]=="watchers"
then
GithubRepoListWatchers(user, args[3])
else
GithubRepoList(user)
end

end


function GithubWatchRepo(user, url, WatchType)
local S, rcode, len
local URLInfo
local doc=""

URLInfo=net.parseURL(url);
if WatchType=="star" then
url="https://"..GithubUser..":"..GithubAuth.."@api.github.com/user/starred"..URLInfo.path;
else
url="https://"..GithubUser..":"..GithubAuth.."@api.github.com/repos"..URLInfo.path.."/subscription"
doc='{"subscribed": true, "ignored": false}'
end
print(url)

len=strutil.strlen(doc)
S=stream.STREAM(url, "W hostauth content-type=application/json content-length="..len)
if len > 0 then S:writeln(doc) end
S:commit();
doc=S:readdoc();

rcode=S:getvalue("HTTP:ResponseCode")

if rcode=="204" or rcode=="200"
then
	if WatchType=="star" then
	Out:puts("~gOKAY~0 target starred successfully\n")
	else
	Out:puts("~gOKAY~0 target watched successfully\n")
	end
else
	Out:puts("~rFAIL~0 add " .. WatchType .. " failed\n")
end

end



function GithubUnWatchRepo(user, url, WatchType)
local S, doc, P, N, M, I, event, clones, uniques
local URLInfo

URLInfo=net.parseURL(url);
if WatchType=="star" then
url="https://"..GithubUser..":"..GithubAuth.."@api.github.com/user/starred"..URLInfo.path;
else
url="https://"..GithubUser..":"..GithubAuth.."@api.github.com/repos"..URLInfo.path.."/subscription";
end

print(url)
S=stream.STREAM(url, "D hostauth");
doc=S:readdoc();

if S:getvalue("HTTP:ResponseCode")=="204"
then
	Out:puts("~gOKAY~0 star deleted successfully\n")
else
	Out:puts("~rFAIL~0 delete star failed\n")
end

end

function GithubRepoPulls(user, repo)
local S, doc, url, P, N, M, I, name, desc, event, clones, uniques

--get list of repos, then get pulls for each one
url="https://"..GithubUser..":"..GithubAuth.."@api.github.com/repos/"..user.."/"..repo.."/pulls?state=all";
print(url)
S=stream.STREAM(url);
doc=S:readdoc();
--print(doc)
P=dataparser.PARSER("json",doc);

N=P:open("/")
--M=N:first()
I=N:first()
while I ~= nil
do
	print(repo.. "  " .. value("id") .. "  " ..value("title").."\n")
	
	I=N:next()
end

end


function GithubPullsList(user)
local S, doc, url, P, N, M, I, name, desc, event, clones, uniques

--get list of repos, then get pulls for each one
url="https://api.github.com/users/"..user.."/repos";
S=stream.STREAM(url);
doc=S:readdoc();
P=dataparser.PARSER("json",doc);

N=P:open("/")
M=N:first()
I=M:first()
while I ~= nil
do
	name=I:value("name")
	if strutil.strlen(name) > 0 then GithubRepoPulls(user, name); end
	
	I=M:next()
end

end



function PrintVersion()
print("githuber version: "..VERSION)
end

function PrintUsage()

print()
PrintVersion()
print("   githuber.lua notify                                              - list user's notifications")
print("   githuber.lua notify issues                                       - list user's issues notifications")
print("   githuber.lua notify forks                                        - list user's forks notifications")
print("   githuber.lua notify stars                                        - list user's stars notifications")
print("   githuber.lua repo list                                           - list user's repositories")
print("   githuber.lua repo new [name] [description]                       - create new repository")
print("   githuber.lua repo create [name] [description]                    - create new repository")
print("   githuber.lua repo set [repo] description [description]           - change description for a repository")
print("   githuber.lua repo set [repo] homepage [homepage]                 - change homepage for a repository")
print("   githuber.lua repo del [name]                                     - delete repository")
print("   githuber.lua repo delete [name]                                  - delete repository")
print("   githuber.lua repo rm [name]                                      - delete repository")
print("   githuber.lua repo watchers [name]                                - list repo watchers")
print("   githuber.lua star [url]                                          - 'star' (bookmark) a repo by url")
print("   githuber.lua unstar [url]                                        - remove a 'star' (bookmark) of a repo by url")
print("   githuber.lua watch [url]                                          - 'watch' a repo by url")
print("   githuber.lua unwatch [url]                                        - remove a 'watch' of a repo by url")
print("   githuber.lua issues                                              - list issues across all users repositories")
print("   githuber.lua releases [repo]                                     - list releases for a repository")
print("   githuber.lua releases [repo] new [name] [title] [description]    - create release for a repository")
print("   githuber.lua releases [repo] create [name] [title] [description] - create release for a repository")
print("   githuber.lua releases [repo] del [name] [title] [description]    - delete release for a repository")
print("   githuber.lua releases [repo] delete [name] [title] [description] - delete release for a repository")
print("   githuber.lua releases [repo] rm [name] [title] [description]     - delete release for a repository")

end


function GithubCheckUser(user)

if strutil.strlen(user) ==0
then
print("NO USER DEFINED: please either set environment variable GITHUB_USER or alter GithubUser variable at the top of githuber.lua")
Out:reset()
process.exit(1)
end

return true
end



--     'MAIN' starts here --

if strutil.strlen(GithubProxy) > 0 then
net.setProxy(GithubProxy);
end

Out=terminal.TERM()
if arg[1]=="repo" or arg[1] == "repos"
then
if GithubCheckUser(GithubUser) then GithubRepositories(GithubUser, arg) end
elseif arg[1]=="releases" 
then
if GithubCheckUser(GithubUser) then GithubRepoReleases(GithubUser, arg[2], arg) end
elseif arg[1]=="referers" 
then
if GithubCheckUser(GithubUser) then GithubRepoReferers(GithubUser, arg[2]) end
elseif arg[1]=="traffic" 
then
if GithubCheckUser(GithubUser) then GithubRepoTraffic(GithubUser, arg[2]) end
elseif arg[1]=="issues" 
then
if GithubCheckUser(GithubUser) then GithubIssues(GithubUser) end
elseif arg[1]=="pulls" 
then
if GithubCheckUser(GithubUser) then GithubPullsList(GithubUser) end
elseif arg[1]=="star" 
then
if GithubCheckUser(GithubUser) then GithubWatchRepo(GithubUser, arg[2], "star") end
elseif arg[1]=="unstar" 
then
if GithubCheckUser(GithubUser) then GithubUnWatchRepo(GithubUser, arg[2], "star") end
elseif arg[1]=="watch" 
then
if GithubCheckUser(GithubUser) then GithubWatchRepo(GithubUser, arg[2], "watch") end
elseif arg[1]=="unwatch" 
then
if GithubCheckUser(GithubUser) then GithubUnWatchRepo(GithubUser, arg[2],"watch") end
elseif arg[1]=="notify" 
then
if GithubCheckUser(GithubUser) then GithubNotifications(GithubUser, arg[2]) end
else
PrintUsage()
end
