#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_AU3Check_Parameters=-d -w 1 -w 2 -w 3 -w 4 -w 5 -w 6
#AutoIt3Wrapper_icon=..\..\App\AppInfo\appicon.ico
#AutoIt3Wrapper_outfile=..\..\App\EraserDrop\EraserDrop.exe
#AutoIt3Wrapper_Compression=4
#AutoIt3Wrapper_Res_Comment=Drop files or folders onto the target to securely erase.
#AutoIt3Wrapper_Res_Description=EraserDrop
#AutoIt3Wrapper_Res_Fileversion=2.1.0.0
#AutoIt3Wrapper_Res_LegalCopyright=by Erik Pilsits
#AutoIt3Wrapper_Res_Language=1033
#AutoIt3Wrapper_Res_requestedExecutionLevel=asInvoker
#AutoIt3Wrapper_Run_Obfuscator=y
#Obfuscator_Parameters=/sf=1 /sv=1 /om /cs=0 /cn=0
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#NoTrayIcon

#include <GUIConstantsEx.au3>
#include <GUIListView.au3>
#include <WindowsConstants.au3>
#include <ComboConstants.au3>
#include <Constants.au3>
#include <Array.au3>
#include <Misc.au3>
#include <WinAPI.au3>
#include <GDIPlus.au3>
#include <Security.au3>
#include <Date.au3>
#include <_EraserAPI.au3>
#include <_RegFunc.au3>
#include <_OsVersionInfo.au3>

Opt("GUIOnEventMode", 1) ; set OnEvent mode
Opt("GUICloseOnESC", 0) ; disable ESC to exit
Opt("TrayMenuMode", 1+2) ; disable tray menu, don't auto-check items
Opt("TrayOnEventMode", 1) ; enable tray events
Opt("MustDeclareVars", 1) ; must declare vars before use
Opt("WinTitleMatchMode", 3) ; exact title match

; MasterQueue:  1D array = <context>,<mode>
; Mode:  1 = Normal, 2 = Recycle Bin, 3 = Freespace

Global Const $AC_SRC_ALPHA = 1
;~ Global Const $ULW_ALPHA = 2
Global Const $WM_DROPFILES = 0x233
Global Const $SHCNE_RMDIR = 0x10
Global Const $SHCNF_PATHW = 0x5
Global Const $SHCNF_PATH = $SHCNF_PATHW
Global Const $SHERB_NOCONFIRMATION = 0x1
Global Const $SHERB_NOPROGRESSUI = 0x2
Global Const $SHERB_NOSOUND = 0x4

Global Const $configini = @ScriptDir & "\config.ini"

Global $key = "", $oldsilent, $Terminated, $GlobalFileCount = 0, $dummy
Global $hotkey, $hottip, $hImage, $widthGUI, $heightGUI
Global $nGUI, $ClickMenu, $TasksMenu, $Recycle, $Freespace, $OptionsMenu, $MethodMenu, $methodGutmann, $methodDoD, $methodSchneier, $methodDoD_E, $methodRandom
Global $WarnMenu, $ShowReportMenu, $TipsMenu, $OnTopMenu, $HotkeyMenu, $TargetImage, $ResetImage, $ReloadMenu, $HideMenu, $TerminateMenu, $HelpMenu, $AboutMenu, $ExitMenu
Global $FlashMenu, $AnimateMenu, $doFlash, $doAnimation
Global $dGUI, $cDrive, $bOK, $bCancel, $lDrives
Global $hGUI, $hCTRL, $hALT, $hSHIFT, $hCombo, $hSave, $hCancel
Global $trayTerminate, $trayHide, $trayAbout, $trayExit
Global $Eraser_Msg, $MasterQueue[1] = [0], $FolderArray[1] = [0]
Global $CmdMsg, $CmdMsg_msg = -1
; gdi+ globals
Global $hBitmap = 0, $hScrDc = 0, $hMemDC = 0
Global $tSize, $pSize, $tSource, $pSource, $tBlend, $pBlend

$CmdMsg = _WinAPI_RegisterWindowMessage("EraserDrop_CustomMessage")

#Region ; Commandline
If _Singleton(@ScriptName, 1) = 0 Then
	; commandline mode
	If $CmdLine[0] > 0 Then
		Switch $CmdLine[1]
			Case "exit"
				$CmdMsg_msg = 0
		EndSwitch
		If $CmdMsg_msg <> -1 Then _SendMessage(WinGetHandle("EraserDrop"), $CmdMsg, $CmdMsg_msg, 0)
	EndIf
	Exit
Else
	TraySetState()
EndIf
#EndRegion
#Region ; Init
; initialize Eraser library, _EraserInit() does NOT create the reg key
If Not _EraserOK(_EraserInit()) Then
	MsgBox(0 + 16, "Eraser", "Error initializing the Eraser library.")
	Exit
EndIf
$Eraser_Msg = _WinAPI_RegisterWindowMessage("ERASER_NOTIFY_MESSAGE")

; tray icon
; -7 = primary mouse button down
TraySetOnEvent(-7, "ShowGUI")
TraySetClick(8) ; right-click tray menu
$trayTerminate = TrayCreateItem("Terminate All Jobs")
$trayHide = TrayCreateItem("Hide")
TrayCreateItem("")
$trayAbout = TrayCreateItem("About...")
TrayCreateItem("")
$trayExit = TrayCreateItem("Exit")
TrayItemSetOnEvent($trayTerminate, "TerminateJobs")
TrayItemSetOnEvent($trayHide, "HideGUI")
TrayItemSetOnEvent($trayAbout, "AboutMenu")
TrayItemSetOnEvent($trayExit, "GUIClose")

; check reg key
If Not _RegKeyExists("HKCU\Software\Heidi Computers Ltd") Then $key = "delete" ; if key does not exist, delete it later

; fix new report ini value
$oldsilent = IniRead($configini, "eraser", "runsilent", "missing")
If $oldsilent <> "missing" Then
	; old value exists
	If $oldsilent = "1" Then
		IniWrite($configini, "eraser", "showreport", "0")
	Else
		IniWrite($configini, "eraser", "showreport", "1")
	EndIf
	IniDelete($configini, "eraser", "runsilent")
EndIf

; load GUI
_GDIPlus_Startup() ; start GDI+
LoadGUI()

; set version/OS Version
Global $version = FileGetVersion(@ScriptFullPath)
Global $fOSGrEqVista = _OsVersionTest($VER_GREATER_EQUAL, 6)
; open readme if first run
If "0" <> IniRead($configini, "eraser", "firstrun", "1") Then
	ShellExecute(@ScriptDir & "\Readme.txt", "", @ScriptDir, "open")
	IniWrite($configini, "eraser", "firstrun", "0")
EndIf
#EndRegion
; GUI loop
Global $AniDirection = 1, $AniOpacity = 255, $isVisible = True, $isRunning = False, $doneWipe = False
While 1
	If $doAnimation And $isRunning Then
		; user wants ani and eraser is running
		If $isVisible Then
			; only if gui is visible
			If $AniOpacity = 255 Then
				$AniDirection = 1
				Sleep(100)
			ElseIf $AniOpacity = 75 Then
				$AniDirection = 0
				Sleep(100)
			EndIf
			$AniOpacity += 5 - ($AniDirection * 10)
			SetBitmap($nGUI, $AniOpacity)
			Sleep(40)
		Else
			; gui is hidden, make sure it starts at 255 on showing
			$AniOpacity = 255
			Sleep(1000)
		EndIf
	Else
		; no animation or done erasing
		If $doneWipe Then
			; finished wipe, reset to 255 if visible (not hidden); only do this once
			$doneWipe = False
			$AniOpacity = 255
			If $isVisible Then SetBitmap($nGUI, 255)
		EndIf
		Sleep(1000)
	EndIf
