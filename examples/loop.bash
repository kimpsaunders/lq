#!/bin/bash

# set up a symlink cycle/loop with 10 links in the chain

rm -f loop?

for i in {0..9}
do
  j=$(( ($i + 1) % 10))
  ln -s loop$j loop$i
done
