# TCL script for Design Compiler - ASAP7 version
# Adapted from UMC 28nm flow

# Enable multicore functionality
set_host_options -max_cores 8

# Get design name from environment variable (set by Makefile)
set top_level [getenv DESIGN_NAME]
set clk_period [getenv PERIOD]

puts "================================================"
puts "Starting ASAP7 Synthesis"
puts "Design: ${top_level}"
puts "Clock Period: ${clk_period} ps"
puts "================================================"

# Load common variables and ASAP7 standard cells
source -verbose "../scripts/common.syn.tcl"

# Set Report Directory
set dir_name "../rpts/${top_level}"

proc checkAndCreateDir {dirName} {
    if { ![file exists $dirName] || ![file isdirectory $dirName] } {
        puts "Directory does not exist, creating: $dirName"
        file mkdir $dirName
    } else {
        puts "Directory already exists: $dirName"
    }
}

checkAndCreateDir $dir_name

# Create work library
sh rm -rf work
define_design_lib work -path work

# Read verilog files from Bender-generated filelist
puts "Reading RTL files..."
source "../load_files.tcl"

set ASAP7_SRAM_VERILOG_PATH "${FOUNDRY_PATH}/../asap7_sram_0p0/generated/verilog"
lappend search_path $ASAP7_SRAM_VERILOG_PATH
puts "INFO: Added ASAP7 SRAM verilog path: ${ASAP7_SRAM_VERILOG_PATH}"

# Elaborate design
puts "Elaborating design: ${top_level}"
elaborate $top_level
list_designs
current_design $top_level

# Clock settings
set clk_uncertainty [expr $clk_period * 0.05]
set clk_transition [expr $clk_period * 0.05]

# Create real clock if clock port is found
if {[sizeof_collection [get_ports clk_i]] > 0} {
  set clk_name "clk_i"
  set clk_port "clk_i"
  puts "Creating clock: ${clk_name} with period ${clk_period} ns"
  create_clock -name $clk_name -period $clk_period [get_ports $clk_port]
  set_drive 0 [get_clocks $clk_name]
} else {
  puts "ERROR: Clock port clk_i not found!"
  exit 1
}

# I/O delay settings
set min_input_delay [expr $clk_period * 0.1]
set max_input_delay [expr $clk_period * 0.2]
set typical_input_transition 0.05
set min_output_delay [expr $clk_period * 0.1]
set max_output_delay [expr $clk_period * 0.2]
set typical_output_load 0.005

# Link the design
puts "Linking design..."
link

# Uniquify
uniquify

# Black Box Settings
# 1. ASAP7 SRAM 
set sram_cells [get_cells -hier -filter "ref_name =~ srambank_*" -quiet]
if {[sizeof_collection $sram_cells] > 0} {
    puts "INFO: Found [sizeof_collection $sram_cells] SRAM instances"
    set_dont_touch $sram_cells true
    puts "INFO: Set dont_touch on SRAM instances"
}

# Set maximum fanout of gates
set_max_fanout 16 $top_level

# Configure the clock network
set_fix_hold [all_clocks]
set_dont_touch_network $clk_port

# Set delays and transitions
set_input_transition $typical_input_transition [all_inputs]
set_input_delay $min_input_delay -min [all_inputs] -clock $clk_name
set_input_delay $max_input_delay -max [all_inputs] -clock $clk_name
remove_input_delay -clock $clk_name [find port $clk_port]
set_output_delay $min_output_delay -min [all_outputs] -clock $clk_name
set_output_delay $max_output_delay -max [all_outputs] -clock $clk_name

set_clock_uncertainty $clk_uncertainty [get_clocks $clk_name]
set_clock_transition $clk_transition [get_clocks $clk_name]

# Reset handling (if exists)
if {[sizeof_collection [get_ports rst_ni]] > 0} {
  set_ideal_network [get_ports rst_ni]
  puts "Set ideal network on reset: rst_ni"
}

# Set loading of outputs
set_load $typical_output_load [all_outputs]

# SRAM Black Box Handling
set sram_patterns [list \
  "*i_tag_sram*" \
  "*i_data_sram*" \
  "*tc_sram*" \
  "*sram_wrapper*" \
]

foreach pattern $sram_patterns {
  set sram_cells [get_cells -hierarchical -filter "ref_name =~ $pattern" -quiet]
  if {[sizeof_collection $sram_cells] > 0} {
    puts "Setting dont_touch on SRAM cells matching: $pattern"
    set_dont_touch $sram_cells
  }
}

# Verify the design
puts "Checking design..."
check_design

# Enable pipelined-logic retiming
set_optimize_registers true -designs $top_level

set FOUNDRY_PATH [getenv FOUNDRY_PATH]
set ASAP7_LIB_PATH "${FOUNDRY_PATH}/LIB/NLDM"
set DC_HOME [get_unix_variable SYNOPSYS]
set_app_var search_path ". ${ASAP7_LIB_PATH} ${FOUNDRY_PATH} ${DC_HOME}/libraries/syn"
puts "Search path before compile: [get_app_var search_path]"

# Synthesize the design with adaptive retiming
puts "Starting compile_ultra with retiming..."
compile_ultra -retime
# For better timing: compile_ultra -retime -timing_high_effort_script

# Rename modules and signals according to naming rules
puts "Applying naming rules..."
source -verbose "../scripts/naming_rules.syn.tcl"

# Generate structural verilog netlist
puts "Writing outputs..."
write -hierarchy -format verilog -output "${dir_name}/${top_level}.syn.v"

# Generate Standard Delay Format (SDF) file
write_sdf -context verilog "${dir_name}/${top_level}.syn.sdf"

# Generate timing constraints file
write_sdc "${dir_name}/${top_level}.syn.sdc"

# Generate DDC file (for later analysis)
write -format ddc -hierarchy -output "${dir_name}/${top_level}.syn.ddc"

# Generate comprehensive reports
puts "Generating reports..."
set maxpaths 20
set rpt_file "${dir_name}/${top_level}.syn.rpt"

check_design > $rpt_file
report_area -hierarchy >> ${rpt_file}
report_power -hier -analysis_effort medium >> ${rpt_file}
report_design >> ${rpt_file}
report_cell >> ${rpt_file}
report_port -verbose >> ${rpt_file}
report_compile_options >> ${rpt_file}
report_constraint -all_violators -verbose >> ${rpt_file}
report_timing -path full -delay max -max_paths $maxpaths -nworst 100 >> ${rpt_file}
report_timing -loops >> ${rpt_file}
report_reference -hierarchy >> ${rpt_file}
report_qor >> ${rpt_file}

puts "================================================"
puts "Synthesis Complete!"
puts "Results in: ${dir_name}"
puts "================================================"

# Exit dc_shell
exit