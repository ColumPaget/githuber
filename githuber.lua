require("stream")
require("dataparser")
require("process")
require("terminal")
require("strutil")
require("net")
require("time")


-- program version
VERSION="1.13.0"

--        USER CONFIGURABLE STUFF STARTS HERE       --
-- Put your username here, or leave blank and use environment variable GITHUB_USER instead
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
process.lu_set("HTTP:UserAgent","githuber-"..VERSION)

--uncomment this to see HTTP headers
--process.lu_set("HTTP:Debug","y")



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


function TableSub(tab, start)
local i, item
local newtab={}

for i,item in ipairs(tab)
do
	if i >= start then table.insert(newtab, item) end
end

return newtab
end


function ParseArg(args, i)
local val

val=args[i];
args[i]=""
return(val)
end


-- color is only applied if attribute is greater than 0
function FormatNumericValue(name, value, color)
local str=""
local valnum

valnum=tonumber(value)
if valnum==nil then valnum=0 end

if (valnum > 0) then str="~e"..name..": "..color..value.."~0  "
else str=name..": 0 "
end

return(str)
end




function FormatTime(secs)
local when
local day=3600 * 24

if (time.secs() - secs) < day then when="~e"..time.formatsecs("%Y_%m_%d %H:%M", secs).."~0"
elseif (time.secs() - secs) < day * 2 then when="~y"..time.formatsecs("%Y_%m_%d %H:%M", secs).."~0"
else when="~c"..time.formatsecs("%Y_%m_%d %H:%M", secs).."~0" end

return(when)
end


function SortByTime(i1, i2)
if i1.when > i2.when then return(true) end
return(false)

end


function ParseEvent(I)
local Issue={}
local tmpstr, details, id

id=I:value("number")
if strutil.strlen(id) ==0 then id=I:value("id") end
if strutil.strlen(id) ==0 then return nil end

Issue.what=I:value("type")
Issue.id=string.format("%- 9s", id)
Issue.who=I:value("actor/login")
if strutil.strlen(Issue.who) == 0 then Issue.who=I:value("user/login") end
Issue.where=I:value("repository/name")
if strutil.strlen(Issue.where) == 0 then Issue.where=I:value("repo/name") end
Issue.when=time.tosecs("%Y-%m-%dT%H:%M:%S", I:value("created_at"))

details=I:open("payload/issue")
if details == nil then details=I end

Issue.why=details:value("title")
Issue.state=details:value("state")
Issue.url=details:value("html_url")
Issue.diff=details:value("diff_url")
Issue.patch=details:value("patch_url")
Issue.no_of_comments=details:value("comments")

if Issue.what == "IssueCommentEvent"
then
Issue.details=I:value("payload/comment/body")
else
Issue.details=I:value("payload/issue/body")
Issue.comments={}
end

return Issue
end


function GithubGetTry(url, args)
local S, doc, rcode

S=stream.STREAM(url, args)
if S==nil then return(nil) end

rcode=S:getvalue("HTTP:ResponseCode")
doc=S:readdoc()
S:close()

return doc,rcode
end



function GithubGet(url, args)
local i, doc, rcode

--io.stderr:write("GET: "..url .."\n")
for i=1,5,1
do
doc,rcode=GithubGetTry(url, args)
if strutil.strlen(doc) > 0 then return doc,rcode  end
process.sleep(1)
end

Out:puts("~rFAIL~0 No connection to github.com\n")
return(nil)
end


function GithubDelete(url, itemtype)
local doc,rcode

doc,rcode=GithubGet(url, "D hostauth")
if rcode == "204"
then
	Out:puts("~gOKAY~0 " .. itemtype .. " removed successfully\n")
else
	Out:puts("~rFAIL~0 " .. itemtype .. " removal failed\n")
end
end


function GithubPutPost(url, WriteFlag,  body, success_message, fail_message) 
local S, str, P

if WriteFlag == "P"
then
	S=stream.STREAM(url, WriteFlag.. " hostauth content-type=application/json method=PATCH content-length=" .. strutil.strlen(body))