WEnd

#Region ; Notify Funcs
;===================================================================================
; Notify Functions
;===================================================================================
Func _MY_WM_DROPFILES($hWnd, $Msg, $wParam, $lParam)
	#forceref $hWnd, $Msg, $wParam, $lParam
    Local $objtowipe, $passes

	; warn?
	If "1" = IniRead($configini, "eraser", "warn", "1") Then
		If 7 = MsgBox(4 + 32, "Eraser", "Wipe all selected file(s) and folder(s)?") Then Return 1
	EndIf

	; read Eraser options
	Local $method = _EraserConvertMethod()
	If $method = "" Then Return 1
	If $method = $RANDOM_METHOD_ID Then
		$passes = Number(IniRead($configini, "eraser", "pseudo_passes", "1"))
	Else
		$passes = -1
	EndIf

	; create Eraser context
	Local $context = _EraserCreateContextEx($method, $passes)
	If Not _EraserOK(_EraserIsValidContext($context)) Then
		MsgBox(0 + 48, "Eraser", "Error creating Eraser Context.")
		Return 1
	EndIf
	_EraserSetDataType($context, $ERASER_DATA_FILES)
	; register window message
	_EraserSetWindow($context, $nGUI)
	_EraserSetWindowMessage($context, $Eraser_Msg)
	; set context and mode to master queue
	$MasterQueue[0] += 1
	_ArrayAdd($MasterQueue, $context & ",1")
	; add folder job
	_AddEraserFolderJob($FolderArray)

    ; string buffer for file path
    Local $tDrop = DllStructCreate("char[260]")
    ; get file count
	Local $dll = DllOpen("shell32.dll")
    Local $aRet = DllCall($dll, "int", "DragQueryFile", _
							"hwnd", $wParam, _
							"uint", -1, _
							"ptr", DllStructGetPtr($tDrop), _
							"int", DllStructGetSize($tDrop) _
							)
    Local $iCount = $aRet[0]
    ; get file paths
    For $i = 0 To $iCount - 1
        $aRet = DllCall($dll, "int", "DragQueryFile", _
								"hwnd", $wParam, _
								"uint", $i, _
								"ptr", DllStructGetPtr($tDrop), _
								"int", DllStructGetSize($tDrop) _
								)
        $objtowipe = DllStructGetData($tDrop, 1)
		If StringInStr(FileGetAttrib($objtowipe), "D") Then
			; folder
			_EraserParseFolder($objtowipe, $context, $FolderArray)
		Else
			; file
			_EraserAddItem($context, $objtowipe)
			$GlobalFileCount += 1
		EndIf
    Next
    ; finalize
    DllCall($dll, "int", "DragFinish", "hwnd", $wParam)
	DllClose($dll)

	; set file count and reset var
	$MasterQueue[$MasterQueue[0]] &= "," & $GlobalFileCount
	$GlobalFileCount = 0
	; reverse folder order
	_TrimFolderArrayJob($FolderArray)
	; start Eraser
	GUICtrlSendToDummy($dummy, 1) ; _EraserStartWipe()
EndFunc

Func _MY_ERASER_NOTIFY($hWnd, $Msg, $wParam, $lParam)
	#forceref $hWnd, $Msg, $wParam, $lParam
	Switch $wParam
		Case $ERASER_WIPE_UPDATE
			_EraserWipeUpdate()
		Case $ERASER_WIPE_DONE
			GUICtrlSendToDummy($dummy, 2) ; _EraserWipeDone()
	EndSwitch
EndFunc

Func _MY_WM_NOTIFY($hWnd, $Msg, $wParam, $lParam)
	#forceref $hWnd, $Msg, $wParam, $lParam
    Local $tNMHDR = DllStructCreate($tagNMHDR, $lParam)
    Local $iCode = DllStructGetData($tNMHDR, "Code")

    Switch $iCode
		Case $LVN_BEGINDRAG, $LVN_BEGINRDRAG
			Return 1
	EndSwitch
	Return $GUI_RUNDEFMSG
EndFunc

Func _MY_CUSTOM_MSG($hWnd, $Msg, $wParam, $lParam)
	#forceref $hWnd, $Msg, $wParam, $lParam
	Switch $Msg
		Case $CmdMsg
			Switch $wParam
				Case 0
					GUIClose()
			EndSwitch
	EndSwitch
EndFunc

Func _DummyEvent()
	Switch GUICtrlRead($dummy)
		Case 1
			_EraserStartWipe()
		Case 2
			_EraserWipeDone()
	EndSwitch
