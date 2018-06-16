#!/bin/sh

# This script is to help assist the deadlock test.
# Write a large amount of text to stdout/stderr and read from stdin and
# then repeat.

line="All work and no play makes Jack a dull boy"

i=1
while test $i -le 1024; do
  echo 1-STDOUT$i $line
  i=$((i+1))
done

i=1
while test $i -le 1024; do
  echo 1-STDERR$i $line
  i=$((i+1))
done >&2

echo -n "Reading input: "
read empty

i=1
while test $i -le 1024; do
  echo 2-STDOUT$i $line
  i=$((i+1))
done

i=1
while test $i -le 1024; do
  echo 2-STDERR$i $line
  i=$((i+1))
done >&2

echo -n "Reading input: "
read empty

exit 0
