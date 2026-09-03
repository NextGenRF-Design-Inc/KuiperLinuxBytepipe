# Create Path Variables
set wrkDir [pwd]
set srcDir [file dirname [file normalize [ info script ] ] ]

set mode [lindex $argv 0]
set part [lindex $argv 1]
set xsa_name [lindex $argv 2]

if {$xsa_name eq ""} {
  set xsa_name system_top.xsa
}

if {([file tail $xsa_name] ne $xsa_name) || ([file extension $xsa_name] ne ".xsa")} {
  return -code error [format "ERROR: XSA name '%s' must be a filename ending in .xsa, without a directory path." $xsa_name]
}

if {($mode ne "lvds") && ($mode ne "cmos")} {
  return -code error [format "ERROR: mode $mode NOT supported! Select lvds or cmos."]
}

# Set Vivado Project Name
set project_name iio_${part}_${mode}

# Create Project
create_project $project_name $wrkDir/$mode -part $part -force

# Add Source Files
add_files -fileset constrs_1 -norecurse $srcDir/bytepipe_system_constr.xdc
add_files -fileset constrs_1 -norecurse $srcDir/system_constr.xdc
add_files -norecurse $srcDir/system_top.v
add_files -norecurse $srcDir/system_wrapper.v
add_files -norecurse $wrkDir/Adi/hdl/library/common/ad_iobuf.v

if {$mode eq "cmos"} {
add_files -fileset constrs_1 -norecurse $srcDir/cmos_constr.xdc
} else {
add_files -fileset constrs_1 -norecurse $srcDir/lvds_constr.xdc
}

# Generate IP

# Add IP Catalog
set_property ip_repo_paths [list \
  [file normalize [file join $wrkDir/Adi/hdl/library]] \
] [current_project]
update_ip_catalog

# Generate Block Design
source $srcDir/system.tcl

if {$mode eq "cmos"} {
set_property -dict [list CONFIG.CMOS_LVDS_N {1}] [get_bd_cells axi_adrv9001]
} else {
set_property -dict [list CONFIG.CMOS_LVDS_N {0}] [get_bd_cells axi_adrv9001]
}
# Refresh and Save Project
update_compile_order -fileset sources_1
regenerate_bd_layout
save_bd_design

# Make Top Module Wrapper
update_compile_order -fileset sources_1
set_property top system_top [current_fileset]
update_compile_order -fileset sources_1

# Generate Targets
generate_target all [get_files  $wrkDir/$mode/$project_name.srcs/sources_1/bd/system/system.bd]
export_ip_user_files -of_objects [get_files $wrkDir/$mode/$project_name.srcs/sources_1/bd/system/system.bd] -no_script -sync -force -quiet
create_ip_run [get_files -of_objects [get_fileset sources_1] $wrkDir/$mode/$project_name.srcs/sources_1/bd/system/system.bd]
launch_runs -jobs 6 {system_axi_hp1_interconnect_0_synth_1 system_util_adc_2_pack_0_synth_1}

# Launch Runs
launch_runs impl_1 -to_step write_bitstream -jobs 6
wait_on_run -quiet impl_1

# Export Hardware Defintion Files
update_compile_order -fileset sources_1
write_hw_platform -fixed -force -include_bit -file [file join $wrkDir $xsa_name]

exit