EndFunc
#EndRegion
#Region ; Main Funcs
;===================================================================================
; Main Functions
;===================================================================================
Func LoadGUI()
	; read and set hotkey, blank = disabled
	$hotkey = IniRead($configini, "eraser", "hotkey", "")
	If $hotkey <> "" Then HotKeySet($hotkey, "HideGUI")
	; Load PNG file as GDI bitmap
	Local $pngImg = IniRead($configini, "eraser", "image", "")
	If $pngImg = "" Then
		$pngImg = "\eraser.png"
	Else
		$pngImg = "\..\..\Data\images\" & $pngImg
	EndIf
	Local $pngSrc = @ScriptDir & $pngImg
	; fall back to default if can't find custom image, reset INI
	If Not FileExists($pngSrc) Then
		$pngSrc = @ScriptDir & "\eraser.png"
		IniWrite($configini, "eraser", "image", "")
	EndIf
	$hImage = _GDIPlus_ImageLoadFromFile($pngSrc)
	; extract image width and height from PNG
	$widthGUI = _GDIPlus_ImageGetWidth($hImage)
	$heightGUI = _GDIPlus_ImageGetHeight($hImage)

	Local $aDesktop = WinGetPos("Program Manager")
	Local $xGUI = Number(IniRead($configini, "eraser", "x", "100"))
	If $xGUI > $aDesktop[2] - $widthGUI  Then
		$xGUI = $aDesktop[2] - $widthGUI
	ElseIf $xGUI < 0 Then
		$xGUI = 0
	EndIf
	Local $yGUI = Number(IniRead($configini, "eraser", "y", "100"))
	If $yGUI > $aDesktop[3] - $heightGUI Then
		$yGUI = $aDesktop[3] - $heightGUI
	ElseIf $yGUI < 0 Then
		$yGUI = 0
	EndIf

	; Create GUI
	$nGUI = GUICreate("EraserDrop", $widthGUI, $heightGUI, $xGUI, $yGUI, $WS_POPUP, BitOR($WS_EX_ACCEPTFILES, $WS_EX_TOPMOST, $WS_EX_LAYERED, $WS_EX_TOOLWINDOW))
	$dummy = GUICtrlCreateDummy()
	GUICtrlSetOnEvent($dummy, "_DummyEvent")
	GUISetCursor(0)
	; set png background
	_CleanGDIP()
	_InitGDIP($hImage)
	SetBitmap($nGUI, 0)

	; register messages
	GUIRegisterMsg($WM_DROPFILES, "_MY_WM_DROPFILES")
	GUIRegisterMsg($Eraser_Msg, "_MY_ERASER_NOTIFY")
	GUIRegisterMsg($WM_NOTIFY, "_MY_WM_NOTIFY")
	GUIRegisterMsg($CmdMsg, "_MY_CUSTOM_MSG")

	; read # of random passes
	Local $passes = Number(IniRead($configini, "eraser", "pseudo_passes", "-1"))
	; if value = -1, use default of 1 and write to INI
	If $passes = -1 Then
		$passes = 1
		IniWrite($configini, "eraser", "pseudo_passes", "1")
	EndIf

	; context menu
	$ClickMenu = GUICtrlCreateContextMenu()
		$TasksMenu = GUICtrlCreateMenu("Tasks", $ClickMenu)
			$Recycle = GUICtrlCreateMenuItem("Wipe Recycle Bin", $TasksMenu)
			$Freespace = GUICtrlCreateMenuItem("Wipe Free Space...", $TasksMenu)
		$OptionsMenu = GUICtrlCreateMenu("Options", $ClickMenu)
			$MethodMenu = GUICtrlCreateMenu("Eraser Method", $OptionsMenu)
				$methodGutmann = GUICtrlCreateMenuItem("Gutmann (Most Secure / Slowest) [35 passes]", $MethodMenu, 0)
				$methodDoD = GUICtrlCreateMenuItem("DoD 8-306 E, C and E (More Secure / Slower) [7 passes]", $MethodMenu, 1)
				$methodSchneier = GUICtrlCreateMenuItem("Schneier's Method (More Secure / Slower) [7 passes]", $MethodMenu, 2)
				$methodDoD_E = GUICtrlCreateMenuItem("DoD 8-306 E (Secure / Average Speed) [3 passes]", $MethodMenu, 3)
				$methodRandom = GUICtrlCreateMenuItem("Pseudorandom (Custom) [" & $passes & " pass(es)]", $MethodMenu, 4)
			GUICtrlCreateMenuItem("", $OptionsMenu)
			$WarnMenu = GUICtrlCreateMenuItem("Warn Before Erasing", $OptionsMenu)
			$ShowReportMenu = GUICtrlCreateMenuItem("Show Erasing Report", $OptionsMenu)
			$TipsMenu = GUICtrlCreateMenuItem("Show Tray Tips", $OptionsMenu)
			$FlashMenu = GUICtrlCreateMenuItem("Flash Tray Icon", $OptionsMenu)
			$AnimateMenu = GUICtrlCreateMenuItem("Animate GUI", $OptionsMenu)
			$OnTopMenu = GUICtrlCreateMenuItem("Always On Top", $OptionsMenu)
			GUICtrlCreateMenuItem("", $OptionsMenu)
			$HotkeyMenu = GUICtrlCreateMenuItem("Set Hotkey...", $OptionsMenu)
			$TargetImage = GUICtrlCreateMenuItem("Change Target Image...", $OptionsMenu)
			$ResetImage = GUICtrlCreateMenuItem("Reset Target Image", $OptionsMenu)
		GUICtrlCreateMenuItem("", $ClickMenu)
		$ReloadMenu = GUICtrlCreateMenuItem("Reload", $ClickMenu)
		$HideMenu = GUICtrlCreateMenuItem("Hide", $ClickMenu)
		GUICtrlCreateMenuItem("", $ClickMenu)
		$TerminateMenu = GUICtrlCreateMenuItem("Terminate All Jobs", $ClickMenu)
		GUICtrlCreateMenuItem("", $ClickMenu)
		$HelpMenu = GUICtrlCreateMenuItem("Help", $ClickMenu)
		$AboutMenu = GUICtrlCreateMenuItem("About...", $ClickMenu)
		GUICtrlCreateMenuItem("", $ClickMenu)
		$ExitMenu = GUICtrlCreateMenuItem("Exit", $ClickMenu)

	; set options checks
	; on top
	Switch IniRead($configini, "eraser", "ontop", "")
		Case "1"
			GUICtrlSetState($OnTopMenu, $GUI_CHECKED)
		Case "0"
			GUICtrlSetState($OnTopMenu, $GUI_UNCHECKED)
			WinSetOnTop($nGUI, "", 0)
		Case Else
			GUICtrlSetState($OnTopMenu, $GUI_CHECKED)
			IniWrite($configini, "eraser", "ontop", "1")
	EndSwitch
	; method
	Switch IniRead($configini, "eraser", "method", "")
		Case "Gutmann"
			GUICtrlSetState($methodGutmann, $GUI_CHECKED)
		Case "DoD"
			GUICtrlSetState($methodDoD, $GUI_CHECKED)
		Case "Schneier"
			GUICtrlSetState($methodSchneier, $GUI_CHECKED)
		Case "DoD_E"
			GUICtrlSetState($methodDoD_E, $GUI_CHECKED)
		Case Else
			GUICtrlSetState($methodRandom, $GUI_CHECKED)
			IniWrite($configini, "eraser", "method", "Random")
	EndSwitch
	; warn
	Switch IniRead($configini, "eraser", "warn", "")
		Case "1"
			GUICtrlSetState($WarnMenu, $GUI_CHECKED)
		Case "0"
			GUICtrlSetState($WarnMenu, $GUI_UNCHECKED)
		Case Else
			GUICtrlSetState($WarnMenu, $GUI_CHECKED)
			IniWrite($configini, "eraser", "warn", "1")
	EndSwitch
	; report
	Switch IniRead($configini, "eraser", "showreport", "")
		Case "1"
			GUICtrlSetState($ShowReportMenu, $GUI_CHECKED)
		Case "0"
			GUICtrlSetState($ShowReportMenu, $GUI_UNCHECKED)
		Case Else
			GUICtrlSetState($ShowReportMenu, $GUI_CHECKED)
			IniWrite($configini, "eraser", "showreport", "1")
	EndSwitch
	; tips
	Switch IniRead($configini, "eraser", "showtips", "")
		Case "1"
			GUICtrlSetState($TipsMenu, $GUI_CHECKED)
		Case "0"
			GUICtrlSetState($TipsMenu, $GUI_UNCHECKED)
		Case Else
			GUICtrlSetState($TipsMenu, $GUI_CHECKED)
			IniWrite($configini, "eraser", "showtips", "1")
	EndSwitch
	; flash tray
	$doFlash = Number(IniRead($configini, "eraser", "flashtray", 1))
	Switch $doFlash
		Case 1
			GUICtrlSetState($FlashMenu, $GUI_CHECKED)
		Case 0
			GUICtrlSetState($FlashMenu, $GUI_UNCHECKED)
		Case Else
			GUICtrlSetState($FlashMenu, $GUI_CHECKED)
			IniWrite($configini, "eraser", "flashtray", "1")
	EndSwitch
	; animate gui
	$doAnimation = Number(IniRead($configini, "eraser", "doanimation", 0))
	Switch $doAnimation
		Case 1
			GUICtrlSetState($AnimateMenu, $GUI_CHECKED)
		Case 0
			GUICtrlSetState($AnimateMenu, $GUI_UNCHECKED)
		Case Else
			GUICtrlSetState($AnimateMenu, $GUI_CHECKED)
			IniWrite($configini, "eraser", "doanimation", "1")
	EndSwitch

	; GUI Events
	GUISetOnEvent($GUI_EVENT_CLOSE, "GUIClose")
	GUISetOnEvent($GUI_EVENT_PRIMARYDOWN, "MoveGUI")

	; control events
	GUICtrlSetOnEvent($Recycle, "Recycle")
	GUICtrlSetOnEvent($Freespace, "Freespace")
	GUICtrlSetOnEvent($ReloadMenu, "ReloadGUI")
	GUICtrlSetOnEvent($HideMenu, "HideGUI")
	GUICtrlSetOnEvent($TerminateMenu, "TerminateJobs")
	GUICtrlSetOnEvent($HelpMenu, "HelpMenu")
	GUICtrlSetOnEvent($AboutMenu, "AboutMenu")
	GUICtrlSetOnEvent($ExitMenu, "GUIClose")
	; methods
	GUICtrlSetOnEvent($methodGutmann, "EraseMethod")
	GUICtrlSetOnEvent($methodDoD, "EraseMethod")
	GUICtrlSetOnEvent($methodSchneier, "EraseMethod")
	GUICtrlSetOnEvent($methodDoD_E, "EraseMethod")
	GUICtrlSetOnEvent($methodRandom, "EraseMethod")
	; toggles
	GUICtrlSetOnEvent($WarnMenu, "WarnMenu")
	GUICtrlSetOnEvent($ShowReportMenu, "ShowReport")
	GUICtrlSetOnEvent($TipsMenu, "ShowTips")
	GUICtrlSetOnEvent($OnTopMenu, "OnTop")
	GUICtrlSetOnEvent($FlashMenu, "FlashTray")
	GUICtrlSetOnEvent($AnimateMenu, "AnimateGUI")
	; change target image
	GUICtrlSetOnEvent($TargetImage, "TargetImage")
	GUICtrlSetOnEvent($ResetImage, "ResetImage")
	; set hotkey
	GUICtrlSetOnEvent($HotkeyMenu, "HotkeyMenu")

	; tray tip
	If $hotkey = "" Then
		$hottip = "disabled"
	Else
		_GetHottip()
	EndIf
	TraySetToolTip("EraserDrop" & @CRLF & "HotKey = " & $hottip)

	; show GUI
	GUISetState(@SW_SHOW, $nGUI)
	;fade in png background
	For $i = 0 to 255 step 10
		SetBitmap($nGUI, $i)
	Next
	_ReduceMemory()
