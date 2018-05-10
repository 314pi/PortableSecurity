!macro CustomCodePostInstall
	IfFileExists "$INSTDIR\Data\images\*.*" +2
		CreateDirectory "$INSTDIR\Data\images"
!macroend