else
	S=stream.STREAM(url, WriteFlag.. " hostauth content-type=application/json content-length=" .. strutil.strlen(body))
end

if S ~= nil
then
	S:writeln(body)
	S:commit()

	str=S:readdoc()
	P=dataparser.PARSER("json", str)

	if string.sub(S:getvalue("HTTP:ResponseCode"), 1, 1) == "2"
	then
		Out:puts("~gOKAY~0 "..success_message .."\n")
	else
		Out:puts("~rFAIL~0 ".. fail_message .. " " ..P:value("message").."\n")
	end
else	
	Out:puts("~rFAIL~0 No connection to github.com\n")
end

end


function GithubPost(url, body, success_message, fail_message) 
GithubPutPost(url, "w",  body, success_message, fail_message) 
end

function GithubPut(url, body, success_message, fail_message) 
GithubPutPost(url, "W",  body, success_message, fail_message) 
end

function GithubPatch(url, body, success_message, fail_message) 
GithubPutPost(url, "P",  body, success_message, fail_message) 
end



function GithubNotifications(user, filter)
local doc, P, I, event, when, secs

doc=GithubGet("https://api.github.com/users/"..user.."/received_events", "r hostauth")
P=dataparser.PARSER("json",doc)

I=P:first()
while I ~= nil
do

secs=time.tosecs("%Y-%m-%dT%H:%M:%S", I:value("created_at"))
-- if secs is zero, it means we got an item that's not a notification
if secs > 0
then
when=FormatTime(secs)

event=I:value("type")
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
		Out:puts(when.."  ".. I:value("actor/login").. "  "..issue_color .. I:value("payload/action") .. "  issue~0 "..title_color.."'" .. I:value("payload/issue/title") .. "'~0 " .. I:value("repo/name") .. "\r\n")
	elseif I:value("type")=="IssueCommentEvent"
	then
		Out:puts(when.."  ".. I:value("payload/comment/user/login").. "  ~rcommented on issue~0 "..title_color.."'" .. I:value("payload/issue/title") .. "'~0 " .. I:value("repo/name") .. "\r\n")
	else
	
		Out:puts(when.."  "..I:value("actor/login").. "  " .. event .. "  ".. I:value("repo/name") .. "\r\n")
	end
end
end
I=P:next()
end

end


function GithubOutputEvent(Event)
local State

	if Event.state == "closed" then State="~gclosed~0"
	else State="~rOPEN~0"
	end

	Out:puts(Event.id .." ".. State.." since " .. time.formatsecs("%Y/%m/%d",Event.when) .. " by ".. string.format("%- 15s", Event.who) .. "  " .. Event.where .. "  " .. title_color .. "'" .. Event.why.."~0'  ".. "comments: "..Event.no_of_comments.."\r\n  url: "..Event.url.."\r\n")
	if strutil.strlen(Event.diff) > 0
	then
		Out:puts("  diff: "..Event.diff.."  patch: "..Event.patch .. "\r\n")
	end
	Out:puts("\r\n")
end



function GithubIssuesURL(url, showall)
local doc, P, I, key
local Issues={}
local Event

doc=GithubGet(url, "r hostauth")
P=dataparser.PARSER("json",doc)

I=P:first()
while I ~= nil
do
Event=ParseEvent(I)
if Event ~= nil then Issues[Event.id]=Event; end

I=P:next()
end

for key,Event in pairs(Issues)
do
	if Event.state ~="closed" or showall==true then GithubOutputEvent(Event) end
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
local doc, P, clones

doc=GithubGet("https://" .. GithubUser .. ":" .. GithubAuth .. "@" .. "api.github.com/repos/"..user.."/"..repo.."/traffic/clones", "r hostauth")

P=dataparser.PARSER("json",doc)
clones=P:value("count")
uniques=P:value("uniques")

return clones,uniques
end


function GithubRepoReferers(user, repo)
local doc, P, clones

doc=GithubGet("https://" .. GithubUser .. ":" .. GithubAuth .. "@" .. "api.github.com/repos/"..user.."/"..repo.."/traffic/popular/referrers", "r hostauth")

