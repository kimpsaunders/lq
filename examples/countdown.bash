#!/bin/bash

rm -f countdown? dangling?

for i in {9..2}
do
  j=$(( $i - 1 ))
  mkdir dir$i
  ln -s countdown{$j,$i}
done

ln -s /dev/zero countdown1
