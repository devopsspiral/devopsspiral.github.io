#!/usr/bin/env bash
set -e
>$1
for f in ./md*
do
	cat $f >> $1
	rm -f "$f"
done
