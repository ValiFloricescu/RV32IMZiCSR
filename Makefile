# ============================================================
#  RISC-V RV32IM - Pipeline pe 5 etaje
#  Metodologie: Patterson & Hennessy (COD, RISC-V Edition)
#  Makefile - flux de simulare + regresie automata (Icarus)
# ============================================================
#  Utilizare uzuala:
#     make            -> ruleaza TOATE testele (regresie completa)
#     make run TB=... -> ruleaza un singur testbench (debug)
#     make wave TB=... -> deschide unda unui testbench
#  Conventie: fisierul test/tb_NUME.v contine "module tb_NUME".
# ============================================================

# --- Unelte ---
IVERILOG ?= iverilog
VVP      ?= vvp
GTKWAVE  ?= gtkwave

# --- Directoare ---
RTL_DIR  := rtl
TEST_DIR := test
SIM_DIR  := sim
WAVE_DIR := waveform
SW_DIR   := sw

# --- Surse ---
RTL_SRCS := $(wildcard $(RTL_DIR)/*.v)
TB_SRCS  := $(sort $(wildcard $(TEST_DIR)/tb_*.v))   # toate testbench-urile

# --- Flag-uri compilare (fara DUMP_FILE; acela se adauga per-test) ---
IVFLAGS := -g2012 -Wall -I $(RTL_DIR)

# --- Pentru rularea unui singur test: make run TB=test/tb_alu.v ---
TB     ?= $(TEST_DIR)/tb_sanity.v
TBNAME := $(basename $(notdir $(TB)))
OUT := $(SIM_DIR)/$(TBNAME).out
LOG := $(SIM_DIR)/$(TBNAME).log
VCD := $(WAVE_DIR)/$(TBNAME).vcd

# ============================================================
.PHONY: all regress test run build wave sanity clean distclean help

all: regress               ## (implicit) ruleaza toata suita de regresie

regress test:              ## compileaza + ruleaza TOATE testbench-urile
	@mkdir -p $(SIM_DIR) $(WAVE_DIR)
	@echo "============================================"
	@echo "  REGRESIE RV32IM - $(words $(TB_SRCS)) testbench-uri"
	@echo "============================================"
	@pass=0; fail=0; failed=""; \
	for tb in $(TB_SRCS); do \
	  name=$$(basename $$tb .v); \
	  out=$(SIM_DIR)/$$name.out; log=$(SIM_DIR)/$$name.log; vcd=$(WAVE_DIR)/$$name.vcd; \
	  if ! $(IVERILOG) $(IVFLAGS) -DDUMP_FILE=\"$$vcd\" -s $$name -o $$out $(RTL_SRCS) $$tb 2> $$log; then \
	    echo "  [BUILD FAIL] $$name"; sed 's/^/        /' $$log; \
	    fail=$$((fail+1)); failed="$$failed $$name"; continue; \
	  fi; \
	  $(VVP) $$out > $$log 2>&1; \
	  if grep -q '>>> PASS <<<' $$log; then \
	    echo "  [PASS] $$name"; pass=$$((pass+1)); \
	  else \
	    echo "  [FAIL] $$name"; grep -E 'FAIL|error' $$log | sed 's/^/        /'; \
	    fail=$$((fail+1)); failed="$$failed $$name"; \
	  fi; \
	done; \
	echo "============================================"; \
	echo "  REZULTAT: $$pass trecute / $$((pass+fail)) total"; \
	if [ $$fail -ne 0 ]; then echo "  PICATE:$$failed"; echo "============================================"; exit 1; fi; \
	echo "  >>> TOATE TESTELE TREC <<<"; \
	echo "============================================"

build:                     ## compileaza un singur test: $(TB)
	@mkdir -p $(SIM_DIR) $(WAVE_DIR)
	$(IVERILOG) $(IVFLAGS) -DDUMP_FILE=\"$(VCD)\" -s $(TBNAME) -o $(OUT) $(RTL_SRCS) $(TB)

run: build                 ## compileaza + ruleaza un singur test (debug)
	$(VVP) $(OUT) | tee $(LOG)
	@echo ">>> waveform: $(VCD)"

sanity:                    ## smoke test de toolchain (doar tb_sanity)
	$(MAKE) run TB=$(TEST_DIR)/tb_sanity.v

wave:                      ## deschide unda testului $(TB) in GTKWave
	$(GTKWAVE) $(VCD) &

clean:                     ## sterge rezultatele de simulare (pastreaza waveform)
	rm -rf $(SIM_DIR)/*.out $(SIM_DIR)/*.log

distclean: clean           ## sterge si formele de unda
	rm -rf $(WAVE_DIR)/*.vcd

help:                      ## listeaza tintele disponibile
	@grep -E '^[a-zA-Z_ ]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	 awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-10s\033[0m %s\n",$$1,$$2}'