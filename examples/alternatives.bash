#!/bin/bash

set -e
set -x

cat > alternatives-01.sh <<END
ls -flogd /usr/bin/java `readlink /usr/bin/java`
readlink /usr/bin/java
readlink -f /usr/bin/java
realpath /usr/bin/java
lq /usr/bin/java /usr/bin/gcc
END