EndFunc

Func _GetHottip()
	$hottip = "" ; clear hottip

	Local $mods = StringLeft($hotkey, StringInStr($hotkey, "{") - 1)
	Local $key = StringTrimRight(StringTrimLeft($hotkey, StringInStr($hotkey, "{")), 1)

	If StringInStr($mods, "^") Then $hottip &= "CTRL+"
	If StringInStr($mods, "!") Then $hottip &= "ALT+"
	If StringInStr($mods, "+") Then $hottip &= "SHIFT+"
	$hottip &= $key
EndFunc

Func _InitGDIP($hImage)
	$hScrDC = _WinAPI_GetDC($nGUI)
	$hMemDC = _WinAPI_CreateCompatibleDC($hScrDC)
	$hBitmap = _GDIPlus_BitmapCreateHBITMAPFromBitmap($hImage)
	_WinAPI_SelectObject($hMemDC, $hBitmap)
	$tSize = DllStructCreate($tagSIZE)
	$pSize = DllStructGetPtr($tSize)
	DllStructSetData($tSize, "X", $widthGUI)
	DllStructSetData($tSize, "Y", $heightGUI)
	$tSource = DllStructCreate($tagPOINT)
	$pSource = DllStructGetPtr($tSource)
	$tBlend = DllStructCreate($tagBLENDFUNCTION)
	$pBlend = DllStructGetPtr($tBlend)
	DllStructSetData($tBlend, "Format", $AC_SRC_ALPHA)
EndFunc

Func _CleanGDIP()
	If $hBitmap Then
;~ 		_WinAPI_SelectObject($hMemDC, $hOld)
		_WinAPI_DeleteObject($hBitmap)
		_WinAPI_DeleteDC($hMemDC)
		_WinAPI_ReleaseDC($nGUI, $hScrDC)
	EndIf
EndFunc

Func SetBitmap($GUI, $iOpacity)
	; widthGUI and heightGUI are set/reset in LoadGUI()
	DllStructSetData($tBlend, "Alpha", $iOpacity)
	_WinAPI_UpdateLayeredWindow($GUI, $hScrDC, 0, $pSize, $hMemDC, $pSource, 0, $pBlend, $ULW_ALPHA)
EndFunc

Func _ReduceMemory($i_PID = -1)
	; PROCESS_SET_INFORMATION | PROCESS_QUERY_INFORMATION = 0x0600
	Local $ai_Return

	If $i_PID <> -1 Then
		Local $ai_Handle = DllCall('kernel32.dll', 'ptr', 'OpenProcess', 'dword', 0x0600, 'int', False, 'dword', $i_PID)
		$ai_Return = DllCall('psapi.dll', 'int', 'EmptyWorkingSet', 'ptr', $ai_Handle[0])
		DllCall('kernel32.dll', 'int', 'CloseHandle', 'ptr', $ai_Handle[0])
	Else
		$ai_Return = DllCall('psapi.dll', 'int', 'EmptyWorkingSet', 'ptr', -1)
	EndIf
	Return $ai_Return[0]
EndFunc   ;==> _ReduceMemory()

Func MoveGUI()
	; 0xA0 = LSHIFT
	; 0x01 = LMOUSE
	If _IsPressed("A0") Then
		Local $aPos = WinGetPos($nGUI)
		Local $mPos = MouseGetPos()
		Local $xOfst = $mPos[0] - $aPos[0]
		Local $yOfst = $mPos[1] - $aPos[1]
		Local $dll = DllOpen("user32.dll")
		While _IsPressed("01", $dll) And _IsPressed("A0", $dll)
			Sleep(10)
			$mPos = MouseGetPos()
			WinMove($nGUI, "", $mPos[0] - $xOfst, $mPos[1] - $yOfst)
		WEnd
		DllClose($dll)
		; save window position
		$aPos = WinGetPos($nGUI)
		IniWrite($configini, "eraser", "x", $aPos[0])
		IniWrite($configini, "eraser", "y", $aPos[1])
	EndIf
EndFunc

Func ReloadGUI()
	; save window position
	Local $aPos = WinGetPos($nGUI)
	IniWrite($configini, "eraser", "x", $aPos[0])
	IniWrite($configini, "eraser", "y", $aPos[1])
	;fade out png background
	For $i = 255 to 0 step -15
		SetBitmap($nGUI, $i)
	Next
	; Release resources
	GUIDelete($nGUI)
	_WinAPI_DeleteObject($hImage)
	; reload GUI
	LoadGUI()
EndFunc

Func HideGUI()
	; 2 = visible
	If $isVisible Then ; window is visible
		;fade out png background
		For $i = 255 to 0 step -15
			SetBitmap($nGUI, $i)
		Next
		; hide GUI
		WinSetState($nGUI, "", @SW_HIDE)
		; set hotkey if not disabled
		If $hotkey <> "" Then HotKeySet($hotkey, "ShowGUI")
		; disable Hide item
		TrayItemSetState($trayHide, $TRAY_DISABLE)
		$isVisible = False
	EndIf
EndFunc

Func ShowGUI()
	If Not $isVisible Then ; window is not visible
		; set hotkey if not disabled
		If $hotkey <> "" Then HotKeySet($hotkey, "HideGUI")
		; enable Hide item
		TrayItemSetState($trayHide, $TRAY_ENABLE)
		; show gui
		SetBitmap($nGUI, 0) ; make sure we start at 0
		WinSetState($nGUI, "", @SW_SHOW)
		;fade in png background
		For $i = 0 to 255 step 15
			SetBitmap($nGUI, $i)
		Next
		$isVisible = True
	EndIf
EndFunc

Func HelpMenu()
	ShellExecute(@ScriptDir & "\Readme.txt", "", @ScriptDir, "open")
EndFunc

Func AboutMenu()
	MsgBox(0 + 64, "About...", "EraserDrop" & @CRLF & "v" & $version & @CRLF & @CRLF & "by Erik Pilsits", 0, $nGUI)
EndFunc

