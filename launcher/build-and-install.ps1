# Windows version of build-and-install.sh: build the launcher APK with the bare SDK tools (no Gradle)
# and install it on the TV as the home screen.
#   launcher\build-and-install.ps1 192.168.8.114            build + install
#   launcher\build-and-install.ps1 -Build                   build only
param([string]$Tv, [switch]$Build)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
$jdk = if ($env:JAVA_HOME_21) { $env:JAVA_HOME_21 } else { (Get-Item "C:\Program Files\Microsoft\jdk-21*").FullName }
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "$env:LOCALAPPDATA\Android\Sdk" }
# Target the latest API: Play Protect blocks installs of apps built for older Android versions.
$api = 36
$bt = "$sdk\build-tools\$api.0.0"; $jar = "$sdk\platforms\android-$api\android.jar"; $adb = "$sdk\platform-tools\adb.exe"
# Google TV stock launcher; older Android TV sets use com.google.android.tvlauncher.
$stock = if ($env:STOCK_LAUNCHER) { $env:STOCK_LAUNCHER } else { "com.google.android.apps.tv.launcherx" }
# Pipe flattens array arguments (file lists) into separate native args.
function Run { & $args[0] @($args | Select-Object -Skip 1 | % { $_ }); if ($LASTEXITCODE) { throw "failed: $($args[0])" } }

$B = "build"
Remove-Item -Recurse -Force $B -EA SilentlyContinue
New-Item -ItemType Directory "$B\gen", "$B\classes", "$B\dex" | Out-Null
Run "$bt\aapt2.exe" compile --dir res -o "$B\res.zip"
Run "$bt\aapt2.exe" link -o "$B\unsigned.apk" -I $jar --manifest AndroidManifest.xml --java "$B\gen" `
  --min-sdk-version 30 --target-sdk-version $api "$B\res.zip"
Run "$jdk\bin\javac.exe" -nowarn '-Xlint:-options' --release 11 -classpath $jar -d "$B\classes" `
  @(Get-ChildItem src, "$B\gen" -Recurse -Filter *.java | % FullName)
Run "$bt\d8.bat" --min-api 30 --lib $jar --output "$B\dex" @(Get-ChildItem "$B\classes" -Recurse -Filter *.class | % FullName)
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z = [IO.Compression.ZipFile]::Open("$PWD\$B\unsigned.apk", "Update")
[void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($z, "$PWD\$B\dex\classes.dex", "classes.dex")
# Assets added here, not via aapt2 -A: on Windows aapt2 writes "assets/wallpapers\01.jpg" and Android can't list them.
foreach ($f in Get-ChildItem assets -Recurse -File) {
  $name = "assets/" + $f.FullName.Substring("$PWD\assets\".Length).Replace('\', '/')
  [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($z, $f.FullName, $name, "NoCompression")
}
$z.Dispose()
Run "$bt\zipalign.exe" -f 4 "$B\unsigned.apk" "$B\aligned.apk"
if (-not (Test-Path debug.keystore)) {
  Run "$jdk\bin\keytool.exe" -genkeypair -keystore debug.keystore -storepass android -keypass android `
    -alias tvhome -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=tvhome"
}
$env:JAVA_HOME = $jdk
Run "$bt\apksigner.bat" sign --ks debug.keystore --ks-pass pass:android --out "$B\tvhome.apk" "$B\aligned.apk"
"built $B\tvhome.apk ($((Get-Item "$B\tvhome.apk").Length) bytes)"
if ($Build) { exit 0 }

$s = "$($Tv):5555"
Run $adb -s $s install -r "$B\tvhome.apk"
# One pm call per shell command; chained pm calls can stop early.
foreach ($c in "pm grant com.mihir.tvhome android.permission.ACCESS_FINE_LOCATION",
               "cmd package set-home-activity --user 0 com.mihir.tvhome/.MainActivity",
               "pm disable-user --user 0 $stock",
               "pm disable-user --user 0 com.google.android.tungsten.setupwraith",
               "cmd package set-home-activity --user 0 com.mihir.tvhome/.MainActivity",
               "am force-stop com.android.tv.settings",
               "input keyevent KEYCODE_HOME") {
  "$c -> " + (& $adb -s $s shell $c 2>&1)
}
"Installed. Press Home on the remote."
