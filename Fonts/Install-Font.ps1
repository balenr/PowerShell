Write-Output "Install fonts"
$fonts = (New-Object -ComObject Shell.Application).Namespace(0x14)
foreach ($file in Get-ChildItem *.ttf) {
    $fileName = $file.Name
    if (-not(Test-Path -Path "C:\Windows\fonts\$fileName" )) {
        Write-Output $fileName
        Get-ChildItem $file | ForEach-Object { $fonts.CopyHere($_.fullname) }
    }
}
Copy-Item *.ttf c:\windows\fonts\