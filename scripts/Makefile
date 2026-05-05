XRUN = xrun
XRUN_FLAGS = $(shell . ./xrun_args.sh >/dev/null 2>&1 && echo $$XRUN_FLAGS)

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
