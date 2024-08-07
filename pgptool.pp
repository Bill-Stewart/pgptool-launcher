{ This program is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the Free
  Software Foundation; either version 3 of the License, or (at your option) any
  later version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE. See the GNU General Lesser Public License for more
  details.

  You should have received a copy of the GNU Lesser General Public License
  along with this program. If not, see https://www.gnu.org/licenses/.

}

program pgptool;

{$MODE OBJFPC}
{$MODESWITCH UNICODESTRINGS}
{$R *.res}

uses
  wargcv,
  regexpr,
  SysUtils,
  Windows,
  VersionStrings,
  WindowsMessages,
  WindowsString;

const
  APP_TITLE = 'PGPTool';
  MIN_JAVA_VERSION = '8';
  INVALID_FILE_ATTRIBUTES = DWORD(-1);

type
  TIsJavaInstalled = function(): DWORD; stdcall;
  TGetJavaMinimumVersion = function(Version: LPWSTR; VersionOK: PDWORD): DWORD; stdcall;
  TGetString = function(Buffer: PChar; NumChars: DWORD): DWORD; stdcall;

function GetString(var Func: TGetString): string;
var
  NumChars: DWORD;
  OutStr: string;
begin
  result := '';
  NumChars := Func(nil, 0);
  SetLength(OutStr, NumChars);
  if Func(PChar(OutStr), NumChars) > 0 then
    result := OutStr;
end;

procedure MsgBox(const Msg: string; const MsgBoxType: UINT);
begin
  MessageBoxW(0,           // HWND    hWnd
    PChar(Msg),            // LPCWSTR lpText
    APP_TITLE,             // LPCWSTR lpCaption
    MsgBoxType or MB_OK);  // UINT    uType
end;

function FileExists(const FileName: string): Boolean;
var
  Attrs: DWORD;
begin
  Attrs := GetFileAttributesW(PChar(FileName));  // LPCWSTR lpFileName
  result := (Attrs <> INVALID_FILE_ATTRIBUTES) and
    ((Attrs and FILE_ATTRIBUTE_DIRECTORY) = 0);
end;

function GetParentPath(const Path: string): string;
var
  I: Integer;
begin
  result := Path;
  if Length(Path) > 1 then
  begin
    for I := Length(Path) downto 2 do
      if Path[I] = '\' then
      begin
        result := Copy(Path, 1, I - 1);
        break;
      end;
  end;
end;

function JoinPath(Path1, Path2: string): string;
begin
  if (Length(Path1) > 0) and (Length(Path2) > 0) then
  begin
    while Path1[Length(Path1)] = '\' do
      Path1 := Copy(Path1, 1, Length(Path1) - 1);
    while Path2[1] = '\' do
      Path2 := Copy(Path2, 2, Length(Path2) - 1);
    result := Path1 + '\' + Path2;
  end
  else
    result := '';
end;

// Searches executable directory for latest version of .jar file; if found,
// returns full path and filename of .jar file
function GetJarFileName(): string;
const
  JAR_FILE_NAME = 'pgptoolgui';
var
  RegEx: TRegExpr;
  LatestVersion, MyPath, REMatch: string;
  SR: TUnicodeSearchRec;
begin
  result := '';
  RegEx := TRegExpr.Create('-((?:(?:\d+)\.){1,3}\d?)\.');
  LatestVersion := '0';
  MyPath := GetParentPath(ParamStr(0));
  if SysUtils.FindFirst(JoinPath(MyPath, JAR_FILE_NAME + '-*.jar'), faAnyFile and (not faDirectory), SR) = 0 then
  begin
    repeat
      if RegEx.Exec(UnicodeStringToAnsi(SR.Name, CP_ACP)) then
      begin
        REMatch := AnsiToUnicodeString(RegEx.Match[1], CP_ACP);
        if TestVersionString(REMatch) and (CompareVersionStrings(REMatch, LatestVersion) > 0) then
          LatestVersion := REMatch;
      end;
    until SysUtils.FindNext(SR) <> 0;
    SysUtils.FindClose(SR);
  end;
  RegEx.Free();
  if LatestVersion <> '0' then
    result := JoinPath(MyPath, JAR_FILE_NAME + '-' + LatestVersion + '.jar');
end;

