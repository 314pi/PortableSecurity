#include-once

#cs
Windows 7				6.1
Windows Server 2008		6.0
Windows Vista			6.0
Windows Server 2003 R2	5.2
Windows Server 2003		5.2
Windows XP				5.1
Windows 2000			5.0
#ce

;*** Constants
; dwTypeBitMask
Global Const $VER_BUILDNUMBER = 0x0000004
Global Const $VER_MAJORVERSION = 0x0000002
Global Const $VER_MINORVERSION = 0x0000001
Global Const $VER_PLATFORMID = 0x0000008
Global Const $VER_PRODUCT_TYPE = 0x0000080
Global Const $VER_SERVICEPACKMAJOR = 0x0000020
Global Const $VER_SERVICEPACKMINOR = 0x0000010
Global Const $VER_SUITENAME = 0x0000040
; dwConditionMask
Global Const $VER_EQUAL = 1
Global Const $VER_GREATER = 2
Global Const $VER_GREATER_EQUAL = 3
Global Const $VER_LESS = 4
Global Const $VER_LESS_EQUAL = 5
; if dwTypeBitMask is VER_SUITENAME
Global Const $VER_AND = 6
Global Const $VER_OR = 7

Func _OsVersionTest($iTest, $osMajor, $osMinor = 0, $spMajor = 0, $spMinor = 0)
	Local Const $OSVERSIONINFOEXW = "dword dwOSVersionInfoSize;dword dwMajorVersion;dword dwMinorVersion;dword dwBuildNumber;dword dwPlatformId;" & _
									"wchar szCSDVersion[128];ushort wServicePackMajor;ushort wServicePackMinor;ushort wSuiteMask;byte wProductType;byte wReserved"
	Local $dwlConditionalMask = 0
	; initialize structure
	Local $OSVI = DllStructCreate($OSVERSIONINFOEXW)
	DllStructSetData($OSVI, "dwOSVersionInfoSize", DllStructGetSize($OSVI))
	; set data we want to compare
	DllStructSetData($OSVI, "dwMajorVersion", $osMajor)
	DllStructSetData($OSVI, "dwMinorVersion", $osMinor)
	DllStructSetData($OSVI, "wServicePackMajor", $spMajor)
	DllStructSetData($OSVI, "wServicePackMinor", $spMinor)
	; initialize and set the mask
	VerSetConditionMask($VER_MAJORVERSION, $iTest, $dwlConditionalMask)
	VerSetConditionMask($VER_MINORVERSION, $iTest, $dwlConditionalMask)
	VerSetConditionMask($VER_SERVICEPACKMAJOR, $iTest, $dwlConditionalMask)
	VerSetConditionMask($VER_SERVICEPACKMINOR, $iTest, $dwlConditionalMask)
	; perform test
	Return VerifyVersionInfo(DllStructGetPtr($OSVI), BitOR($VER_MAJORVERSION, $VER_MINORVERSION, $VER_SERVICEPACKMAJOR, $VER_SERVICEPACKMINOR), $dwlConditionalMask)
EndFunc

Func VerSetConditionMask($dwTypeBitMask, $dwConditionMask, ByRef $dwlConditionalMask)
	Local $ret = DllCall("kernel32.dll", "uint64", "VerSetConditionMask", "uint64", $dwlConditionalMask, "dword", $dwTypeBitMask, "byte", $dwConditionMask)
	$dwlConditionalMask = $ret[0]
EndFunc

Func VerifyVersionInfo($lpVersionInfo, $dwTypeMask, $dwlConditionalMask)
	; dwTypeMask is a BitOR'd combination of the conditions we want to test
	Local $ret = DllCall("kernel32.dll", "int", "VerifyVersionInfoW", "ptr", $lpVersionInfo, "dword", $dwTypeMask, "uint64", $dwlConditionalMask)
	Return $ret[0]
EndFunc
