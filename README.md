## GITHUBER
Githuber is a tool for managing your github repositories. It is intended to be used alongside command-line git, and does no pull or push. The user can list their notifications and various information for their repositories. They can create and delete repositories. They can list, create and delete releases for a repository.

## INSTALL

Githuber requires the following libraries to be installed

libUseful      https://github.com/ColumPaget/libUseful
libUseful-lua  https://github.com/ColumPaget/libUseful-lua

to build libUseful-lua you will need to have swig (http://www.swig.org) installed

## CONFIG

Githuber requires at least a valid Github username to be setup. This can either be in the environment variable `GITHUB_USER` or it can be more permanently configured by setting the 'GithubUser' variable at the top of the githuber.lua script. This will allow you to list your repos and notifications. All other functions require an authentication token. This can either be your password (not advised) or a 'personal auth token' (recommended). Either of these values can be set in the `GITHUB_AUTH` environment variable, or in the 'GithubAuth' variable at the top of githuber.lua.

You can obtain a personal auth token by going to `Settings->Developer Settings->Personal Access Tokens`. An access token saves exposing your real password, and also allows you to set limits on the things githuber.lua can do. For instance, if you don't want to delete repositories just leave out the `delete_repo` permission, and you'll be safe from accidentally typing the command to delete one!

You can setup githuber to use a proxy by either setting one of the following environment variables:

```
SOCKS_PROXY     e.g. SOCKS_PROXY="socks5:myhost:1835"
socks_proxy
HTTPS_PROXY     e.g. HTTPS_PROXY="https://myhost:443"
https_proxy
all_proxy       e.g. all_proxy="socks5:myhost:1835"
```

or by setting the 'GithubProxy' variable at the top of githuber.lua. The GihubProxy variable is set with the format:

```
<type>:<user>:<password>@<host>:<port>
```

'type' can be

```
sshtunnel  - use ssh tunneling (-L option)
socks4     - socks 4 protocol
socks5     - socks 5 protocol (this works with 'ssh -D *:<port>' mode)
https      - https CONNECT proxy
```

for sshtunnel .ssh/config style aliases can be used in the place of 'host'


## USAGE

Githuber is usually run within the lua interpreter. e.g.

```
lua githuer.lua notify
```

alternatively you can configure linux's "binfmt" system to auto-run scripts ending in '.lua'


## COMMANDS

```
   githuber.lua account set name                                    - set user's display-name
   githuber.lua account set email                                   - set user's registered email
   githuber.lua account set bio                                     - set user's bio
   githuber.lua account set company                                 - set user's displayed company
   githuber.lua account set location                                - set user's displayed location
   githuber.lua account set blog                                    - set user's blog URL
   githuber.lua notify                                              - list user's notifications
   githuber.lua notify issues                                       - list user's issues notifications
   githuber.lua notify forks                                        - list user's forks notifications
   githuber.lua notify stars                                        - list user's stars notifications
   githuber.lua issues                                              - list all open issues acrosss all user's repos
   githuber.lua repo list                                           - list user's repositories
   githuber.lua repo details                                        - list user's repositories with traffic details
   githuber.lua repo details [repo]                                 - detailed info for a repository
   githuber.lua repo issues                                         - list user's repositories that have issues
   githuber.lua repo issues [repo]                                  - list issues for a specific repository
   githuber.lua repo names                                          - list user's repositories, just names, one name per line, for use in scripts
   githuber.lua repo urls                                           - list user's repositories, just urls, one url per line, for use in scripts
   githuber.lua repo snames                                         - list user's repositories, just names, all in one line, for use in scripts
   githuber.lua repo surls                                          - list user's repositories, just urls, all in one line, for use in scripts
   githuber.lua repo new [name] [description]                       - create new repository
   githuber.lua repo create [name] [description]                    - create new repository
   githuber.lua repo set [repo] description [description]           - change description for a repository
   githuber.lua repo set [repo] homepage [homepage]                 - change homepage for a repository
   githuber.lua repo set [repo] topics [topics]                     - change topics for a repository
   githuber.lua repo del [repo]                                     - delete repository
   githuber.lua repo delete [repo]                                  - delete repository
   githuber.lua repo rm [repo]                                      - delete repository
   githuber.lua repo merge [repo]  [pull number]                    - merge a pull request by its pull number
   githuber.lua repo watchers [repo]                                - list repo watchers
   githuber.lua repo commits [repo]                                 - list repo commits
   githuber.lua repo history [repo]                                 - list repo commits and releases
   githuber.lua repo pulls [repo]                                   - list repo pull requests
   githuber.lua repo pulls [repo] merge [pull number]               - merge a pull request by its pull number
   githuber.lua repo forks [repo]                                   - list repo forks
   githuber.lua preq [repo] [title]                                 - issue a pull request to parent repo
   githuber.lua star [url]                                          - 'star' (bookmark) a repo by url
   githuber.lua unstar [url]                                        - remove a 'star' (bookmark) of a repo by url
   githuber.lua watch [url]                                         - 'watch' a repo by url
   githuber.lua unwatch [url]                                       - remove a 'watch' of a repo by url
   githuber.lua fork [url]                                          - fork a repo by url
   githuber.lua releases [repo]                                     - list releases for a repository
   githuber.lua releases [repo] new [name] [title] [description]    - create release for a repository
   githuber.lua releases [repo] create [name] [title] [description] - create release for a repository
   githuber.lua releases [repo] del [name]                          - delete release for a repository
   githuber.lua releases [repo] delete [name]                       - delete release for a repository
   githuber.lua releases [repo] rm [name]                           - delete release for a repository
```

The 'notify' command also accepts a `-details` command-line switch, which causes it to print out the text of any comments relating to an event.

The "repo names", "repo snames", "repo urls" and  "repo surls" commands are intended for use in scripting. "repo names" and "repo urls" use newline as a separator (so one item per line) whereas "repo snames" and "repo surls" use space as a separator. For instance, you can back up all your github repositories with a script like this:

```
#!/bin/sh

mkdir GithubBackup
cd GithubBackup

for URL in `githuber.lua repo surls`
do
git clone $URL
done
```


The "preq" command issues a pull request on a repo that you've forked into your own list of repos. Unfortunately it will fail if commits have been applied since the fork. The only solution I've discovered is to delete the fork, fork again, make the changes, and re-request. There's probably a better method, but I'm still finding my way around this aspect of github.