P=dataparser.PARSER("json",doc)
clones=P:value("/count")

return(clones)
end



function GitubRepoCommitParse(info)
local commit={}

commit.type="commit";
commit.who=info:value("commit/committer/name")
commit.what=info:value("commit/message")
commit.when=time.tosecs("%Y-%m-%dT%H:%M:%S", info:value("commit/committer/date"))

return(commit)
end

function GithubRepoCommitsLoad(commit_list, user, repo)
local doc, url, P, item

doc=GithubGet("https://" .. GithubUser .. ":" .. GithubAuth .. "@" .. "api.github.com/repos/"..user.."/"..repo.."/commits","r");
P=dataparser.PARSER("json",doc)

item=P:first()
while item ~= nil
do
table.insert(commit_list, GitubRepoCommitParse(item))
item=P:next()
end

end


function GithubRepoReleaseParse(info)
local release={}

release.type="release";
release.who=info:value("author/login")
release.tag=info:value("tag_name")
release.what=info:value("name")
release.url=info:value("url")
release.tarball=info:value("tarball_url")
release.zipball=info:value("zipball_url")
release.when=time.tosecs("%Y-%m-%dT%H:%M:%S", info:value("published_at"))

return(release)
end


function GithubRepoReleasesLoad(commit_list, user, repo)
local doc, P, item

doc=GithubGet("https://" .. GithubUser .. ":" .. GithubAuth .. "@" .. "api.github.com/repos/"..user.."/"..repo.."/releases", "r")
P=dataparser.PARSER("json",doc)

item=P:first()
while item ~= nil
do
table.insert(commit_list, GithubRepoReleaseParse(item))
item=P:next()
end

end


function GithubRepoCommitsList(report_type, user, repo)
local commit_list={}

GithubRepoCommitsLoad(commit_list, user, repo)
if report_type=="history" then GithubRepoReleasesLoad(commit_list, user, repo) end

table.sort(commit_list, SortByTime)

for i,item in ipairs(commit_list)
do

if item.when > 0
then
Out:puts("~e" .. FormatTime(item.when) .. " ~y" .. strutil.padto(item.who, " ", 15) .. "~0  ")

if report_type=="history"
then
	if item.type=="release"
	then 
		Out:puts("~m"..item.type.."~0:"..item.tag.." ")
	else
		Out:puts("~c"..item.type.." ~0 ")
	end
end

Out:puts("  " ..item.what.."\n")
end
end

end



function GithubRepoReleasesList(user, repo)
local doc, url, P, item

doc=GithubGet("https://" .. GithubUser .. ":" .. GithubAuth .. "@" .. "api.github.com/repos/"..user.."/"..repo.."/releases", "r")
P=dataparser.PARSER("json",doc)

item=P:first()
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


function GithubRepoReleasesNew(user, repo, tag, name, descript) 
local url, body

url="https://" .. GithubUser .. ":" .. GithubAuth .. "@" .. "api.github.com/repos/"..user.."/"..repo.."/releases";

body='{"tag_name": "'..strutil.quoteChars(tag,'"')..'", "name": "'..strutil.quoteChars(name,'"')..'", '..'"body": "'..strutil.quoteChars(descript,'"')..'"}'

GithubPost(url, body, "Release created successfully", "Release creation failed: ")
end




function GithubRepoReleasesDelete(user, repo, tag) 
local doc, rcode, P, item
local found=false

doc=GithubGet("https://" .. GithubUser .. ":" .. GithubAuth .. "@" .. "api.github.com/repos/"..user.."/"..repo.."/releases", "r")
P=dataparser.PARSER("json",doc)

item=P:first()
while item ~= nil
do

if item:value("tag_name")==tag
then
	found=true
	url="https://" .. GithubUser .. ":" .. GithubAuth .. "@" .. "api.github.com/repos/"..user.."/"..repo.."/releases/"..item:value("id")
  GithubDelete(url, "Release")
	break
end

item=P:next()
end

