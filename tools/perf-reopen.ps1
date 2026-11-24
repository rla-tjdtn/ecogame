# 측정용 Studio 창 열기·닫기(여러 창을 동시에 써도 서로 건드리지 않게, 플레이스 파일 이름으로 고른다).
#   powershell -File tools/perf-reopen.ps1 -Close <이름 일부>   : 제목에 그 이름이 든 Studio 창만 정상 종료(저장 안 함 — 강제 종료 아님)
#   powershell -File tools/perf-reopen.ps1 -Open <place.rbxlx>  : 그 플레이스로 새 Studio 창
#   (둘 다 주면 닫고 나서 연다)
#   powershell -File tools/perf-reopen.ps1 -Focus <이름 일부>   : 그 창을 앞으로(비활성 창은 15fps 로 묶여 시간 측정이 흔들린다)
param([string]$Close, [string]$Open, [string]$Focus)
Add-Type @'
using System;using System.Text;using System.Collections.Generic;using System.Runtime.InteropServices;
public class PW{ public delegate bool E(IntPtr h,IntPtr l);[DllImport("user32.dll")]public static extern bool EnumWindows(E e,IntPtr l);[DllImport("user32.dll")]public static extern uint GetWindowThreadProcessId(IntPtr h,out uint p);[DllImport("user32.dll")]public static extern bool IsWindowVisible(IntPtr h);[DllImport("user32.dll")]public static extern bool GetWindowRect(IntPtr h,out R r);[DllImport("user32.dll")]public static extern bool PostMessage(IntPtr h,uint m,IntPtr w,IntPtr l);
public struct R{public int l,t,r,b;}
public static List<IntPtr> Of(uint pid){var o=new List<IntPtr>();EnumWindows((h,l)=>{uint p;GetWindowThreadProcessId(h,out p);if(p==pid&&IsWindowVisible(h))o.Add(h);return true;},IntPtr.Zero);return o;}
public static void Click(IntPtr h,int x,int y){IntPtr l=(IntPtr)((y<<16)|x);PostMessage(h,0x200,IntPtr.Zero,l);PostMessage(h,0x201,(IntPtr)1,l);PostMessage(h,0x202,IntPtr.Zero,l);}}
'@
$exe = "$env:LOCALAPPDATA\Roblox\Versions\version-8d7a1009c17e4ff8\RobloxStudioBeta.exe"
if ($Close) {
	$pids = @(Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like "*$Close*" } | ForEach-Object { $_.Id })
	foreach ($i in 1..12) {
		$live = @($pids | Where-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue })
		if ($live.Count -eq 0) { break }
		foreach ($id in $live) {
			$q = Get-Process -Id $id -ErrorAction SilentlyContinue
			if (-not $q) { continue }
			# "저장할까요?" 창(366x141)이 떠 있으면 "저장 안 함"
			$dlg = $null
			foreach ($h in [PW]::Of($q.Id)) { $r = New-Object PW+R; [void][PW]::GetWindowRect($h, [ref]$r); if (($r.r - $r.l) -eq 366 -and ($r.b - $r.t) -eq 141) { $dlg = $h } }
			if ($dlg) { [PW]::Click($dlg, 250, 78) } else { [void]$q.CloseMainWindow() }
		}
		Start-Sleep 5
	}
	$left = @($pids | Where-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue })
	if ($left.Count -gt 0) { "still open ($Close); not forcing"; exit 1 }
	"closed $Close"
}
if ($Focus) {
	Add-Type @'
using System;using System.Runtime.InteropServices;
public class PF{[DllImport("user32.dll")]public static extern bool SetForegroundWindow(IntPtr h);[DllImport("user32.dll")]public static extern bool ShowWindow(IntPtr h,int c);[DllImport("user32.dll")]public static extern void keybd_event(byte k,byte s,uint f,UIntPtr e);}
'@
	$q = Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like "*$Focus*" } | Select-Object -First 1
	if ($q) {
		[PF]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [PF]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero) # (Alt 를 눌렀다 떼야 다른 프로그램 창을 앞으로 가져올 수 있다)
		[void][PF]::ShowWindow($q.MainWindowHandle, 9)
		"focus " + [PF]::SetForegroundWindow($q.MainWindowHandle)
	} else { "no window $Focus" }
}
if ($Open) {
	Start-Process $exe -ArgumentList "`"$Open`""
	"opened $Open"
}
