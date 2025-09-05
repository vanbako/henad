# Prefer python3 if available, else fall back to python
PY ?= $(shell command -v python3 >/dev/null 2>&1 && echo python3 || echo python)
INPUT ?= processors/amber/asm/examples/hello.asm
TICKS ?= 200

.PHONY: help benches benches-run run clean

help:
	@echo "Targets:"
	@echo "  benches    Build all Amber *_tb.v benches to build/vvp/amber/"
	@echo "             Optional: PATTERN=<substr> to filter benches"
	@echo "  run        Assemble+run Amber with INPUT=<.asm|.hex> (default: $(INPUT))"
	@echo "             Optional: TICKS=<cycles> (default: $(TICKS))"
	@echo "             Tip: override PY for env without 'python' (e.g., make PY=python3 run)"
	@echo "  clean      Remove build/vvp/amber outputs"

benches:
	$(PY) tools/build_tbs.py --pattern "$(PATTERN)"

# Build and run all benches (prints PASS/FAIL)
benches-run: benches
	@echo "Running benches..."
	@find build/vvp/amber -maxdepth 1 -type f -name "*_tb.vvp" -print0 | xargs -0 -n1 -I{} sh -c 'echo "=== {} ==="; vvp "{}"'

run:
	$(PY) tools/amber_run.py "$(INPUT)" --ticks $(TICKS)

clean:
	rm -rf build/vvp/amber
	@echo "Cleaned build/vvp/amber"
