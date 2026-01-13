changequote(`{', `}')
define(inline, {`include($1)`} )
define(block, {```
include($1)```} )

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

block({alternatives/alternatives-01.txt})

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

block({release/release-01-opt.txt})

In this setup, each application is accessed via a series of symbolic links
from `include({release/root_envs.txt})/<ENVIRONMENT>/<APPLICATION>`.

Applications are then run by using stable paths, like
`include({release/production_hello.txt})`, which can be used in
web/application server configurations, launch scripts, added to `$PATH`, etc.

At the lowest layer, applications are stored under
`include({release/root_vols.txt})/volume<NNNN>/<ID>`.
Considering that volumes may need to be added, removed, combined or
restructured over time, it could be impractical for all `<ID>` directories
to exist under the same mount point / parent directory.

It could also be the case that the `<ID>` directory names are unwieldy,
such as hashes, timestamps, serial numbers, or controlled by a vendor or third party.

- The first layer of symlinks within inline({release/root_apps.txt})
  provides a useful, unified namespace of logical application names
  and versions, where each version is a symbolic link targeting the
  actual application build / installation directory
  (under inline({release/root_vols.txt})).
- A second layer of symbolic links under `/opt/environments` provides a namespace of environment configurations, for several different environments (`development`, `testing` and `production`) with the app symbolic link targeting the currently selected application version for each environment, and pointing to that version under inline({release/root_apps.txt}).

#### Symbolic Link Information

In this scheme, each symbolic link layer provides a different kind of
additional metadata.

- Where is `helloworld` version `1.3` stored?
block({release/release-01-volume.txt})

- Which `helloworld` version is currently live in the `production` environment?
block({release/release-01-production.txt})

These symlinks could be updated at different times for different reasons
(and by different people), as seen in the following example scenarios.

#### Release

After successful testing, owners of the `helloworld` application want to
promote their release candidate (which has been running in the
`testing` environment) to the `production` environment.

block({release/release-02-production.txt})

The application has been able to run as
`include({release/production_hello.txt})` throughout the release
process, since `helloworld` was overwritten atomically with `helloworld_tmp`.

No paths, configurations, scripts, etc. need updating - the stable
`include({release/production_hello.txt})` path seamlessly goes from
resolving to version `1.1` to version `1.3`, and both versions continue
to exist side-by-side for easy comparison, or potentially reverting back
to `1.1`.

The release is completely non-destructive of application files,
and no writes are made within `include({release/root_vols.txt})` during
the release.

#### Volume Move

A storage administrator wants to move the inline({release/volume_dir.txt}) storage location from 
inline({release/volume_old.txt}) to
inline({release/volume_new.txt}), in preparation for removing the 
inline({release/volume_old.txt}) disk.

block({release/release-03-volume.txt})

The files for `helloworld` version 1.3 are copied to 
inline({release/volume_new.txt}), and after successful completion, the `1.3` symbolic link is updated atomically.

Since users of `helloworld` run the software via a symbolic link, and not a `include({release/volume_dir.txt})` path, there is no unavailability during this process of moving from one storage location to another - is available via the `1.3` symbolic link at all times.

#### Garbage Collection

In this convention, we can also think of each symbolic link as a reference, and use them for reference counting / garbage collection purposes.

Any symbolic links that exist under inline({release/root_apps.txt}), but are not the target of a symbolic link within inline({release/root_envs.txt}) are not live in any environment, and could be removed:

block({release/release-04-gcapp.txt})

Likewise, directories under inline({release/root_vols.txt}) that are not referenced by symbolic links within
inline({release/root_apps.txt}) can also be removed:

block({release/release-05-gcvol.txt})

#### Attributes

This software configuration management scheme also demonstrates another concept.
A directory can also be thought of as a namespace, with directory name specifying some attribute, and the name of each directory entry within it being an attribute value.

This is the case for the `environment/`, `application/` and `version/` directories in the example. These attribute name/value pairs can be captured using `lq`:

block({release/release-06-attrs.txt})

The `-a` option takes one or more attribute (directory) names, separated with `/`. An optional delimiter for output is specified with `-d`, with `/` being use for output as well by default. Unless `-e` is provided, only captured attribute name/value pairs are output, and the symbolic link expansion is omitted.

#### Benefits

This software configuration management convention is convenient for many common use cases:

- Files / application contents can be compared or manipulated conveniently using any tool, e.g.:
  - `diff include({release/root_envs.txt})/testing/helloworld/CHANGELOG include({release/root_envs.txt})/production/helloworld/CHANGELOG` - diff the `CHANGELOG` file
     between whatever app versions are currently live in the `testing` + `production` environments (even as those versions change over time).
  - `diff include({release/root_apps.txt})/application/helloworld/version/1.2/README include({release/root_apps.txt})/application/helloworld/version/1.3/CHANGELOG` - diff
     the CHANGELOG file between the specific versions `1.2` and `1.3` of the `helloworld` application.
- Storage locations can be reorganized without impacting live environments, as with the example
  inline({release/volume_old.txt}) move to inline({release/volume_new.txt}).
- A "release" or "upgrade" of a new application version is just a matter of
  updating a single symbolic link under inline({release/root_envs.txt}).
  No application files need to be transferred, updated, or overwritten for this,
  as they already exist under inline({release/root_vols.txt}), the only change is to a symbolic link.
- All symbolic link updates can be done atomically,  by creating a temporary symbolic link to the new target, then a rename to overwrite the old link.
- The symbolic links can be used for reference counting - any inline({release/root_vols.txt}) directories no longer reachable via symlinks from inline({release/root_envs.txt}) + inline({release/root_apps.txt}) can be deleted / moved harmlessly.
- Application files stored under
  inline({release/root_vols.txt})
  volumes are immutable (written once)
  and can then be replicated and cached easily at edge nodes, without ever
  needing up update or evict replicated/cached contents.
- Only the symbolic links, under
  include({release/root_envs.txt}) and include({release/root_apps.txt})
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