if found == false then Out:puts("~rFAIL~0 no matching relase found\n") end

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
local url, body

url="https://"..GithubUser..":"..GithubAuth.."@api.github.com/user/repos"
body='{"name": "'..strutil.quoteChars(repo,'"')..'", '..'"description": "'..strutil.quoteChars(description,'"')..'"}'

GithubPost(url, body, "Repo created successfully", "Repo creation failed: ")
end


function GithubRepoDelete(user, repo)
local url

url="https://"..GithubUser..":"..GithubAuth.."@api.github.com/repos/"..user.."/"..repo
GithubDelete(url, "Repo")
end


function GithubRepoSet(user, repo, key, value)
local url, body

	body='{"name": "'..strutil.quoteChars(repo,'"')..'", '
	if key=="description" then body=body..'"description": "'..strutil.quoteChars(value,'"') end
	if key=="homepage" then body=body..'"homepage": "'..strutil.quoteChars(value,'"') end
	body=body..'"}'

	url="https://"..GithubUser..":"..GithubAuth.."@api.github.com/repos/"..user.."/"..repo
	GithubPost(url, body, "Repo updated successfully", "Repo update failed: ")

end


function GithubRepoListWatchers(user, repo)
local doc, rcode, url, P, item, len

url="https://"..GithubUser..":"..GithubAuth.."@api.github.com/repos/"..user.."/"..repo.."/stargazers"

doc,rcode=GithubGet(url, "r hostauth")
if rcode == "200"
then
print(doc)
		P=dataparser.PARSER("json",doc)
		item=P:first()
		while item ~=nil
		do
		Out:puts("~e"..item:value("login").."~0  "..url_color..item:value("html_url").."~0\r\n")
		item=P:next()
		end
	end
end



function GithubRepoListForks(user, repo)
local doc, rcode, url, P, item, secs

url="https://"..GithubUser..":"..GithubAuth.."@api.github.com/repos/"..user.."/"..repo.."/forks"
doc,rcode=GithubGet(url, "r hostauth")
if rcode == "200"
then
		P=dataparser.PARSER("json",doc)
		item=P:first()
		while item ~=nil
		do
			secs=time.tosecs("%Y-%m-%dT%H:%M:%S", item:value("created_at"))
			-- if secs is zero, it means we got an item that's not a notification
			Out:puts(FormatTime(secs) .. "  " .. "~e"..item:value("owner/login").."~0  "..url_color..item:value("html_url").."~0\r\n")
			item=P:next()
		end
end

end




function GithubRepoParent(user, repo)
local url,doc, rcode, P
local parent_url="none"
local parent

url="https://"..GithubUser..":"..GithubAuth.."@api.github.com/repos/"..user.."/".. repo 
doc,rcode=GithubGet(url, "r")
if rcode == "200"
then
P=dataparser.PARSER("json", doc)
parent=P:open("/parent")
parent_url=parent:value("html_url")
end

return parent_url
end


function GithubFormatRepo(P, detail)
local desc, str, item
local user, clones, uniques

	repo=P:value("name")
	desc=P:value("description")

	item=P:open("/owner")
	user=item:value("login")

	if strutil.strlen(desc) == 0 or desc == "null" then desc=issue_color.."no description~0" end

 	str="~m~e" .. repo .. "~0  " .. "   ~elanguage:~0 ".. P:value("language") .. "   ~b" .. P:value("html_url") .. "~0\r\n"
	str=str.."~ecreated:~0 " .. string.gsub(P:value("created_at"), "T", " ") .. "   ~eupdated:~0 ".. string.gsub(P:value("updated_at"), "T", " ") .. "\r\n"

	str=str.. FormatNumericValue("stars", P:value("stargazers_count"), starred_color)
	str=str.. FormatNumericValue("forks", P:value("forks_count"), fork_color)
	str=str.. FormatNumericValue("issues", P:value("open_issues"), issue_color)

	if detail["traffic"] == true
	then
		clones,uniques=GithubRepoTraffic(user, repo)
	end

	str=str.. FormatNumericValue("clones", clones, fork_color)
	str=str.. FormatNumericValue("uniques", uniques, fork_color)

	if P:value("fork") == "true"  
	then
		if detail["forks"] == true
		then
				str=str.." ~bfork of ".. GithubRepoParent(user, repo) .. "~0" 
		else
				str=str.." ~bfork~0" 
		end
	end

	str=str .. "\r\n"


	if detail["topics"] == true
	then
		str=str.."~etopics:~0 "
		topics_list=P:open("topics")
		if topics_list ~= nil
		then
			item=topics_list:next()
			while item ~= nil
			do
				str=str.." "..item:value("")
				item=topics_list:next()
			end
		end
		str=str .. "\r\n"
	end

	str=str .. desc .. "\r\n"

