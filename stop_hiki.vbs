Option Explicit

Dim Locator,Service,Items,Item,Res

Res=False

Set Locator = WScript.CreateObject("WbemScripting.SWbemLocator")
Set Service = Locator.ConnectServer
Set Items   = Service.ExecQuery("Select * From Win32_Process Where CommandLine Like '%ruby.exe%'")

For Each Item In Items
    If InStr(Item.CommandLine,"rackup")>0 Then
        Item.terminate
        MsgBox "�uHiki�v���~���܂����B"
        Res = True
    End If
    If InStr(Item.CommandLine,"remote_dialog.rb")>0 Then
        Item.terminate
    End If
Next

If Res = False Then
    MsgBox "�uHiki�v�͉ғ����ł͂���܂���ł����B"
End If