Func EraseMethod()
	; uncheck all
	GUICtrlSetState($methodGutmann, $GUI_UNCHECKED)
	GUICtrlSetState($methodDoD, $GUI_UNCHECKED)
	GUICtrlSetState($methodSchneier, $GUI_UNCHECKED)
	GUICtrlSetState($methodDoD_E, $GUI_UNCHECKED)
	GUICtrlSetState($methodRandom, $GUI_UNCHECKED)
	; check option and write INI
	Switch @GUI_CtrlId
		Case $methodGutmann
			GUICtrlSetState($methodGutmann, $GUI_CHECKED)
			IniWrite($configini, "eraser", "method", "Gutmann")
		Case $methodDoD
			GUICtrlSetState($methodDoD, $GUI_CHECKED)
			IniWrite($configini, "eraser", "method", "DoD")
		Case $methodSchneier
			GUICtrlSetState($methodSchneier, $GUI_CHECKED)
			IniWrite($configini, "eraser", "method", "Schneier")
		Case $methodDoD_E
			GUICtrlSetState($methodDoD_E, $GUI_CHECKED)
			IniWrite($configini, "eraser", "method", "DoD_E")
		Case $methodRandom
			GUICtrlSetState($methodRandom, $GUI_CHECKED)
			IniWrite($configini, "eraser", "method", "Random")
			Local $passes = IniRead($configini, "eraser", "pseudo_passes", "")
			$passes = Int(InputBox("Eraser", "# of Pseudorandom passes:", $passes, " M2", 190, 140))
			If Not @error Then
				If $passes <= 0 Then $passes = 1
				IniWrite($configini, "eraser", "pseudo_passes", $passes)
				GUICtrlSetData($methodRandom, "Pseudorandom (Custom) [" & $passes & " pass(es)]")
			EndIf
	EndSwitch
EndFunc

Func WarnMenu()
	Switch IniRead($configini, "eraser", "warn", "")
		Case "1"
			GUICtrlSetState($WarnMenu, $GUI_UNCHECKED)
			IniWrite($configini, "eraser", "warn", "0")
		Case "0"
			GUICtrlSetState($WarnMenu, $GUI_CHECKED)
			IniWrite($configini, "eraser", "warn", "1")
		Case Else
			GUICtrlSetState($WarnMenu, $GUI_CHECKED)
			IniWrite($configini, "eraser", "warn", "1")
	EndSwitch
EndFunc

Func ShowReport()
	Switch IniRead($configini, "eraser", "showreport", "")
		Case "1"
			GUICtrlSetState($ShowReportMenu, $GUI_UNCHECKED)
			IniWrite($configini, "eraser", "showreport", "0")
		Case "0"
			GUICtrlSetState($ShowReportMenu, $GUI_CHECKED)
			IniWrite($configini, "eraser", "showreport", "1")
		Case Else
			GUICtrlSetState($ShowReportMenu, $GUI_CHECKED)
			IniWrite($configini, "eraser", "showreport", "1")
	EndSwitch
EndFunc

Func ShowTips()
	Switch IniRead($configini, "eraser", "showtips", "")
		Case "1"
			GUICtrlSetState($TipsMenu, $GUI_UNCHECKED)
			IniWrite($configini, "eraser", "showtips", "0")
		Case "0"
			GUICtrlSetState($TipsMenu, $GUI_CHECKED)
			IniWrite($configini, "eraser", "showtips", "1")
		Case Else
			GUICtrlSetState($TipsMenu, $GUI_CHECKED)
			IniWrite($configini, "eraser", "showtips", "1")
	EndSwitch
EndFunc

Func OnTop()
	Switch IniRead($configini, "eraser", "ontop", "")
		Case "1"
			GUICtrlSetState($OnTopMenu, $GUI_UNCHECKED)
			IniWrite($configini, "eraser", "ontop", "0")
			WinSetOnTop($nGUI, "", 0)
		Case "0"
			GUICtrlSetState($OnTopMenu, $GUI_CHECKED)
			IniWrite($configini, "eraser", "ontop", "1")
			WinSetOnTop($nGUI, "", 1)
		Case Else
			GUICtrlSetState($OnTopMenu, $GUI_CHECKED)
			IniWrite($configini, "eraser", "ontop", "1")
			WinSetOnTop($nGUI, "", 1)
	EndSwitch
EndFunc

Func FlashTray()
	Switch IniRead($configini, "eraser", "flashtray", "")
		Case "1"
			GUICtrlSetState($FlashMenu, $GUI_UNCHECKED)
			IniWrite($configini, "eraser", "flashtray", "0")
			$doFlash = 0
			TraySetState(8)
		Case "0"
			GUICtrlSetState($FlashMenu, $GUI_CHECKED)
			IniWrite($configini, "eraser", "flashtray", "1")
			$doFlash = 1
			If $isRunning Then TraySetState(4)
		Case Else
			GUICtrlSetState($FlashMenu, $GUI_CHECKED)
			IniWrite($configini, "eraser", "flashtray", "1")
			$doFlash = 1
			If $isRunning Then TraySetState(4)
	EndSwitch
EndFunc

Func AnimateGUI()
	Switch IniRead($configini, "eraser", "doanimation", "")
		Case "1"
			GUICtrlSetState($AnimateMenu, $GUI_UNCHECKED)
			IniWrite($configini, "eraser", "doanimation", "0")
			$doAnimation = 0
			$doneWipe = True ; set opacity to 255
		Case "0"
			GUICtrlSetState($AnimateMenu, $GUI_CHECKED)
			IniWrite($configini, "eraser", "doanimation", "1")
			$doAnimation = 1
		Case Else
			GUICtrlSetState($AnimateMenu, $GUI_CHECKED)
			IniWrite($configini, "eraser", "doanimation", "1")
			$doAnimation = 1
	EndSwitch
EndFunc

