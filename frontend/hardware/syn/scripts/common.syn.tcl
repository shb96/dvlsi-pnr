# common.syn.tcl for ASAP7 PDK
# Replaces UMC 28nm library setup

# Get environment variables from Makefile
set TECH_NAME [getenv TECH_NAME]
set FOUNDRY_PATH [getenv FOUNDRY_PATH]
set TARGET_LIBRARY_FILES [getenv TARGET_LIBRARY_FILES]
set SRAM_LIBRARY_FILES [getenv SRAM_LIBRARY_FILES]

# ASAP7 library paths
set ASAP7_LIB_PATH "${FOUNDRY_PATH}/LIB/NLDM"
set ASAP7_SRAM_DB_PATH "${FOUNDRY_PATH}/../asap7_sram_0p0/generated/LIB"

# Get DC_HOME
set DC_HOME [get_unix_variable SYNOPSYS]
if {$DC_HOME == ""} {
    set DC_HOME [get_unix_variable DC_HOME]
}

# Set search path
set search_path [list \
    "." \
    ${ASAP7_LIB_PATH} \
    ${ASAP7_SRAM_DB_PATH} \
    ${FOUNDRY_PATH} \
    ${DC_HOME}/libraries/syn \
]

# Build library lists with FULL PATHS
set target_libs ""
set link_libs "* "

# 1. Standard cells
foreach lib_file $TARGET_LIBRARY_FILES {
    set lib_path "${ASAP7_LIB_PATH}/${lib_file}"
    lappend target_libs "${lib_path}"
    lappend link_libs "${lib_path}"
}

# 2. SRAM macros 
foreach sram_file $SRAM_LIBRARY_FILES {
    set sram_path "${ASAP7_SRAM_DB_PATH}/${sram_file}"
    if {[file exists $sram_path]} {
        lappend target_libs "${sram_path}"
        lappend link_libs "${sram_path}"
        puts "INFO: Added SRAM library: ${sram_path}"
    } else {
        puts "WARNING: SRAM library not found: ${sram_path}"
    }
}

# Set target and link libraries with FULL PATHS
set target_library $target_libs
set link_library [concat $link_libs "dw_foundation.sldb"]

puts "================================================"
puts "ASAP7 Library Setup"
puts "================================================"
puts "Technology: ${TECH_NAME}"
puts "Foundry Path: ${FOUNDRY_PATH}"
puts "SRAM DB Path: ${ASAP7_SRAM_DB_PATH}"
puts "Search Path: ${search_path}"
puts ""
puts "Target Library (with full paths):"
foreach lib $target_library {
    puts "  - $lib"
}
puts ""
puts "Link Library (count): [llength $link_library]"
puts "================================================"