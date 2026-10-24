# Windows version of restore.sh: undo everything. Re-enables every package in the debloat list, brings
# back the stock launcher and Google TV's setup app, makes the stock launcher the default home again and
# removes the custom launcher.
# Usage: tools\restore.ps1 192.168.8.114 examples\tcl-google-tv-g08\debloat.txt
#   $env:STOCK_LAUNCHER="com.google.android.tvlauncher/.MainActivity"   (older Android TV)
param([Parameter(Mandatory)][string]$Tv, [Parameter(Mandatory)][string]$List)
$adb = "$(if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "$env:LOCALAPPDATA\Android\Sdk" })\platform-tools\adb.exe"
$stock = if ($env:STOCK_LAUNCHER) { $env:STOCK_LAUNCHER } else { "com.google.android.apps.tv.launcherx/.home.HomeActivity" }
$s = "$($Tv):5555"
& $adb connect $s | Out-Null
$pkgs = Get-Content $List | % { ($_ -replace '#.*', '').Trim() } | ? { $_ }
# One pm call per shell command; chained pm calls can stop early.
$cmds = @($pkgs | % { "pm enable $_" }) + @(
  "pm enable com.google.android.tungsten.setupwraith",
  "pm enable $($stock.Split('/')[0])",
  "cmd package set-home-activity --user 0 $stock",
  "pm uninstall com.mihir.tvhome",
  "input keyevent KEYCODE_HOME")
foreach ($c in $cmds) { "$c -> " + (& $adb -s $s shell $c 2>&1) }
"Restored. Press Home on the remote."
