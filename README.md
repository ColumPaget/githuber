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

Available commands are:

```
   githuber.lua notify                                              - list user's notifications
   githuber.lua notify issues                                       - list user's issues notifications
   githuber.lua notify forks                                        - list user's forks notifications
   githuber.lua notify stars                                        - list user's stars notifications
   githuber.lua issues                                              - list all open issues acrosss all user's repos
   githuber.lua repo list                                           - list user's repositories
   githuber.lua repo new [name] [description]                       - create new repository
   githuber.lua repo create [name] [description]                    - create new repository
   githuber.lua repo set [repo] description [description]           - change description for a repository
   githuber.lua repo set [repo] homepage [homepage]                 - change homepage for a repository
   githuber.lua repo del [name]                                     - delete repository
   githuber.lua repo delete [name]                                  - delete repository
   githuber.lua repo rm [name]                                      - delete repository
   githuber.lua repo watchers [name]                                - list repo watchers
   githuber.lua repo commits [name]                                 - list repo commits
   githuber.lua repo history [name]                                 - list repo commits and releases
   githuber.lua repo issues [name]                                  - list repo issues
   githuber.lua repo pulls [name]                                   - list repo pull requests
   githuber.lua repo forks [name]                                   - list repo forks
   githuber.lua star [url]                                          - 'star' (bookmark) a repo by url
   githuber.lua unstar [url]                                        - remove a 'star' (bookmark) of a repo by url
   githuber.lua watch [url]                                         - 'watch' a repo by url
   githuber.lua unwatch [url]                                       - remove a 'watch' of a repo by url
   githuber.lua releases [repo]                                     - list releases for a repository
   githuber.lua releases [repo] new [name] [title] [description]    - create release for a repository
   githuber.lua releases [repo] create [name] [title] [description] - create release for a repository
   githuber.lua releases [repo] del [name] [title] [description]    - delete release for a repository
   githuber.lua releases [repo] delete [name] [title] [description] - delete release for a repository
   githuber.lua releases [repo] rm [name] [title] [description]     - delete release for a repository
```
