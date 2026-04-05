Dim shell, path, scriptDir, command

Set shell = CreateObject("WScript.Shell")
path      = WScript.Arguments(0)
scriptDir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)

command = "powershell.exe -ExecutionPolicy Bypass -NoProfile -NonInteractive" & _
          " -File """ & scriptDir & "\wslp.ps1""" & _
          " -RawPath """ & path & """"

' 0 = hidden window, True = wait for completion
shell.Run command, 0, True
