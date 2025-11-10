# Author : Seungheon Baek <qwdqwd00@g.skku.edu>

SHELL = /usr/bin/env bash
ROOT_DIR := $(patsubst %/,%, $(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
ROOT := $(patsubst %/hardware,%,$(ROOT_DIR))
INSTALL_DIR := $(abspath $(ROOT_DIR)/../install)
VCS_HOME ?= /ids/tools/SYNOPSYS/VCS/S-2023.12
DW_PATH := /ids/tools/SYNOPSYS/syn/S-2021.06-SP4/dw/sim_ver

ASAP7_BASE := $(ROOT)/../asap7
ASAP7_LIB_PATH := $(ASAP7_BASE)/asap7sc7p5t_28/LIB/NLDM
ASAP7_DB_PATH := $(ASAP7_BASE)/asap7sc7p5t_28/LIB/CCS

DESIGN_NAME ?= dvlsi_system
TECH_NAME ?= asap7
FOUNDRY_PATH ?= $(ROOT)/asap7/asap7sc7p5t_28

TARGET_LIBRARY_FILES ?= \
    asap7sc7p5t_AO_RVT_TT_nldm_211120.db \
    asap7sc7p5t_INVBUF_RVT_TT_nldm_220122.db \
    asap7sc7p5t_OA_RVT_TT_nldm_211120.db \
    asap7sc7p5t_SIMPLE_RVT_TT_nldm_211120.db \
    asap7sc7p5t_SEQ_RVT_TT_nldm_220123.db

SRAM_LIBRARY_FILES ?= \
    srambank_256x4x64_6t122.db \
    srambank_128x4x64_6t122.db \
    srambank_64x4x64_6t122.db

PERIOD ?= 5000 # Target Freq : 200MHz(5ns)
TARGET ?= cv64a6_imafdc_sv39

EXPORT_SYNTH = TECH_NAME=$(TECH_NAME) \
              DESIGN_NAME=$(DESIGN_NAME) \
              TARGET=$(TARGET) \
              PERIOD=$(PERIOD) \
              FOUNDRY_PATH=$(FOUNDRY_PATH) \
              TARGET_LIBRARY_FILES="$(TARGET_LIBRARY_FILES)" \
              SRAM_LIBRARY_FILES="$(SRAM_LIBRARY_FILES)"


BENDER := $(ROOT_DIR)/../hardware/bender
BENDER_VERSION := 0.27.3


buildpath ?= build
app_name ?= tensor_core_dispatcher_csr
max_cycle ?= 2000000
dram_dump_len ?= 20000

VSCODE_DIR := $(ROOT_DIR)/.vscode
LINT_DIR := lint
VERILATOR_SCRIPT := $(LINT_DIR)/verilator.sh
VSCODE_SETTINGS := $(VSCODE_DIR)/settings.json


# Targets
bender_common_targs := -t rtl -t cv64a6_imafdcv_alt_sv39 -t tech_cells_generic_include_tc_sram -t tech_cells_generic_include_tc_clk
bender_targ_vcs := $(bender_common_targs) -t svit_soc_fpga_top_wrapper_test_sim
top_module := svit_soc_fpga_top_wrapper_tb_sim


dpi_library ?= work-dpi

SVIT_VCS_OPTS = -notice \
				+lint=all,noVCDE,noUI \
				-timescale=1ns/1ps -quiet \
				-debug_access+all -sverilog -kdb \
				-ignore initializer_driver_checks \
				-debug_region=cell+lib \
				-LDFLAGS -Wl,--no-as-needed \
				-top $(top_module) \
				+vcs+vcdpluson \
				-l $(abspath $(buildpath))/compile.log \


FSDB_DIR = $(buildpath)/fsdb
FSDB_FILE = $(top_module)_dump.fsdb
SVIT_VERDI_OPTS = 	-sv \
                  	-top $(top_module) \
				  	-ssf $(FSDB_FILE) \
					-nologo


# Build path
$(buildpath):
	mkdir -p $(buildpath)

.PHONY: bender update checkout
bender: $(BENDER)
$(BENDER):
	@[ -x $(BENDER) ] && echo "Bender already exists." || \
	(curl -sSf https://pulp-platform.github.io/bender/init | sh -s -- $(BENDER_VERSION))
	@echo "$$(./bender --version) available."

# 1) Bender
$(buildpath)/compile.sh : | $(buildpath) bender
	@echo "Generating VCS filelist..."
	cd $(buildpath) && $(BENDER) script vcs \
	--vlog-arg="-timescale=1ns/1ps" \
	--vlog-arg="-work WORK" \
	--vlog-arg="-kdb" \
	--vlog-arg="-debug_access+all" \
	--vlog-arg="-sverilog" \
	--vlog-arg="-v2k_generate" \
	--vlog-arg="-y $(DW_PATH) +incdir+$(DW_PATH) +libext+.v" \
	--vlog-arg="+define+COMMON_CELLS_ASSERTS_OFF" \
	$(bender_targ_vcs) > compile.sh


update: $(BENDER) $(ROOT_DIR)/../Bender.yml
	$(BENDER) update -f
	$(BENDER) checkout

checkout: $(BENDER)
	$(BENDER) checkout 


# 2) DPI
.PHONY: dpi
dpi: $(buildpath)/$(dpi_library)/svit_soc_dpi.so
$(buildpath)/$(dpi_library)/svit_soc_dpi.so: tb/dpi/elfloader.cc
	mkdir -p $(buildpath)/$(dpi_library)
	g++ -shared -fPIC -std=c++11 -Bsymbolic \
	-I$(INSTALL_DIR)/riscv-isa-sim/include \
	-I$(VCS_HOME)/include \
	-I$(VCS_HOME)/include/vcs \
	-c $< -o $(buildpath)/$(dpi_library)/elfloader.o \
	
	g++ -shared -o $(buildpath)/$(dpi_library)/svit_soc_dpi.so \
	-L$(INSTALL_DIR)/riscv-isa-sim/lib -lfesvr \
	-L$(VCS_HOME)/lib \
	$(buildpath)/$(dpi_library)/elfloader.o \
	

# 3) Compile
.PHONY: compile_vcs
compile_vcs: $(buildpath)/compile.sh dpi
	echo "Compiling with VCS..."
	chmod +x $(buildpath)/compile.sh
	cd $(buildpath) && ./compile.sh
	echo "Compilation script executed"
	echo "Linking to create simv"
	chmod +rx $(buildpath)
	cd $(buildpath) && vcs -full64 $(SVIT_VCS_OPTS)
	echo "VCS compilation complete"

# 4) sim_vcs
.PHONY: sim_vcs
sim_vcs: #compile_vcs
	@echo "Running VCS simulation..."
	cd $(buildpath) && ./simv \
	+PRELOAD=$(APP_DIR)/$(app_name) \
	+DRAM_DUMP_FILE=$(DUMP_DIR)/$(app_name)/dram_dump.hex \
	+DRAM_DUMP_LEN=$(dram_dump_len) \
	+SIM_MAX_CYCLE=$(max_cycle) \
	-sv_lib $(dpi_library)/svit_soc_dpi
	@echo "VCS simulation complete"


# 5) Verdi
.PHONY : verdi
verdi:
    # Extract all .sv files and include directories from compile.sh
	cd $(buildpath) && grep -oP '(?<=\").*?\.sv(?=\")' compile.sh | sed 's|\$$ROOT|$(ROOT)|g' > filelist.f
	cd $(buildpath) && grep -oP '(?<=\+incdir\+).*?(?=\")' compile.sh | sed 's|\$$ROOT|$(ROOT)|g' | sed 's/^/+incdir+/' >> filelist.f
	# cat $(buildpath)/filelist.f
	echo $(ROOT)
    # Run verdi
	if [ -f $(FSDB_DIR)/$(FSDB_FILE) ]; then \
		cd $(FSDB_DIR) && verdi -sv \
		-f ../filelist.f \
		$(SVIT_VERDI_OPTS); \
	else \
		echo "FSDB file not found at $(FSDB_DIR)/$(FSDB_FILE)"; \
		exit 1; \
    fi

SYNTH_DIR := syn
SYNTH_WORK_DIR := $(SYNTH_DIR)/work
DC_SHELL ?= dc_shell-xg-t -64bit 
.PHONY : syn syn_clean

$(SYNTH_WORK_DIR) :
	mkdir -p $(SYNTH_WORK_DIR)

$(SYNTH_DIR)/load_files.tcl : | bender
	echo "Generating Synthesis filelist..."
	cd $(SYNTH_DIR) && $(BENDER) script synopsys \
		--define COMMON_CELLS_ASSERTS_OFF \
		--target rtl \
		--target $(TARGET) \
		> load_files.tcl

syn : $(SYNTH_DIR)/load_files.tcl $(SYNTH_WORK_DIR)
	echo "Running ASAP7 Synthesis..."
	cd $(SYNTH_WORK_DIR) && export $(EXPORT_SYNTH) && \
	$(DC_SHELL) -f ../scripts/top.syn.tcl 2>&1 | tee ../syn_$(shell date +%Y%m%d_%H%M%S).log

syn_clean :
	rm -rf $(SYNTH_WORK_DIR)
	rm -rf $(SYNTH_DIR)/load_files.tcl
	rm -rf $(SYNTH_DIR)/rpts
	rm -rf $(SYNTH_DIR)/*.log


# =============================================================================
# Linting
# =============================================================================
.PHONY: lint setup-vscode lint/verilator.sh .vscode/settings.json clean_lint

# Clean existing lint files
clean_lint:
	@rm -f $(VERILATOR_SCRIPT)
	@rm -f $(VSCODE_SETTINGS)

# Create lint directory if it doesn't exist
$(LINT_DIR):
	mkdir -p $(LINT_DIR)

# Create .vscode directory if it doesn't exist
$(VSCODE_DIR):
	mkdir -p $(VSCODE_DIR)

# Generate verilator.sh using bender
$(VERILATOR_SCRIPT): clean_lint | $(LINT_DIR)
	bender script verilator $(bender_common_targs) > $(VERILATOR_SCRIPT)
	chmod +x $(VERILATOR_SCRIPT)

# Convert verilator.sh to VSCode settings
$(VSCODE_SETTINGS): $(VERILATOR_SCRIPT) | $(VSCODE_DIR)
	@echo -n '{' > $(VSCODE_SETTINGS)
	@echo -n '    "verilog.linting.verilator.arguments": "' >> $(VSCODE_SETTINGS)
	@grep -v '#!/bin/bash' $(VERILATOR_SCRIPT) | \
	sed 's/verilator//' | \
	sed 's/--cc//' | \
	sed 's/^[ \t]*//' | \
	sed '/^$$/d' | \
	sed 's/\\//' | \
	tr '\n' ' ' >> $(VSCODE_SETTINGS)
	@echo '",' >> $(VSCODE_SETTINGS)
	@echo '    "verilog.linting.linter": "verilator",' >> $(VSCODE_SETTINGS)
	@echo '    "verilog.linting.verilator.runAtFileLocation": false,' >> $(VSCODE_SETTINGS)
	@echo '}' >> $(VSCODE_SETTINGS)

# Alias for .vscode/settings.json
.PHONY: linting
linting: $(VSCODE_SETTINGS)


.PHONY: clean
clean:
	rm -rf build*
	rm -f $(BENDER)
	rm -rf work.lib++
	rm -rf AN.DB

.PHONY: force_clean
force_clean:
	@echo "Forcibly closing file handles and cleaning build directory..."
	-lsof +D $(ROOT_DIR)/build | grep -v PID | awk '{print $$2}' | sort -u | xarg kill -9 2>/dev/null || true
	$(MAKE) clean