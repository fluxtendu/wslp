If WScript.Arguments.Count = 0 Then
    WScript.Quit 1
End If

Dim shell, path, scriptDir, encoded, command

Set shell  = CreateObject("WScript.Shell")
path       = WScript.Arguments(0)
scriptDir  = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)

' Encode the path as UTF-16LE base64 so no character in the path
' (quotes, backticks, special chars, accents) can break the PowerShell
' command line.
'
' Strategy: write the string into an ADODB.Stream opened as text with
' charset utf-16le, then re-read it in binary mode. The stream writes
' a 2-byte BOM first, which we skip by setting Position = 2 before
' switching to binary read. This preserves the native UTF-16 encoding
' of VBScript strings without going through the ANSI code page.
Dim stream
Set stream = CreateObject("ADODB.Stream")
stream.Open
stream.Type    = 2          ' text mode
stream.Charset = "utf-16le"
stream.WriteText path
stream.Position = 0
stream.Type     = 1         ' switch to binary mode to read raw bytes
stream.Position = 2         ' skip the 2-byte UTF-16LE BOM
Dim bytes : bytes = stream.Read
stream.Close

Dim xmlObj  : Set xmlObj  = CreateObject("MSXML2.DOMDocument")
Dim xmlElem : Set xmlElem = xmlObj.createElement("b64")
xmlElem.DataType      = "bin.base64"
xmlElem.nodeTypedValue = bytes
encoded = xmlElem.Text
encoded = Join(Split(encoded, Chr(10)), "")  ' strip LF
encoded = Join(Split(encoded, Chr(13)), "")  ' strip CR

command = "powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive" & _
          " -File """ & scriptDir & "\_wslp.ps1""" & _
          " -EncodedPath """ & encoded & """"

' 0 = hidden window, True = wait for completion
shell.Run command, 0, True
