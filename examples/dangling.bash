#!/bin/bash

rm -f  dangling?

for i in {0..9}
do
  j=$(( $i + 1 ))
  ln -s dangling{$j,$i}
done