return str
end


function GithubRepoInfo(user, repo)
local doc, url, P, I
local detail={}

url="https://api.github.com/repos/"..user.."/"..repo
doc,rcode=GithubGet(url, "r Accept=application/vnd.github.mercy-preview+json")

if rcode == "200"
then
P=dataparser.PARSER("json",doc)

detail["forks"]=true
detail["traffic"]=true
detail["topics"]=true
Out:puts(GithubFormatRepo(P, detail))
end
	
end



function GithubRepoList(user, list_type)
local doc, url, P, I, name, desc, event, clones, uniques
local detail={}

detail["forks"]=false
detail["traffic"]=false
detail["topics"]=false

if list_type=="details"
then
	detail["forks"]=true
	detail["traffic"]=true
	detail["topics"]=true
end


doc=GithubGet("https://api.github.com/users/"..user.."/repos?per_page=100", "r Accept=application/vnd.github.mercy-preview+json")
P=dataparser.PARSER("json", doc)


I=P:first()
while I ~= nil
do
	name=I:value("name")
	if strutil.strlen(name) > 0 
	then
		if list_type == "names"
		then
      name=strutil.quoteChars(name, " 	`'$\"")
			Out:puts(name.."\r\n")
		elseif list_type == "snames"
		then
      name=strutil.quoteChars(name, " 	`'$\"")
			Out:puts(name.." ")
		elseif list_type == "urls"
		then
      name=strutil.quoteChars(I:value("html_url"), " 	`'$\"")
			Out:puts(name.."\r\n")
		elseif list_type == "surls"
		then
      name=strutil.quoteChars(I:value("html_url"), " 	`'$\"")
			Out:puts(name.." ")
		else
			Out:puts(GithubFormatRepo(I, detail))
	    Out:puts("\r\n")
		end
	end
	
	I=P:next()
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
	if args[4]=="topics" 
	then 
		GithubRepoSetTopics(user, args[3], TableSub(args, 5))
	else
		GithubRepoSet(user, args[3], args[4], args[5]) 
	end
elseif args[2]=="merge"
then
	GithubRepoPullMerge(user, args[3], args[4])
elseif args[2]=="watchers"
then
GithubRepoListWatchers(user, args[3])
elseif args[2]=="forks"
then
GithubRepoListForks(user, args[3])
elseif args[2]=="pulls"
then
GithubRepoPulls(user, args[3], args[4], args[5])
elseif args[2]=="topics"
then
GithubRepoTopics(user, args[3])
elseif args[2]=="history"
then
GithubRepoCommitsList("history", user, args[3])
elseif args[2]=="commits"
then
GithubRepoCommitsList("commits", user, args[3])
elseif args[2]=="issues"
then
GithubIssuesURL("https://" .. GithubUser .. ":" .. GithubAuth .. "@api.github.com/repos/"..GithubUser.."/"..args[3].."/issues?state=all",true)
elseif args[2]=="details" 
then
	if strutil.strlen(args[3]) > 0
	then
		GithubRepoInfo(user, args[3])
	else
		GithubRepoList(user, args[2])
	end
elseif  args[2] == "names" or args[2] == "urls" or args[2] == "snames" or args[2] == "surls"
then
GithubRepoList(user, args[2])
else
GithubRepoList(user, "")
end

