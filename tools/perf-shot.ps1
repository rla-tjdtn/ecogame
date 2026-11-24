# 측정용 Studio 창 한 개를 PNG 로 찍는다(다른 창에 가려져도 PrintWindow 로 그 창 내용만).
#   powershell -File tools/perf-shot.ps1 -Title <제목 일부> -Out <file.png>
param([string]$Title, [string]$Out)
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;using System.Runtime.InteropServices;
public class PS{[DllImport("user32.dll")]public static extern bool GetWindowRect(IntPtr h,out R r);[DllImport("user32.dll")]public static extern bool PrintWindow(IntPtr h,IntPtr dc,uint f);[DllImport("user32.dll")]public static extern bool IsIconic(IntPtr h);[DllImport("user32.dll")]public static extern bool ShowWindow(IntPtr h,int c);
public struct R{public int l,t,r,b;}}
'@
$p = Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like "*$Title*" } | Select-Object -First 1
if (-not $p) { "no window $Title"; exit 1 }
$h = $p.MainWindowHandle
# (최소화된 창은 제목 줄만 찍힌다: 활성화 없이 원래 크기로)
if ([PS]::IsIconic($h)) { [void][PS]::ShowWindow($h, 4); Start-Sleep -Milliseconds 700 }
$r = New-Object PS+R; [void][PS]::GetWindowRect($h, [ref]$r)
$w = $r.r - $r.l; $hh = $r.b - $r.t
$bmp = New-Object System.Drawing.Bitmap $w, $hh
$g = [System.Drawing.Graphics]::FromImage($bmp)
$dc = $g.GetHdc(); [void][PS]::PrintWindow($h, $dc, 2); $g.ReleaseHdc($dc)
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
"saved $Out ($w x $hh)"
