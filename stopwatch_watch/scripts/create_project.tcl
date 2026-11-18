set base [file normalize [file join [file dirname [info script]] ..]]
set target [lindex $argv 0]
if {$target eq ""} {set target stopwatch_watch}
switch -- $target {
    stopwatch_watch {
        set top top_module_sw_w
        set rtl_pattern {rtl/*.v}
        set tb_pattern {tb/new/*.v}
        set xdc {constraints/Basys-3-Master.xdc}
    }
    default {error "Unknown target: $target"}
}
set output [file join $base build $target]
create_project $target $output -part xc7a35tcpg236-1
set rtl [glob -directory $base $rtl_pattern]
add_files -norecurse $rtl
set_property top $top [get_filesets sources_1]
set tb [glob -nocomplain -directory $base $tb_pattern]
if {[llength $tb]} {add_files -fileset sim_1 -norecurse $tb}
if {$xdc ne ""} {add_files -fileset constrs_1 -norecurse [file join $base $xdc]}
update_compile_order -fileset sources_1
if {[lindex $argv 1] eq "synth"} {
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    if {![string match {*Complete*} [get_property STATUS [get_runs synth_1]]]} {error "Synthesis failed"}
    open_run synth_1
    if {[llength [get_cells -hier -filter {IS_BLACKBOX == 1}]]} {error "Unresolved black boxes"}
    report_utilization -file [file join $output utilization.rpt]
}