end



-- target can be 'name', 'email', 'bio'
function GithubAccountSet(user, target, args)
local str, doc, url
local value=""

for i,str in ipairs(args)
do
	value=value..str
end

doc='{"' .. target .. '": "' .. value .. '"}'
url="https://"..GithubUser..":"..GithubAuth.."@api.github.com/user"
GithubPatch(url, doc, "changed " .. target, "change ".. target .. " failed")

end



function GithubAccount(user, args)

if args[2]=="set"
then
	if args[3]=="user" then GithubAccountSet(user, "user", TableSub(args, 4))
	elseif args[3]=="email" then GithubAccountSet(user, "email", TableSub(args, 4))
	elseif args[3]=="bio" then GithubAccountSet(user, "bio", TableSub(args, 4))
	elseif args[3]=="location" then GithubAccountSet(user, "location", TableSub(args, 4))
	elseif args[3]=="company" then GithubAccountSet(user, "company", TableSub(args, 4))
	elseif args[3]=="blog" then GithubAccountSet(user, "blog", TableSub(args, 4))
	else print("ERROR: unknown account setting '"..args[3].."'")
	end
end

end

function GithubWatchRepo(user, url, WatchType)
local URLInfo
local doc=""

URLInfo=net.parseURL(url)
if WatchType=="star" then
url="https://"..GithubUser..":"..GithubAuth.."@api.github.com/user/starred"..URLInfo.path
else
url="https://"..GithubUser..":"..GithubAuth.."@api.github.com/repos"..URLInfo.path.."/subscription"
doc='{"subscribed": true, "ignored": false}'
end

GithubPut(url, doc, "added " .. WatchType, WatchType .. " failed: ")
end



function GithubUnWatchRepo(user, url, WatchType)
local URLInfo

URLInfo=net.parseURL(url)
if WatchType=="star" then
url="https://"..GithubUser..":"..GithubAuth.."@api.github.com/user/starred"..URLInfo.path;
else
url="https://"..GithubUser..":"..GithubAuth.."@api.github.com/repos"..URLInfo.path.."/subscription";
end

GithubDelete(url, "star")
end




function GithubForkRepo(user, url, WatchType)
local URLInfo

URLInfo=net.parseURL(url)
url="https://"..GithubUser..":"..GithubAuth.."@api.github.com/repos"..URLInfo.path.."/forks";

GithubPost(url, "", "Fork sucessful", "Fork failed: ") 
end


function GithubRepoTopics(user, repo)
local doc, url, P, item, items
local Event={}

url="https://"..GithubUser..":"..GithubAuth.."@api.github.com/repos/"..user.."/"..repo.."/topics";
doc=GithubGet(url, "r Accept=application/vnd.github.mercy-preview+json")
P=dataparser.PARSER("json", doc)
items=P:open("/names")

item=items:first()
while item ~= nil
do
	Out:puts("item:" .. item:value() .. "\n")
	item=items:next()
end

end


function GithubRepoSetTopics(user, repo, args)
local json, url, i, topic
local topics=""


for i,topic in ipairs(args)
do

	if strutil.strlen(topics)==0 
	then 
		topics=topics .. '"' .. topic .. '"' 
	else
		topics=topics .. ', "' .. topic .. '"' 
	end
end


url="https://"..GithubUser..":"..GithubAuth.."@api.github.com/repos/"..user.."/"..repo.."/topics";
json='{"names": [' .. topics ..  ']}'

GithubPutPost(url, "W Accept=application/vnd.github.mercy-preview+json", json, "topics updated", "failed to set topics")

end



function GithubRepoPullsList(user, repo)
local doc, url, P, I
local Event={}


url="https://"..GithubUser..":"..GithubAuth.."@api.github.com/repos/"..user.."/"..repo.."/pulls?state=all";
doc=GithubGet(url, "r")
P=dataparser.PARSER("json",doc)

I=P:first()
while I ~= nil
do
	Event=ParseEvent(I)
	if Event ~= nil then GithubOutputEvent(Event) end
	I=P:next()
end

