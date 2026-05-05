#!/bin/bash

source ./xrun_args.sh

echo "== Cleaning =="
rm -rf xrun.* *.log waves.shm

echo "== Compile =="
xrun $XRUN_FLAGS -l compile.log
if [ $? -ne 0 ]; then
  echo "Compile failed. Check compile.log"
  exit 1
fi

echo "== Run =="
xrun -R -l run.log

echo "== Checking results =="
grep -i "ERROR" run.log && echo "Errors found"
grep -i "FATAL" run.log && echo "Fatal errors found"

echo "== Done =="
