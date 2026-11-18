param([string]$VivadoBin = '', [int]$Seed = 1)
$ErrorActionPreference='Stop'
$base=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if($VivadoBin){$xvlog=Join-Path $VivadoBin 'xvlog.bat';$xelab=Join-Path $VivadoBin 'xelab.bat';$xsim=Join-Path $VivadoBin 'xsim.bat'}
else{$xvlog='xvlog';$xelab='xelab';$xsim='xsim'}
function Run-Tool($Tool,$Arguments){ & $Tool @Arguments; if($LASTEXITCODE -ne 0){throw "Tool failed: $Tool"} }
$build=Join-Path $base 'build/xsim'
[IO.Directory]::CreateDirectory($build)|Out-Null
$original=[IO.File]::ReadAllText((Join-Path $base 'tb/tb_fifo_coverage.sv'))
$portable=$original -replace '(?m)^.*\$fsdbDumpfile.*\r?\n','' -replace '(?m)^.*\$fsdbDumpvars.*\r?\n',''
$portablePath=Join-Path $build 'portable_tb.sv'
[IO.File]::WriteAllText($portablePath,$portable,[Text.UTF8Encoding]::new($false))
$sources=@('rtl/fifo.sv')
$sources=@($sources | ForEach-Object {Join-Path $base $_})
Push-Location $base
try {
    Run-Tool $xvlog (@('-sv','-L','uvm','-i','rtl','-i','rtl/pkg')+$sources+@($portablePath))
    Run-Tool $xelab @('-L','uvm','tb_fifo','-s','archive_uvm','-timescale','1ns/1ps')
    Run-Tool $xsim @('archive_uvm','-tclbatch',(Join-Path $PSScriptRoot 'simulate.tcl'),'-sv_seed',"$Seed",'-log',(Join-Path $build 'simulation.log'))
    $log=[IO.File]::ReadAllText((Join-Path $build 'simulation.log'))
    if($log -notmatch 'UVM_ERROR\s*:\s*0' -or $log -notmatch 'UVM_FATAL\s*:\s*0'){throw 'Missing zero-error UVM summary'}
    if($log -notmatch 'State x operation'){throw 'Coverage report missing'}
} finally {Pop-Location}