end



function GithubRepoPullMerge(user, repo, pullid)
local doc, url, json, P, I, merge_sha, merge_msg


url="https://"..GithubUser..":"..GithubAuth.."@api.github.com/repos/"..user.."/"..repo.."/pulls/"..pullid;
doc=GithubGet(url, "r")
P=dataparser.PARSER("json",doc)

merge_title=P:value("title")

I=P:open("/head")
merge_sha=I:value("sha")
merge_msg=""

url="https://"..GithubUser..":"..GithubAuth.."@api.github.com/repos/"..user.."/"..repo.."/pulls/"..pullid.."/merge";
json='{"commit_title": "' .. merge_title .. '", "commit_message": "' .. merge_msg .. '", "sha": "' .. merge_sha .. '"}'
--print(json)
GithubPutPost(url, "W", json, "pull request merged", "failed to merge pull request")
end



function GithubRepoPulls(user, repo, action, pullid)

if strutil.strlen(action) == 0 then action="list" end

if action=="merge" 
then
	GithubRepoPullMerge(user, repo, pullid)
else
	GithubRepoPullsList(user, repo)
end

end

function GithubPullsList(user)
local doc, url, P, I

--get list of repos, then get pulls for each one
url="https://api.github.com/users/"..user.."/repos";
doc=GithubGet(url, "r")
P=dataparser.PARSER("json",doc)

I=P:first()
while I ~= nil
do
	name=I:value("name")
	if strutil.strlen(name) > 0 then GithubRepoPulls(user, name) end
	
	I=P:next()
end

end


function GithubPullRequest(user, args) 
local doc, url, P, item, len, title
local parent

url="https://"..GithubUser..":"..GithubAuth.."@api.github.com/repos/"..user.."/".. args[2]
doc=GithubGet(url, "r")
P=dataparser.PARSER("json", doc)

if P:value("fork") == "true"
then
	if strutil.strlen(args[3]) > 0
	then
		parent=P:open("/parent")
		url="https://"..GithubUser..":"..GithubAuth.."@api.github.com/repos/"..parent:value("full_name") .."/pulls"
		doc='{"title": "' .. args[3] .. '", "head": "' .. user ..":"..P:value("default_branch").. '", "base": "' .. parent:value("default_branch") .. '"}'

		GithubPost(url, doc, "Pull request sent", "Pull request failed: ")
	else
		print("ERROR: No title given for pull request")
	end
else
	print("ERROR: Repo is not a fork, no parent to request pull to")
end

end


function PrintVersion()
print("githuber version: "..VERSION)
end

function PrintUsage()

