# CCRepo

***The package manager for ComputerCraft!***

---

### Install:

Run this command whenever you need to install CCRepo, or repair a broken installation:

`wget run https://github.com/TheJuiceFR/cc-ccr/raw/main/selfInstall.lua`

---

### Using the commandline utility

`ccr install <package1> [package2]...`

installs listed package(s)

`ccr remove <package1> [package2]...`

removes listed package(s)

`ccr purge <package1> [package2]..`

removes listed package(s) and it's config files

`ccr update`

updates all packages

`ccr info <package>`

gives info about package

`ccr list`

lists installed packages

`ccr listall`

lists all available packages

---

### Using the API

Add this to the top of your program:

`ccr = require("/lib/ccr")`

**Verbosity:**

Verbosity 0: Silent

Verbosity 1: One simple message to the user

Verbosity 2: One or two messages


`database = ccr.loaddb()`

Gets the current local copy of the master database

`localDatabase = ccr.loadldb()`

Gets the local database (All of the programs installed)

`neededPkgs = ccr.resolve(verbosity)`

Gets a list of packages in need of updating

`success = ccr.clearCache(verbosity)`

Deletes ccr-related cache files

`success = ccr.sync(verbosity)`

Syncronizes local database from online

`success, failReason = ccr.download(package, verbosity)`

Download <package> for later installation

`success, failReason = ccr.install(package, verbosity, asDependancy)`

Install a downloaded package, either as explicit or a dependancy

`success, failReason = ccr.remove(package, verbosity, force)`

Remove an installed package. Checks if another package needs this one, and then won't uninstall unless forced

`success, failReason = ccr.installTree(package, verbosity)`

Installs a package along with any needed packages in it's tree of dependancies

`ccr.purge(package,verbosity)`

Purges any files from the computer that are associated with a package

