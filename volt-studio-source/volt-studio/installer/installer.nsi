; =====================================================================
;  Volt Studio installer (NSIS)
;  Builds "Volt Studio Setup <version>.exe" from dist\win-unpacked.
;
;  Build:  makensis -DVERSION=1.3.0 installer.nsi
;
;  Installs for the current user only (no admin needed) into
;  %LOCALAPPDATA%\Programs\Volt Studio, adds Start menu / desktop shortcuts,
;  opens .volt files with Volt Studio, and adds an entry to
;  Settings -> Apps so it can be uninstalled.
; =====================================================================

Unicode true
ManifestDPIAware true
SetCompressor /SOLID lzma
SetCompressorDictSize 64
RequestExecutionLevel user

!ifndef VERSION
  !define VERSION "1.0.0"
!endif
!define APPNAME "Volt Studio"
!define EXE "Volt Studio.exe"
!define UNINSTALLER "Uninstall Volt Studio.exe"
!define PUBLISHER "Ethan"
!define REGKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\VoltStudio"
!define SOURCE "..\dist\win-unpacked"

Name "${APPNAME}"
OutFile "..\dist\Volt Studio Setup ${VERSION}.exe"
InstallDir "$LOCALAPPDATA\Programs\${APPNAME}"
InstallDirRegKey HKCU "${REGKEY}" "InstallLocation"
BrandingText "${APPNAME} ${VERSION}"

; Details shown in the installer's Properties window
VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "${APPNAME}"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "FileDescription" "${APPNAME} Setup"
VIAddVersionKey "CompanyName" "${PUBLISHER}"
VIAddVersionKey "LegalCopyright" "MIT License"

!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "LogicLib.nsh"

; ---------- Look ----------
!define MUI_ICON "icon.ico"
!define MUI_UNICON "icon.ico"
!define MUI_WELCOMEFINISHPAGE_BITMAP "sidebar.bmp"
!define MUI_UNWELCOMEFINISHPAGE_BITMAP "sidebar.bmp"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_RIGHT
!define MUI_HEADERIMAGE_BITMAP "header.bmp"
!define MUI_HEADERIMAGE_UNBITMAP "header.bmp"
!define MUI_ABORTWARNING

; ---------- Pages ----------
!define MUI_WELCOMEPAGE_TITLE "Welcome to ${APPNAME} ${VERSION}"
!define MUI_WELCOMEPAGE_TEXT "This will install ${APPNAME} on your computer.$\r$\n$\r$\nWrite Volt once and turn it into Arduino C++, MicroPython, Python, Ruby, JavaScript or a web page.$\r$\n$\r$\nIf ${APPNAME} is open, close it before continuing.$\r$\n$\r$\nClick Next to continue."
!insertmacro MUI_PAGE_WELCOME
!define MUI_COMPONENTSPAGE_SMALLDESC
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\${EXE}"
!define MUI_FINISHPAGE_RUN_TEXT "Open ${APPNAME} now"
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

; ---------- Install ----------
Section "${APPNAME} (required)" SecApp
  SectionIn RO
  SetShellVarContext current
  SetOutPath "$INSTDIR"

  ; If Volt Studio is running, its files are locked. Ask the user to close it.
  ${If} ${FileExists} "$INSTDIR\${EXE}"
    retry:
    ClearErrors
    Delete "$INSTDIR\${EXE}"
    ${If} ${Errors}
      MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "${APPNAME} is still open.$\r$\n$\r$\nClose it, then click Retry." IDRETRY retry
      Abort "Installation cancelled because ${APPNAME} is open."
    ${EndIf}
    ; Remove old app files so nothing stale is left behind after an update
    RMDir /r "$INSTDIR\resources"
    RMDir /r "$INSTDIR\locales"
  ${EndIf}

  File /r "${SOURCE}\*.*"
  File "icon.ico"

  WriteUninstaller "$INSTDIR\${UNINSTALLER}"
  CreateShortcut "$SMPROGRAMS\${APPNAME}.lnk" "$INSTDIR\${EXE}" "" "$INSTDIR\${EXE}" 0

  ; Settings -> Apps entry
  WriteRegStr HKCU "${REGKEY}" "DisplayName" "${APPNAME}"
  WriteRegStr HKCU "${REGKEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${REGKEY}" "Publisher" "${PUBLISHER}"
  WriteRegStr HKCU "${REGKEY}" "DisplayIcon" "$INSTDIR\${EXE},0"
  WriteRegStr HKCU "${REGKEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${REGKEY}" "UninstallString" '"$INSTDIR\${UNINSTALLER}"'
  WriteRegStr HKCU "${REGKEY}" "QuietUninstallString" '"$INSTDIR\${UNINSTALLER}" /S'
  WriteRegDWORD HKCU "${REGKEY}" "NoModify" 1
  WriteRegDWORD HKCU "${REGKEY}" "NoRepair" 1
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0
  WriteRegDWORD HKCU "${REGKEY}" "EstimatedSize" "$0"
SectionEnd

Section "Desktop shortcut" SecDesktop
  SetShellVarContext current
  CreateShortcut "$DESKTOP\${APPNAME}.lnk" "$INSTDIR\${EXE}" "" "$INSTDIR\${EXE}" 0
SectionEnd

Section "Open .volt files with ${APPNAME}" SecAssoc
  WriteRegStr HKCU "Software\Classes\.volt" "" "VoltStudio.volt"
  WriteRegStr HKCU "Software\Classes\VoltStudio.volt" "" "Volt program"
  WriteRegStr HKCU "Software\Classes\VoltStudio.volt\DefaultIcon" "" "$INSTDIR\icon.ico,0"
  WriteRegStr HKCU "Software\Classes\VoltStudio.volt\shell\open\command" "" '"$INSTDIR\${EXE}" "%1"'
  ; Tell Windows the file types changed so icons update straight away
  System::Call 'shell32::SHChangeNotify(i 0x08000000, i 0, p 0, p 0)'
SectionEnd

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SecApp} "The Volt Studio editor, compiler, examples and reference."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecDesktop} "Put a Volt Studio shortcut on your desktop."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecAssoc} "Double-click any .volt file to open it in Volt Studio."
!insertmacro MUI_FUNCTION_DESCRIPTION_END

; ---------- Uninstall ----------
Section "Uninstall"
  SetShellVarContext current

  retry:
  ClearErrors
  Delete "$INSTDIR\${EXE}"
  ${If} ${Errors}
    MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "${APPNAME} is still open.$\r$\n$\r$\nClose it, then click Retry." IDRETRY retry
    Abort
  ${EndIf}

  Delete "$SMPROGRAMS\${APPNAME}.lnk"
  Delete "$DESKTOP\${APPNAME}.lnk"

  ; Only remove the .volt link if it still points to Volt Studio
  ReadRegStr $0 HKCU "Software\Classes\.volt" ""
  ${If} $0 == "VoltStudio.volt"
    DeleteRegKey HKCU "Software\Classes\.volt"
  ${EndIf}
  DeleteRegKey HKCU "Software\Classes\VoltStudio.volt"
  System::Call 'shell32::SHChangeNotify(i 0x08000000, i 0, p 0, p 0)'

  DeleteRegKey HKCU "${REGKEY}"

  ; Your .volt programs are never touched: they live wherever you saved them.
  RMDir /r "$INSTDIR"
SectionEnd
