require("stream")
require("dataparser");
require("process");
require("terminal")
require("strutil")
require("net")


-- program version
VERSION="1.0"

--        USER CONFIGURABLE STUFF STARTS HERE       --
GithubUser=""
GithubAuth=""

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
starred_color="~y"
fork_color="~m"
create_color="~g"
pullreq_color="~r"

--        USER CONFIGURABLE STUFF ENDS       --




function ParseArg(args, i)
local val

val=args[i];
args[i]=""
return(val)
end



function HandleIssuesEvent(I)
local event_text

if I:value("type") == "IssueCommentEvent"
then
Out:puts(I:value("actor/login").. "  "..comment_color.."commented~0 "..title_color.."'" .. I:value("payload/issue/title") .. "'~0 " .. I:value("repo/name") .. "\r\n")
event_text=I:value("payload/comment/body")
else
Out:puts(I:value("actor/login").. "  ".. issue_color .. I:value("payload/action") .. "  issue~0 "..title_color.."'" .. I:value("payload/issue/title") .. "'~0 " .. I:value("repo/name") .. "\r\n")
event_text=I:value("payload/issue/body")
end

if strutil.strlen(event_text) > 0 
then 
event_text=strutil.unQuote(event_text)
event_text=strutil.stripCRLF(event_text)
Out:puts(event_text.."\r\n") 
end

Out:puts("\n")
end



function GithubNotifications(user)
local S, doc, url, P, N, M, I, event

url="https://api.github.com/users/"..user.."/received_events";
S=stream.STREAM(url);
doc=S:readdoc();

P=dataparser.PARSER("json",doc);

N=P:open("/")
M=N:first()
I=M:first()
while I ~= nil
do
if I:value("type") == "IssuesEvent"
then
	Out:puts(I:value("actor/login").. "  "..issue_color .. I:value("payload/action") .. "  issue~0"..title_color.."'" .. I:value("payload/issue/title") .. "'~0 " .. I:value("repo/name") .. "\r\n");
elseif I:value("type")=="IssueCommentEvent"
then
	Out:puts(I:value("payload/comment/user/login").. "  ~rcommented on issue~0 "..title_color.."'" .. I:value("payload/issue/title") .. "'~0 " .. I:value("repo/name") .. "\r\n");
else
	event=I:value("type");
	if event=="WatchEvent" then event=starred_color.."starred~0" end
	if event=="CreateEvent" then event=creat_color.."created~0" end
	if event=="ForkEvent" then event=fork_color.."forked~0" end
	if event=="PullRequestEvent" then event=pullreq_color.."pull request~0" end
	
	Out:puts(I:value("actor/login").. "  " .. event .. "  ".. I:value("repo/name") .. "\r\n");
end
I=M:next()
end

end



function GithubIssues(user)
local S, doc, url, P, N, M, I, event

url="https://" .. GithubUser .. ":" .. GithubAuth .. "@api.github.com/users/"..user.."/received_events";
S=stream.STREAM(url);
doc=S:readdoc();

P=dataparser.PARSER("json",doc);

N=P:open("/")
M=N:first()
I=M:first()
while I ~= nil
do
if I:value("type") == "IssuesEvent" or I:value("type")=="IssueCommentEvent"
then
HandleIssuesEvent(I)
end
I=M:next()
end

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
Out:puts("~c"..item:value("url").."~0\n")
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
S=stream.STREAM(url, "method=DELETE")
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


function GithubRepoList(user)
local S, doc, url, P, N, M, I, event, clones, uniques

url="https://api.github.com/users/"..user.."/repos";
S=stream.STREAM(url);
doc=S:readdoc();

P=dataparser.PARSER("json",doc);

N=P:open("/")
M=N:first()
I=M:first()
while I ~= nil
do
desc=I:value("description");
clones,uniques=GithubRepoTraffic(user, I:value("name"));
if desc == nil then desc="" end
Out:puts("~m~e" .. I:value("name") .. "~0  " .. "~estars:~0 " .. I:value("stargazers_count") .. "  ~eforks:~0 " .. I:value("forks_count") .. "  ~rissues:~0 " .. I:value("open_issues") .. " clones: ".. clones .." uniques: "..uniques.."\r\n" .. I:value("description") .. "\r\n\n");
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
else
GithubRepoList(user)
end

end




function PrintVersion()
print("githuber version: "..VERSION)
end

function PrintUsage()

print()
PrintVersion()
print("   githuber.lua notify                                              - list users notifications")
print("   githuber.lua repo list                                           - list users repositories")
print("   githuber.lua repo new [name] [description]                       - create new repository")
print("   githuber.lua repo create [name] [description]                    - create new repository")
print("   githuber.lua repo del [name]                                     - delete repository")
print("   githuber.lua repo delete [name]                                  - delete repository")
print("   githuber.lua repo rm [name]                                      - delete repository")
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
elseif arg[1]=="notify" 
then
if GithubCheckUser(GithubUser) then GithubNotifications(GithubUser) end
else
PrintUsage()
end
