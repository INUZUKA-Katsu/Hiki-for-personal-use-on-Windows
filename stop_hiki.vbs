Option Explicit

Dim Locator,Service,Items,Item,Res

Res=False

Set Locator = WScript.CreateObject("WbemScripting.SWbemLocator")
Set Service = Locator.ConnectServer
Set Items   = Service.ExecQuery("Select * From Win32_Process Where CommandLine Like '%ruby.exe%'")

For Each Item In Items
    If InStr(Item.CommandLine,"rackup")>0 Then
        Item.terminate
        MsgBox "「Hiki」を停止しました。"
        Res = True
    End If
    If InStr(Item.CommandLine,"remote_dialog.rb")>0 Then
        Item.terminate
    End If
Next

If Res = False Then
    MsgBox "「Hiki」は稼働中ではありませんでした。"
End If