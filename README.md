



# NAME

`lq` - symbolic link query

# SYNOPSIS

`lq [SYMBOLIC LINK]...`

# DESCRIPTION

The `lq` tool resolves and displays symbolic links and attributes
encountered while resolving paths.

# USE CASES

Wondering how it is useful to have several layers of symbolic link indirection? Why not just make every sybolic link refer directly to a file or directory target and avoid additional indirection layers?

It turns out that each layer of indirection can add and store useful metadata top of the symbolic link target, and it can be useful to compose serveral layers of such metadata layers.

## Examples

### Debian Alternatives

The [alternatives](https://wiki.debian.org/DebianAlternative) system used by the Debian distribution uses two levels of symbolic links.

```
$ ls -flogd /usr/bin/java /etc/alternatives/java
lrwxrwxrwx 1 22 Oct 17  2024 /usr/bin/java -> /etc/alternatives/java
lrwxrwxrwx 1 43 Dec 21 17:08 /etc/alternatives/java -> /usr/lib/jvm/java-21-openjdk-amd64/bin/java
$ readlink /usr/bin/java
/etc/alternatives/java
$ readlink -f /usr/bin/java
/usr/lib/jvm/java-21-openjdk-amd64/bin/java
$ realpath /usr/bin/java
/usr/lib/jvm/java-21-openjdk-amd64/bin/java
$ lq /usr/bin/java /usr/bin/gcc
/usr/bin/java -> /etc/alternatives/java
  /etc/alternatives/java -> /usr/lib/jvm/java-21-openjdk-amd64/bin/java
    /usr/lib/jvm/java-21-openjdk-amd64/bin/java
/usr/bin/gcc -> gcc-14
  gcc-14 -> x86_64-linux-gnu-gcc-14
    x86_64-linux-gnu-gcc-14
``` 

1. The first level signifies that `/usr/bin/java` is managed by the alternatives system rather than being an individual binary.
2. The second level signifies that `java-17-openjdk-amd64` is the current alternative being used for `java`.

As seen above, though, familiar tools like `ls -l`, `readlink`, `realpath`, `stat`, and others don't have functionality for expanding and displaying each symbolic link layer, but rather:

- resolve _one_ symbolic link and show its target (like `ls -l`, `readlink`, and `stat`), or;
- resolve _all_ of the symbolic links, showing only the final, fully resolved path (`realpath`, `readlink -f`)

This `lq` tool addresses these use cases, allowing easy inspection of symbolic link chains.

### Release Management

Consider an example software configuration management structure, for managing
application storage, versions, and releases, for use in a large organization
with many teams.

```
$ ls -flogd /opt/environment/*/* /opt/application/helloworld/version/* /opt/volume/*/*
lrwxrwxrwx 1   39 May  5  2015 /opt/environment/development/helloworld -> /opt/application/helloworld/version/1.5
lrwxrwxrwx 1   39 Jan  1  2011 /opt/environment/production/helloworld -> /opt/application/helloworld/version/1.1
lrwxrwxrwx 1   39 Mar  3  2013 /opt/environment/testing/helloworld -> /opt/application/helloworld/version/1.3
lrwxrwxrwx 1   31 Jan  1  2011 /opt/application/helloworld/version/1.1 -> /opt/volume/volume1111/f5a62f82
lrwxrwxrwx 1   31 Feb  2  2012 /opt/application/helloworld/version/1.2 -> /opt/volume/volume2222/aa3145bc
lrwxrwxrwx 1   31 Mar  3  2013 /opt/application/helloworld/version/1.3 -> /opt/volume/volume3333/bbc2e5d4
lrwxrwxrwx 1   31 Apr  4  2014 /opt/application/helloworld/version/1.4 -> /opt/volume/volume4444/bba5e424
lrwxrwxrwx 1   31 May  5  2015 /opt/application/helloworld/version/1.5 -> /opt/volume/volume5555/f1d64923
drwxrwxr-x 3 4096 Jan  1  2011 /opt/volume/volume1111/f5a62f82
drwxrwxr-x 3 4096 Feb  2  2012 /opt/volume/volume2222/aa3145bc
drwxrwxr-x 3 4096 Mar  3  2013 /opt/volume/volume3333/bbc2e5d4
drwxrwxr-x 3 4096 Apr  4  2014 /opt/volume/volume4444/bba5e424
drwxrwxr-x 3 4096 May  5  2015 /opt/volume/volume5555/f1d64923
``` 

In this setup, each application is accessed via a series of symbolic links
from `/opt/environment/<ENVIRONMENT>/<APPLICATION>`.

Applications are then run by using stable paths, like
`/opt/environment/production/helloworld/bin/hello`, which can be used in
web/application server configurations, launch scripts, added to `$PATH`, etc.

At the lowest layer, applications are stored under
`/opt/volume/volume<NNNN>/<ID>`.
Considering that volumes may need to be added, removed, combined or
restructured over time, it could be impractical for all `<ID>` directories
to exist under the same mount point / parent directory.

It could also be the case that the `<ID>` directory names are unwieldy,
such as hashes, timestamps, serial numbers, or controlled by a vendor or third party.

- The first layer of symlinks within `/opt/application` 
  provides a useful, unified namespace of logical application names
  and versions, where each version is a symbolic link targeting the
  actual application build / installation directory
  (under `/opt/volume` ).
- A second layer of symbolic links under `/opt/environments` provides a namespace of environment configurations, for several different environments (`development`, `testing` and `production`) with the app symbolic link targeting the currently selected application version for each environment, and pointing to that version under `/opt/application` .

#### Symbolic Link Information

In this scheme, each symbolic link layer provides a different kind of
additional metadata.

- Where is `helloworld` version `1.3` stored?
```
$ ls -flogd /opt/application/helloworld/version/1.3
lrwxrwxrwx 1 31 Mar  3  2013 /opt/application/helloworld/version/1.3 -> /opt/volume/volume3333/bbc2e5d4
``` 

- Which `helloworld` version is currently live in the `production` environment?
```
$ ls -flogd /opt/environment/production/helloworld
lrwxrwxrwx 1 39 Jan  1  2011 /opt/environment/production/helloworld -> /opt/application/helloworld/version/1.1
``` 

These symlinks could be updated at different times for different reasons
(and by different people), as seen in the following example scenarios.

#### Release

After successful testing, owners of the `helloworld` application want to
promote their release candidate (which has been running in the
`testing` environment) to the `production` environment.

```
$ # check the initial production version
$ lq /opt/environment/production/helloworld/bin/hello
/opt/environment/production/helloworld -> /opt/application/helloworld/version/1.1
  /opt/application/helloworld/version/1.1 -> /opt/volume/volume1111/f5a62f82
    /opt/volume/volume1111/f5a62f82/bin/hello
$ cd /opt/environment/production
$ # take a copy of the symlink from testing/
$ cp -P ../testing/helloworld helloworld_tmp
$ # overwrite the helloworld symlink
$ mv -T helloworld_tmp helloworld
$ # check the final production version
$ lq /opt/environment/production/helloworld/bin/hello
/opt/environment/production/helloworld -> /opt/application/helloworld/version/1.3
  /opt/application/helloworld/version/1.3 -> /opt/volume/volume3333/bbc2e5d4
    /opt/volume/volume3333/bbc2e5d4/bin/hello
``` 

The application has been able to run as
`/opt/environment/production/helloworld/bin/hello` throughout the release
process, since `helloworld` was overwritten atomically with `helloworld_tmp`.

No paths, configurations, scripts, etc. need updating - the stable
`/opt/environment/production/helloworld/bin/hello` path seamlessly goes from
resolving to version `1.1` to version `1.3`, and both versions continue
to exist side-by-side for easy comparison, or potentially reverting back
to `1.1`.

The release is completely non-destructive of application files,
and no writes are made within `/opt/volume` during
the release.

#### Volume Move

A storage administrator wants to move the `bbc2e5d4`  storage location from 
`volume3333`  to
`volume5555` , in preparation for removing the 
`volume3333`  disk.

```
$ # check the initial storage volume location
$ lq /opt/environment/production/helloworld/bin/hello
/opt/environment/production/helloworld -> /opt/application/helloworld/version/1.3
  /opt/application/helloworld/version/1.3 -> /opt/volume/volume3333/bbc2e5d4
    /opt/volume/volume3333/bbc2e5d4/bin/hello
$ # copy bbc2e5d4 to volume5555
$ cp -ar /opt/volume/volume3333/bbc2e5d4 /opt/volume/volume5555
$ cd /opt/application/helloworld/version
$ # create a symblink with the new target
$ ln -s /opt/volume/volume5555/bbc2e5d4 1.3_tmp
$ # overwrite the old 1.3 symlink
$ mv -T 1.3_tmp 1.3
$ # check the final storage volume location
$ lq /opt/environment/production/helloworld/bin/hello
/opt/environment/production/helloworld -> /opt/application/helloworld/version/1.3
  /opt/application/helloworld/version/1.3 -> /opt/volume/volume5555/bbc2e5d4
    /opt/volume/volume5555/bbc2e5d4/bin/hello
``` 

The files for `helloworld` version 1.3 are copied to 
`volume5555` , and after successful completion, the `1.3` symbolic link is updated atomically.

Since users of `helloworld` run the software via a symbolic link, and not a `bbc2e5d4` path, there is no unavailability during this process of moving from one storage location to another - is available via the `1.3` symbolic link at all times.

#### Garbage Collection

In this convention, we can also think of each symbolic link as a reference, and use them for reference counting / garbage collection purposes.

Any symbolic links that exist under `/opt/application` , but are not the target of a symbolic link within `/opt/environment`  are not live in any environment, and could be removed:

```
$ # prepare a sorted, unique list of /opt/environment symlink targets as app1.txt
$ readlink /opt/environment/*/* | sort | uniq | tee /tmp/app1.txt
/opt/application/helloworld/version/1.3
/opt/application/helloworld/version/1.5
$ # prepare a sorted, unique list of /opt/application symlinks as app2.txt
$ ls -d /opt/application/*/*/* | sort | tee /tmp/app2.txt
/opt/application/helloworld/version/1.1
/opt/application/helloworld/version/1.2
/opt/application/helloworld/version/1.3
/opt/application/helloworld/version/1.4
/opt/application/helloworld/version/1.5
$ # delete everything in app2.txt and not in app1.txt
$ comm -1 -3 /tmp/app1,2.txt | xargs -t rm
``` 

Likewise, directories under `/opt/volume`  that are not referenced by symbolic links within
`/opt/application`  can also be removed:

```
$ # prepare a sorted, unique list of /opt/application symlink targets as vol1.txt
$ readlink /opt/application/*/*/* | sort | uniq > /tmp/vol1.txt
$ # prepare a list of /opt/volume directories as vol2.txt
$ ls -d /opt/volume/*/* | sort | uniq > /tmp/vol2.txt
$ # delete directories in vol2.txt and not in vol1.txt
$ comm -1 -3 /tmp/vol1,2.txt | xargs -t rm -rf
``` 

#### Attributes

This software configuration management scheme also demonstrates another concept.
A directory can also be thought of as a namespace, with directory name specifying some attribute, and the name of each directory entry within it being an attribute value.

This is the case for the `environment/`, `application/` and `version/` directories in the example. These attribute name/value pairs can be captured using `lq`:

```
$ lq -a environment/application/version -d': ' -e /opt/environment/*/*
/opt/environment/development/helloworld -> /opt/application/helloworld/version/1.5
  /opt/application/helloworld/version/1.5 -> /opt/volume/volume5555/f1d64923
    /opt/volume/volume5555/f1d64923
      environment: development
      application: helloworld
      version: 1.5
/opt/environment/production/helloworld -> /opt/application/helloworld/version/1.3
  /opt/application/helloworld/version/1.3 -> /opt/volume/volume5555/bbc2e5d4
    /opt/volume/volume5555/bbc2e5d4
      environment: production
      application: helloworld
      version: 1.3
/opt/environment/testing/helloworld -> /opt/application/helloworld/version/1.3
  /opt/application/helloworld/version/1.3 -> /opt/volume/volume5555/bbc2e5d4
    /opt/volume/volume5555/bbc2e5d4
      environment: testing
      application: helloworld
      version: 1.3
``` 

The `-a` option takes one or more attribute (directory) names, separated with `/`. An optional delimiter for output is specified with `-d`, with `/` being use for output as well by default. Unless `-e` is provided, only captured attribute name/value pairs are output, and the symbolic link expansion is omitted.

#### Benefits

This software configuration management convention is convenient for many common use cases:

- Files / application contents can be compared or manipulated conveniently using any tool, e.g.:
  - `diff /opt/environment/testing/helloworld/CHANGELOG /opt/environment/production/helloworld/CHANGELOG` - diff the `CHANGELOG` file
     between whatever app versions are currently live in the `testing` + `production` environments (even as those versions change over time).
  - `diff /opt/application/application/helloworld/version/1.2/README /opt/application/application/helloworld/version/1.3/CHANGELOG` - diff
     the CHANGELOG file between the specific versions `1.2` and `1.3` of the `helloworld` application.
- Storage locations can be reorganized without impacting live environments, as with the example
  `volume3333`  move to `volume5555` .
- A "release" or "upgrade" of a new application version is just a matter of
  updating a single symbolic link under `/opt/environment` .
  No application files need to be transferred, updated, or overwritten for this,
  as they already exist under `/opt/volume` , the only change is to a symbolic link.
- All symbolic link updates can be done atomically,  by creating a temporary symbolic link to the new target, then a rename to overwrite the old link.
- The symbolic links can be used for reference counting - any `/opt/volume`  directories no longer reachable via symlinks from `/opt/environment`  + `/opt/application`  can be deleted / moved harmlessly.
- Application files stored under
  `/opt/volume` 
  volumes are immutable (written once)
  and can then be replicated and cached easily at edge nodes, without ever
  needing up update or evict replicated/cached contents.
- Only the symbolic links, under
  /opt/environment and /opt/application
  are ever mutated, which are a tiny layer of dynamic metadata.

## Summary

Using a structure of directories, files, and symbolic links is a technique for
modeling, storing, and updating metadata that is convenient, and supported
natively by the operating system, and all applications / languages that
run on it.

Using a custom database, or yaml/json/xml/etc file would mean that only
applications, languages, and libraries that understand that custom
format can be aware of the metadata stored that way.

# AUTHOR

Kim Saunders kimpsaunders@gmail.com
