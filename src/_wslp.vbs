If WScript.Arguments.Count = 0 Then
    WScript.Quit 1
End If

Dim shell, path, scriptDir, encoded, command

Set shell  = CreateObject("WScript.Shell")
path       = WScript.Arguments(0)
scriptDir  = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)

' Encode the path as UTF-16LE base64 so no character in the path
' (quotes, backticks, special chars, accents) can break the PowerShell
' command line. We build the UTF-16LE byte sequence manually from the
' VBScript string (which is natively UTF-16) to avoid ADODB.Stream
' re-encoding the string through the system ANSI code page.
Dim i, charCode, lo, hi, byteArray()
ReDim byteArray(LenB(path) - 1)
For i = 1 To Len(path)
    charCode = AscW(Mid(path, i, 1))
    If charCode < 0 Then charCode = charCode + 65536  ' handle signed AscW
    lo = charCode Mod 256
    hi = (charCode \ 256) Mod 256
    byteArray((i - 1) * 2)     = lo
    byteArray((i - 1) * 2 + 1) = hi
Next

' Write raw bytes into a binary stream to get base64 via MSXML
Dim stream
Set stream = CreateObject("ADODB.Stream")
stream.Open
stream.Type = 1  ' binary
stream.Write byteArray
stream.Position = 0

Dim xmlObj : Set xmlObj = CreateObject("MSXML2.DOMDocument")
Dim xmlElem : Set xmlElem = xmlObj.createElement("b64")
xmlElem.DataType = "bin.base64"
xmlElem.nodeTypedValue = stream.Read
stream.Close

encoded = xmlElem.Text
encoded = Join(Split(encoded, Chr(10)), "")  ' strip LF
encoded = Join(Split(encoded, Chr(13)), "")  ' strip CR

command = "powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive" & _
          " -File """ & scriptDir & "\_wslp.ps1""" & _
          " -EncodedPath """ & encoded & """"

' 0 = hidden window, True = wait for completion
shell.Run command, 0, True