print()
PrintVersion()
print()
print("Githuber is a tool for managing one's github repositories. Thus the following commands are for managing a user's own repositories, with the exceptions of the 'star', 'unstart', 'watch' and 'unwatch' commands")
print("   githuber.lua account set name                                    - set user's display-name")
print("   githuber.lua account set email                                   - set user's registered email")
print("   githuber.lua account set bio                                     - set user's bio")
print("   githuber.lua account set company                                 - set user's displayed company")
print("   githuber.lua account set location                                - set user's displayed location")
print("   githuber.lua account set blog                                    - set user's blog URL")
print("   githuber.lua notify                                              - list user's notifications")
print("   githuber.lua notify issues                                       - list user's issues notifications")
print("   githuber.lua notify forks                                        - list user's forks notifications")
print("   githuber.lua notify stars                                        - list user's stars notifications")
print("   githuber.lua issues                                              - list all open issues acrosss all user's repos")
print("   githuber.lua repo list                                           - list user's repositories")
print("   githuber.lua repo details                                        - list user's repositories with traffic details")
print("   githuber.lua repo details [repo]                                 - detailed info for a repository")
print("   githuber.lua repo names                                          - list user's repositories, just names, one name per line, for use in scripts")
print("   githuber.lua repo urls                                           - list user's repositories, just urls, one url per line, for use in scripts")
print("   githuber.lua repo snames                                         - list user's repositories, just names, all in one line, for use in scripts")
print("   githuber.lua repo surls                                          - list user's repositories, just urls, all in one line, for use in scripts")
print("   githuber.lua repo new [name] [description]                       - create new repository")
print("   githuber.lua repo create [name] [description]                    - create new repository")
print("   githuber.lua repo set [repo] description [description]           - change description for a repository")
print("   githuber.lua repo set [repo] homepage [homepage]                 - change homepage for a repository")
print("   githuber.lua repo set [repo] topics [topics]                     - change topics for a repository")
print("   githuber.lua repo del [repo]                                     - delete repository")
print("   githuber.lua repo delete [repo]                                  - delete repository")
print("   githuber.lua repo rm [repo]                                      - delete repository")
print("   githuber.lua repo merge [repo]  [pull number]                    - merge a pull request by its pull number")
print("   githuber.lua repo watchers [repo]                                - list repo watchers")
print("   githuber.lua repo commits [repo]                                 - list repo commits")
print("   githuber.lua repo history [repo]                                 - list repo commits and releases")
print("   githuber.lua repo issues [repo]                                  - list repo issues")
print("   githuber.lua repo pulls [repo]                                   - list repo pull requests")
print("   githuber.lua repo pulls [repo] merge [pull number]               - merge a pull request by its pull number")
print("   githuber.lua repo forks [repo]                                   - list repo forks")
print("   githuber.lua preq [repo] [title]                                 - issue a pull request to parent repo")
print("   githuber.lua star [url]                                          - 'star' (bookmark) a repo by url")
print("   githuber.lua unstar [url]                                        - remove a 'star' (bookmark) of a repo by url")
print("   githuber.lua watch [url]                                         - 'watch' a repo by url")
print("   githuber.lua unwatch [url]                                       - remove a 'watch' of a repo by url")
print("   githuber.lua fork [url]                                          - fork a repo by url")
print("   githuber.lua releases [repo]                                     - list releases for a repository")
print("   githuber.lua releases [repo] new [name] [title] [description]    - create release for a repository")
print("   githuber.lua releases [repo] create [name] [title] [description] - create release for a repository")
print("   githuber.lua releases [repo] del [name]                          - delete release for a repository")
print("   githuber.lua releases [repo] delete [name]                       - delete release for a repository")
print("   githuber.lua releases [repo] rm [name]                           - delete release for a repository")

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


-- if a proxy is not explicitly set in the program, then see if we can guess one from environment variables
function ConfigureProxy()

if strutil.strlen(GithubProxy) == 0 then GithubProxy=process.getenv("SOCKS_PROXY") end
if strutil.strlen(GithubProxy) == 0 then GithubProxy=process.getenv("socks_proxy") end
if strutil.strlen(GithubProxy) == 0 then GithubProxy=process.getenv("HTTPS_PROXY") end
if strutil.strlen(GithubProxy) == 0 then GithubProxy=process.getenv("https_proxy") end
if strutil.strlen(GithubProxy) == 0 then GithubProxy=process.getenv("all_proxy") end

if strutil.strlen(GithubProxy) > 0 then
net.setProxy(GithubProxy)
end

end



--     'MAIN' starts here --

ConfigureProxy()

Out=terminal.TERM()
if arg[1]=="account"
then
	if GithubCheckUser(GithubUser) then GithubAccount(GithubUser, arg) end
elseif arg[1]=="repo" or arg[1] == "repos"
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
	if GithubCheckUser(GithubUser) then GithubIssuesURL("https://" .. GithubUser .. ":" .. GithubAuth .. "@api.github.com/issues?filter=all",false) end
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
elseif arg[1]=="fork" 
then
	if GithubCheckUser(GithubUser) then GithubForkRepo(GithubUser, arg[2]) end
elseif arg[1]=="notify" 
then
	if GithubCheckUser(GithubUser) then GithubNotifications(GithubUser, arg[2]) end
elseif arg[1]=="preq"
then
	if GithubCheckUser(GithubUser) then GithubPullRequest(GithubUser, arg) end
else
PrintUsage()
end

Out:flush()
