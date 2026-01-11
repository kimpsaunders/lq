#!/bin/bash

rm -rf directory?

for i in {9..1}
do
  mkdir directory$i
  j=$(( $i - 1 ))
  ln -s ../directory$j           directory$i/directory_link
  ln -s ../directory$j/link_link directory$i/link_link
done

mkdir directory0;
ln -s /dev/zero directory0/link_link
