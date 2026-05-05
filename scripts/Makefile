XRUN = xrun
XRUN_FLAGS = -sv -f filelist.f -access +rwc -timescale 1ns/1ps

.PHONY: clean compile run check all

clean:
	rm -rf xrun.* *.log waves.shm

compile:
	$(XRUN) $(XRUN_FLAGS) -l compile.log

run:
	$(XRUN) -R -l run.log

check:
	grep -i "ERROR" run.log || true
	grep -i "FATAL" run.log || true

all: clean compile run check

default: all