Func TargetImage()
	Local $var = FileOpenDialog("Choose new image from the Data\images directory...", @ScriptDir & "\..\..\Data\images", "PNG Image (*.png)", 1)
	If Not @error Then
		$var = StringTrimLeft($var, StringInStr($var, "\", 0, -1))
		If FileExists(@ScriptDir & "\..\..\Data\images\" & $var) Then
			IniWrite($configini, "eraser", "image", $var)
			ReloadGUI()
		ElseIf FileExists(@ScriptDir & "\" & $var) Then
			IniWrite($configini, "eraser", "image", "")
			ReloadGUI()
		EndIf
	EndIf
EndFunc

Func ResetImage()
	IniWrite($configini, "eraser", "image", "")
	ReloadGUI()
EndFunc

Func HotkeyMenu()
	If $hGUI <> "" And WinExists($hGUI) Then Return ; only one instance

	$hGUI = GUICreate("Set Hotkey...", 328, 64, -1, -1, $WS_CAPTION, $WS_EX_TOOLWINDOW)
	$hCTRL = GUICtrlCreateCheckbox("CTRL", 8, 8, 50, 20)
	$hALT = GUICtrlCreateCheckbox("ALT", 66, 8, 40, 20)
	$hSHIFT = GUICtrlCreateCheckbox("SHIFT", 114, 8, 50, 20)
	$hCombo = GUICtrlCreateCombo("", 172, 8, 148, 20, BitOR($CBS_DROPDOWNLIST, $WS_VSCROLL))
	$hSave = GUICtrlCreateButton("Save", 106, 40, 50, 20)
	$hCancel = GUICtrlCreateButton("Cancel", 172, 40, 50, 20)
	GUICtrlSetState($hSave, BitOR($GUI_FOCUS, $GUI_DEFBUTTON))

	; events
	GUICtrlSetOnEvent($hSave, "hSaveButton")
	GUICtrlSetOnEvent($hCancel, "CancelButton")

	; set data
	Local $key, $mods
	If $hotkey = "" Then
		$mods = ""
		$key = "(none)"
	Else
		$mods = StringLeft($hotkey, StringInStr($hotkey, "{") - 1)
		$key = StringTrimRight(StringTrimLeft($hotkey, StringInStr($hotkey, "{")), 1)
	EndIf
	If StringInStr($mods, "^") Then GUICtrlSetState($hCTRL, $GUI_CHECKED)
	If StringInStr($mods, "!") Then GUICtrlSetState($hALT, $GUI_CHECKED)
	If StringInStr($mods, "+") Then GUICtrlSetState($hSHIFT, $GUI_CHECKED)
	GUICtrlSetData($hCombo, "(none)|A|B|C|D|E|F|G|H|I|J|K|L|M|N|O|P|Q|R|S|T|U|V|W|X|Y|Z|" & _
							"0|1|2|3|4|5|6|7|8|9|-|=|[|]|\|;|'|,|.|/|" & _
							'!|@|#|$|%|^|&|*|(|)|_|+|||:|"|<|>|?|' & _
							"F1|F2|F3|F4|F5|F6|F7|F8|F9|F10|F11|F12|" & _
							"SPACE|ENTER|BACKSPACE|DEL|UP|DOWN|LEFT|RIGHT|HOME|END|ESC|INS|PGUP|PGDN|TAB|PRINTSCREEN|" & _
							"BREAK|PAUSE|NUMPAD0|NUMPAD1|NUMPAD2|NUMPAD3|NUMPAD4|NUMPAD5|NUMPAD6|NUMPAD7|NUMPAD8|NUMPAD9|" & _
							"NUMPADMULT|NUMPADADD|NUMPADSUB|NUMPADDIV|NUMPADDOT|SLEEP|" & _
							"BROWSER_BACK|BROWSER_FORWARD|BROWSER_REFRESH|BROWSER_STOP|BROWSER_SEARCH|BROWSER_FAVORITES|BROWSER_HOME|" & _
							"VOLUME_MUTE|VOLUME_DOWN|VOLUME_UP|MEDIA_NEXT|MEDIA_PREV|MEDIA_STOP|MEDIA_PLAY_PAUSE", _
							$key _
							)

	GUISetState(@SW_SHOW, $hGUI)
EndFunc

Func hSaveButton()
	; disable previous hotkey
	HotKeySet($hotkey)
	$hotkey = ""
	$hottip = ""

	If GUICtrlRead($hCombo) = "(none)" Then
		$hottip = "disabled"
		TraySetToolTip("EraserDrop" & @CRLF & "HotKey = disabled")
	Else
		; check modifiers
		If BitAND(GUICtrlRead($hCTRL), $GUI_CHECKED) Then $hotkey &= "^"
		If BitAND(GUICtrlRead($hALT), $GUI_CHECKED) Then $hotkey &= "!"
		If BitAND(GUICtrlRead($hSHIFT), $GUI_CHECKED) Then $hotkey &= "+"
		$hotkey &= "{" & GUICtrlRead($hCombo) & "}"
		; set new hotkey
		HotKeySet($hotkey, "HideGUI")
		_GetHottip()
		TraySetToolTip("EraserDrop" & @CRLF & "HotKey = " & $hottip)
	EndIf
	; save to ini
	IniWrite($configini, "eraser", "hotkey", $hotkey)

	GUIDelete($hGUI)
EndFunc

Func GUIClose()
	; check for running job
	If _EraserWipeIsRunning() Then
		MsgBox(0 + 48, "Eraser", "An Eraser job is in progress." & @CRLF & "Wait for it to finish before exiting.")
		Return
	EndIf
	; save target position
	Local $aPos = WinGetPos($nGUI)
	IniWrite($configini, "eraser", "x", $aPos[0])
	IniWrite($configini, "eraser", "y", $aPos[1])
	; unregister messages
	GUIRegisterMsg($WM_DROPFILES, "")
	GUIRegisterMsg($Eraser_Msg, "")
	GUIRegisterMsg($WM_NOTIFY, "")
	GUIRegisterMsg($CmdMsg, "")
	; unset hotkey
	HotKeySet($hotkey)
	;fade out png background
	For $i = 255 to 0 step -15
		SetBitmap($nGUI, $i)
	Next
	; Release resources and shutdown GDI+
	_CleanGDIP()
	_WinAPI_DeleteObject($hImage)
	_GDIPlus_Shutdown()
	; shutdown eraser
	_EraserEnd()
	; clean reg key
	If $key = "delete" Then RegDelete("HKCU\Software\Heidi Computers Ltd")
	Exit
EndFunc
#EndRegion
#Region ; Eraser Funcs
;===================================================================================
; Eraser Functions
;===================================================================================
Func Recycle()
	_Eraser() ; wipe recycle bin
EndFunc

Func Freespace()
	If $dGUI <> "" And WinExists($dGUI) Then Return ; only one instance

	Local $drives = "" ; empty variable
	; get fixed and removable drives, convert to a string
	Local $drivesfix = DriveGetDrive("FIXED")
	Local $drivesrem = DriveGetDrive("REMOVABLE")
	For $i = 1 To $drivesfix[0]
		$drives = $drives & "|" & $drivesfix[$i]
	Next
	If IsArray($drivesrem) Then
		For $i = 1 To $drivesrem[0]
			$drives = $drives & "|" & $drivesrem[$i]
		Next
	EndIf

	; create GUI
	$dGUI = GUICreate("Choose drive...", 140, 75, -1, -1, $WS_CAPTION, $WS_EX_TOOLWINDOW)
	$lDrives = GUICtrlCreateLabel("Drives:", 8, 8, 37, 17)
	$cDrive = GUICtrlCreateCombo("", 56, 8, 73, 25, $CBS_DROPDOWNLIST)
	$bOK = GUICtrlCreateButton("OK", 16, 40, 50, 25)
	$bCancel = GUICtrlCreateButton("Cancel", 74, 40, 50, 25)

	; control events
	GUICtrlSetOnEvent($bOK, "OKButton")
	GUICtrlSetOnEvent($bCancel, "CancelButton")

	; set combo data
	GUICtrlSetData($cDrive, $drives, $drivesfix[1])

	; show GUI
	GUISetState(@SW_SHOW, $dGUI)
EndFunc

Func OKButton()
	Local $drivetowipe = GUICtrlRead($cDrive) ; read drive selection
	GUIDelete($dGUI) ; delete GUI
	_Eraser($drivetowipe) ; wipe freespace
EndFunc

Func CancelButton()
	GUIDelete(@GUI_WinHandle)
EndFunc

Func _Eraser($drive = "")
	; if $drive = "" then wipe recycle bin
	Local $binarray[1] = [0]

	; warn?
	If "1" = IniRead($configini, "eraser", "warn", "1") Then
		If $drive = "" Then
			If 7 = MsgBox(4 + 32, "Eraser", "Wipe Recycle Bin?") Then Return 1
		Else
			If 7 = MsgBox(4 + 32, "Eraser", "Wipe free space on drive " & StringUpper($drive) & "\?") Then Return 1
		EndIf
	EndIf

	; read Eraser options
	Local $passes, $method = _EraserConvertMethod()
	If $method = "" Then Return
	If $method = $RANDOM_METHOD_ID Then
		$passes = Number(IniRead($configini, "eraser", "pseudo_passes", "1"))
	Else
		$passes = -1
	EndIf

	; check if bin is empty
	If $drive = "" And _SHQueryRecycleBin() = 0 Then
		; all bins empty
		MsgBox(0 + 48, "Eraser", "Recycle Bin is already empty.")
		Return
	EndIf

	; create Eraser context
	Local $context = _EraserCreateContextEx($method, $passes)
	If Not _EraserOK(_EraserIsValidContext($context)) Then
		MsgBox(0 + 48, "Eraser", "Error creating Eraser Context.")
		Return
	EndIf
	; register window message
	_EraserSetWindow($context, $nGUI)
	_EraserSetWindowMessage($context, $Eraser_Msg)
	; set context and mode to master queue
	$MasterQueue[0] += 1
	; add folder job
	_AddEraserFolderJob($FolderArray)
	If $drive = "" Then
		; erase recycle bin
		_EraserSetDataType($context, $ERASER_DATA_FILES)
		_ArrayAdd($MasterQueue, $context & ",2")
		; get recycle bin directories
		_GetRecycleBins($binarray)
		; parse bins
		_EraserLoopBins($binarray, $FolderArray, $context)
	Else
		; erase drive free space
		_EraserSetDataType($context, $ERASER_DATA_DRIVES)
		_ArrayAdd($MasterQueue, $context & ",3")
		; add drive to wipe freespace
		_EraserAddItem($context, $drive & "\")
		$GlobalFileCount += 1
	EndIf
	; set file count and reset var
	$MasterQueue[$MasterQueue[0]] &= "," & $GlobalFileCount
	$GlobalFileCount = 0
	; reverse folder order
	_TrimFolderArrayJob($FolderArray)
	; start wipe
	_EraserStartWipe()
EndFunc

Func _EraserConvertMethod()
	Local $method = IniRead($configini, "eraser", "method", "")
	If $method = "" Then
		MsgBox(0 + 48, "Eraser", "Eraser method not found.  Please set it first.")
		Return ""
	EndIf

	Switch $method
		Case "Gutmann"
			Return $GUTMANN_METHOD_ID
		Case "DoD"
			Return $DOD_METHOD_ID
		Case "Schneier"
			Return $SCHNEIER_METHOD_ID
		Case "DoD_E"
			Return $DOD_E_METHOD_ID
		Case "Random"
			Return $RANDOM_METHOD_ID
	EndSwitch
EndFunc

Func _AddEraserFolderJob(ByRef $FolderArray)
	$FolderArray[0] += 1 ; add job
	Local $aTemp[1] = [0]
	_ArrayAdd($FolderArray, $aTemp) ; add job array
EndFunc

Func _TrimFolderArrayJob(ByRef $FolderArray)
	Local $aTemp = $FolderArray[$FolderArray[0]] ; get array
	ReDim $aTemp[$aTemp[0] + 1] ; resize
	$FolderArray[$FolderArray[0]] = $aTemp ; reassign
EndFunc

Func _AddToTempArray(ByRef $aArray, $idx, $vValue)
	Local $aTemp = $aArray[$idx] ; get inner array
	$aTemp[0] += 1 ; increment counter
	If $aTemp[0] >= UBound($aTemp) Then ReDim $aTemp[UBound($aTemp) * 2] ; conditional resize
	$aTemp[$aTemp[0]] = $vValue ; set value
	$aArray[$idx] = $aTemp ; reassign
EndFunc

Func _EraserParseFolder($sFolder, $context, ByRef $FolderArray)
	Local $item, $mode = _QueueMode()

	; remove trailing \ if it exists
	If StringRight($sFolder, 1) = "\" Then $sFolder = StringTrimRight($sFolder, 1)
	; normal mode
	If $mode = 1 Then
		; insert base folder to array
		_AddToTempArray($FolderArray, $FolderArray[0], $sFolder)
	EndIf

	Local $search = FileFindFirstFile($sFolder & "\*")
	If $search = -1 Then Return ; nothing found
	While 1
		$item = FileFindNextFile($search)
		If @error Then ExitLoop ; no more files
		If @extended Then
			; folder, recurse
			; recycle mode
			If $mode = 2 Then
				; insert subfolder to array
				_AddToTempArray($FolderArray, $FolderArray[0], $sFolder & "\" & $item)
			EndIf
			_EraserParseFolder($sFolder & "\" & $item, $context, $FolderArray)
		Else
			; file
			; recycle mode
			If $mode = 2 And $item = "desktop.ini" And StringInStr(FileGetAttrib($sFolder & "\" & $item), "S") Then ContinueLoop ; skip desktop.ini file
			_EraserAddItem($context, $sFolder & "\" & $item)
			$GlobalFileCount += 1
		EndIf
	WEnd
	FileClose($search)
EndFunc

Func _EraserStartWipe()
	Local $context = _QueueContext()

	If $MasterQueue[0] > 0 Then
		If _EraserIsRunning($context) Then Return ; job added to queue for later run
		If $doFlash Then TraySetState(4) ; flash icon
		$isRunning = True
		If "1" = IniRead($configini, "eraser", "showtips", "1") Then
			TrayTip("Eraser", "Starting wipe...", 2, 1) ; tray tip
		EndIf
		; if no files, goto done - avoids "nothing to erase" error
		If _QueueFileCount() > 0 Then
			_EraserStart($context) ; start Eraser thread
		Else
			_EraserWipeDone()
		EndIf
	EndIf
EndFunc

Func _EraserWipeUpdate()
	Local $context = _QueueContext()
	Local $percent = _EraserProgGetTotalPercent($context) & "%"

	; tray tip
	TraySetToolTip("EraserDrop" & @CRLF & "HotKey = " & $hottip & @CRLF & _
		"----------" & @CRLF & _
		"Percent completed:  " & $percent)
EndFunc

Func _EraserWipeDone()
	Local $context = _QueueContext(), $files = _QueueFileCount(), $folders = 0, $errorarray[1] = [0]

	; check termination flag
	If $Terminated Then
		$Terminated = False
		Return
	EndIf
	; tray tip
	TraySetToolTip("EraserDrop" & @CRLF & "HotKey = " & $hottip)
	; remove folders if any
	If $FolderArray[0] > 0 Then
		Local $aTemp = $FolderArray[1] ; get top array
		If $aTemp[0] > 0 Then
			$folders = $aTemp[0] ; for stats
			For $i = $aTemp[0] To 1 Step -1 ; iterate in reverse
				If _EraserOK(_EraserRemoveFolder($aTemp[$i])) Then
					_SHChangeNotifyFolder($aTemp[$i])
				Else
					$errorarray[0] += 1 ; error counter
					_ArrayAdd($errorarray, $aTemp[$i])
				EndIf
			Next
		EndIf
		$FolderArray[0] -= 1 ; counter - 1
		_ArrayDelete($FolderArray, 1) ; remove folder array
	EndIf
	; empty recycle bins
	If _QueueMode() = 2 And _EraserCompleted($context) Then _SHEmptyRecycleBin()
	; show stats
	If "1" = IniRead($configini, "eraser", "showreport", "0") Or _EraserFailed($context) Or $errorarray[0] > 0 Then
		_EraserShowStats($files, $folders, $errorarray)
	EndIf
	; destroy context and remove from array
	_EraserDestroyContext($context)
	$MasterQueue[0] -= 1 ; counter - 1
	_ArrayDelete($MasterQueue, 1)
	; tray tip
	TraySetState(8) ; stop flash icon
	$isRunning = False
	$doneWipe = True
	If "1" = IniRead($configini, "eraser", "showtips", "1") Then
		TrayTip("Eraser", "Wipe finished.", 2, 1)
	EndIf
	Sleep(1000)
	; start next thread if any
	_EraserStartWipe()
EndFunc

Func TerminateJobs()
	Local $context

	; destroy all contexts, also stops currently running job
	If $MasterQueue[0] > 0 Then
		For $i = 1 To $MasterQueue[0]
			$context = _QueueContext($i)
			If _EraserIsRunning($context) Then $Terminated = True ; set flag
			_EraserDestroyContext($context)
		Next
		; reset queue
		Dim $MasterQueue[1] = [0]
	EndIf
	; reset folder array
	Dim $FolderArray[1] = [0]
	; stop flashing tray
	TraySetState(8)
	$isRunning = False
	$doneWipe = True
	; tray tip
	TrayTip("Eraser", "All jobs terminated.", 2, 1)
	; reset tray tooltip
	TraySetToolTip("EraserDrop" & @CRLF & "HotKey = " & $hottip)
EndFunc

Func _EraserWipeIsRunning()
	If $MasterQueue[0] > 0 Then
		For $i = 1 To $MasterQueue[0]
			If _EraserIsRunning(_QueueContext($i)) Then Return True
		Next
	Else
		Return False
	EndIf
	Return False ; default condition
EndFunc

Func _EraserLoopBins(ByRef $binarray, ByRef $FolderArray, $context)
	; get bins and parse them
	For $i = 1 To $binarray[0]
		_EraserParseFolder($binarray[1], $context, $FolderArray)
		; delete bin
		$binarray[0] -= 1
		_ArrayDelete($binarray, 1)
	Next
EndFunc

Func _EraserShowStats($files, $folders, $errorarray)
	Local $h, $m, $s, $context = _QueueContext()
	Local $errors = _EraserErrorStringCount($context), $failed = _EraserFailedCount($context)

	GUICreate("Erasing Report", 400, 420, -1, -1, -1, $WS_EX_TOOLWINDOW)
	_TicksToTime(_EraserStatGetTime($context), $h, $m, $s)
	GUICtrlCreateGroup("Information", 8, 8, 384, 142)
	GUICtrlCreateLabel("Total items wiped:  " & $files - $failed & " file(s), " & $folders - $errorarray[0] & " folder(s)", 24, 26, 360)
	GUICtrlSetFont(-1, 9)
	GUICtrlCreateLabel("Total time:  " & StringFormat("%02i:%02i:%02i", $h, $m, $s) & "  hh:mm:ss", 24, 46, 360)
	GUICtrlSetFont(-1, 9)
	GUICtrlCreateLabel("Data area wiped:  " & Round(_EraserStatGetArea($context) / 1024, 2) & " KB", 24, 66, 360)
	GUICtrlSetFont(-1, 9)
	GUICtrlCreateLabel("Total data written:  " & Round(_EraserStatGetWiped($context) / 1024, 2) & " KB", 24, 86, 360)
	GUICtrlSetFont(-1, 9)
	GUICtrlCreateLabel("Total errors:  " & $errors, 24, 106, 360)
	GUICtrlSetFont(-1, 9)
	GUICtrlCreateLabel("Total failures:  " & $failed + $errorarray[0], 24, 126, 360)
	GUICtrlSetFont(-1, 9)
	GUICtrlCreateGroup("", -99, -99, 1, 1)
	Local $sLV = GUICtrlCreateListView("Error and Failure Messages", 8, 158, 384, 254, BitOR($GUI_SS_DEFAULT_LISTVIEW, $LVS_NOSORTHEADER), $LVS_EX_GRIDLINES)
	Local $h_sLV = GUICtrlGetHandle($sLV)
	GUICtrlSetBkColor(-1, $GUI_BKCOLOR_LV_ALTERNATE)
	If $errors > 0 Then
		For $i = 0 To $errors - 1
			GUICtrlCreateListViewItem(_EraserErrorString($context, $i), $sLV)
			GUICtrlSetBkColor(-1, 0xE6E6E6)
		Next
	EndIf
	If $failed > 0 Then
		For $i = 0 To $failed - 1
			GUICtrlCreateListViewItem(_EraserFailedString($context, $i), $sLV)
			GUICtrlSetBkColor(-1, 0xE6E6E6)
		Next
	EndIf
	If $errorarray[0] > 0 Then
		For $i = 1 To $errorarray[0]
			GUICtrlCreateListViewItem($errorarray[$i] & " (Unable to remove folder.)", $sLV)
			GUICtrlSetBkColor(-1, 0xE6E6E6)
		Next
	EndIf
	_GUICtrlListView_SetColumnWidth($h_sLV, 0, $LVSCW_AUTOSIZE_USEHEADER)

	GUISetOnEvent($GUI_EVENT_CLOSE, "CancelButton")

	GUISetState()
EndFunc

Func _QueueContext($idx = 1)
	If UBound($MasterQueue) = 1 Then
		$MasterQueue[0] = 0
		Return 0
	EndIf
	Local $array = StringSplit($MasterQueue[$idx], ",")
	Return $array[1]
EndFunc

Func _QueueMode($idx = 1)
	If UBound($MasterQueue) = 1 Then
		$MasterQueue[0] = 0
		Return 0
	EndIf
	Local $array = StringSplit($MasterQueue[$idx], ",")
	Return $array[2]
EndFunc

Func _QueueFileCount($idx = 1)
	If UBound($MasterQueue) = 1 Then
		$MasterQueue[0] = 0
		Return 0
	EndIf
	Local $array = StringSplit($MasterQueue[$idx], ",")
	Return $array[3]
EndFunc
#EndRegion
#Region ; Misc Funcs
;===================================================================================
; Misc Functions
;===================================================================================
Func _SHChangeNotifyFolder($folder)
	DllCall("shell32.dll", "int", "SHChangeNotify", _
							"long", $SHCNE_RMDIR, _
							"uint", $SHCNF_PATH, _
							"str", $folder, _
							"ptr", 0 _
							)
EndFunc

Func _SHQueryRecycleBin($path = "")
	Local $tagSHQUERYRBINFO = "align 1; dword cbSize; int64 i64Size; int64 i64NumItems"

	Local $struct = DllStructCreate($tagSHQUERYRBINFO)
	DllStructSetData($struct, "cbSize", DllStructGetSize($struct))

	DllCall("shell32.dll", "int", "SHQueryRecycleBin", "str", $path, "ptr", DllStructGetPtr($struct))
	Local $numitems = DllStructGetData($struct, "i64NumItems")
	Local $sizeitems = DllStructGetData($struct, "i64Size")
	Return SetError(0, $sizeitems, $numitems)
EndFunc

Func _SHEmptyRecycleBin()
	DllCall("shell32.dll", "int", "SHEmptyRecycleBin", "hwnd", 0, "ptr", 0, "dword", BitOR($SHERB_NOCONFIRMATION, $SHERB_NOPROGRESSUI, $SHERB_NOSOUND))
EndFunc

Func _GetRecycleBins(ByRef $binarray)
	Local $drives = DriveGetDrive("FIXED")
	Local $sid = _GetCurrentUserSID()
	For $i = 1 To $drives[0]
		$binarray[0] += 1
		If DriveGetFileSystem($drives[$i] & "\") = "NTFS" Then
			If $fOSGrEqVista Then
				If $sid <> "" Then
					_ArrayAdd($binarray, $drives[$i] & "\$Recycle.Bin\" & $sid)
				Else
					_ArrayAdd($binarray, $drives[$i] & "\$Recycle.Bin")
				EndIf
			Else
				If $sid <> "" Then
					_ArrayAdd($binarray, $drives[$i] & "\RECYCLER\" & $sid)
				Else
					_ArrayAdd($binarray, $drives[$i] & "\RECYCLER")
				EndIf
			EndIf
		Else
			_ArrayAdd($binarray, $drives[$i] & "\RECYCLED")
		EndIf
	Next
EndFunc

Func _GetCurrentUserSID()
	Local $sid = _Security__GetAccountSid(@LogonDomain & "\" & @UserName)
	$sid = _Security__SidToStringSid(DllStructGetPtr($sid))
	Return $sid
EndFunc
#EndRegion