function StartProcess(const FileName, Parameters: string): DWORD;
var
  CommandLine: string;
  StartInfo: STARTUPINFOW;
  ProcInfo: PROCESS_INFORMATION;
begin
  result := ERROR_SUCCESS;
  CommandLine := '"' + FileName + '" ' + Parameters;
  FillChar(StartInfo, SizeOf(StartInfo), 0);
  StartInfo.cb := SizeOf(StartInfo);
  StartInfo.dwFlags := STARTF_USESHOWWINDOW;
  StartInfo.wShowWindow := SW_SHOWNORMAL;
  if not CreateProcessW(nil,  // LPCWSTR               lpApplicationName
    PChar(CommandLine),       // LPWSTR                lpCommandLine
    nil,                      // LPSECURITY_ATTRIBUTES lpProcessAttributes
    nil,                      // LPSECURITY_ATTRIBUTES lpThreadAttributes
    false,                    // BOOL                  bInheritHandles
    NORMAL_PRIORITY_CLASS,    // DWORD                 dwCreationFlags
    nil,                      // LPVOID                lpEnvironment
    nil,                      // LPCWSTR               lpCurrentDirectory
    StartInfo,                // LPSTARTUPINFOW        lpStartupInfo
    ProcInfo) then            // LPPROCESS_INFORMATION lpProcessInformation
  begin
    result := GetLastError();
  end;
end;

var
  JarFileName, DLLPath, JavaHome, JavaBinary: string;
  DLLHandle: HMODULE;
  IsJavaInstalled: TIsJavaInstalled;
  IsJavaMinimumVersion: TGetJavaMinimumVersion;
  VersionOK: DWORD;
  GetJavaHome: TGetString;

begin
  JarFileName := GetJarFileName();
  if JarFileName = '' then
  begin
    ExitCode := ERROR_FILE_NOT_FOUND;
    MsgBox('Unable to find PGPTool jar application file.', MB_ICONERROR);
    exit;
  end;

  DLLPath := JoinPath(GetParentPath(ParamStr(0)), 'JavaInfo.dll');
  DLLHandle := LoadLibraryW(PChar(DLLPath));  // LPCWSTR lpLibFileName
  if DLLHandle = 0 then
  begin
    ExitCode := GetLastError();
    MsgBox('JavaInfo.dll not found.', MB_ICONERROR);
    exit;
  end;

  IsJavaInstalled := TIsJavaInstalled(GetProcAddress(DLLHandle,  // HMODULE hModule
    'IsJavaInstalled'));                                         // LPCSTR  lpProcName
  if IsJavaInstalled() <> 0 then
  begin
    IsJavaMinimumVersion := TGetJavaMinimumVersion(GetProcAddress(DLLHandle,  // HMODULE hModule
      'IsJavaMinimumVersion'));                                               // LPCSTR  lpProcName
    IsJavaMinimumVersion(MIN_JAVA_VERSION, @VersionOK);
    if VersionOK = 1 then
    begin
      GetJavaHome := TGetString(GetProcAddress(DLLHandle,  // HMODULE hModule
        'GetJavaHome'));                                   // LPCSTR  lpProcName
      JavaHome := GetString(GetJavaHome);
      if JavaHome <> '' then
      begin
        JavaBinary := JavaHome + '\bin\javaw.exe';
        if FileExists(JavaBinary) then
        begin
          ExitCode := StartProcess(JavaBinary, '-jar "' + JarFileName + '"');
          if ExitCode <> 0 then
            MsgBox(GetWindowsMessage(ExitCode, true), MB_ICONERROR);
        end
        else
        begin
          ExitCode := ERROR_FILE_NOT_FOUND;
          MsgBox('File not found:' + sLineBreak + sLineBreak + JavaBinary, MB_ICONERROR);
        end;
      end
      else
      begin
        ExitCode := ERROR_PATH_NOT_FOUND;
        MsgBox('Unable to find Java home directory.', MB_ICONERROR);
      end;
    end
    else
    begin
      ExitCode := ERROR_NOT_SUPPORTED;
      MsgBox('Installed Java version is too old.', MB_ICONERROR);
    end;
  end
  else
  begin
    ExitCode := ERROR_FILE_NOT_FOUND;
    MsgBox('Unable to find a Java installation on the current computer.', MB_ICONERROR);
  end;

  FreeLibrary(DLLHandle);  // HMODULE hLibModule
end.
