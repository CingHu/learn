#!/bin/bash
for i in `seq 1 40`
do
echo "interface 25GE 1/0/$i"
echo "undo eth-trunk"
echo "commit"
done

