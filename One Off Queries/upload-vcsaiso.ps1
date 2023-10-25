# https://kb.vmware.com/s/article/2001041

if ( -not $Cred ) {
    $Cred = Get-Credential
}

$serverNameOrIPAddress = "kcdcvc-01.nrccua-hq.local"
$DSName = "kcdcesx5_local_storage"

$FilePathName = "C:\Users\jeff.buenting\Downloads\VMware-Tools-windows-12.3.0-22234872\vmtools\windows.iso"
$Destination = "ds:\ISO\VMTools\12.3.0"

Connect-VIServer -Server $ServerNameOrIPAddress -Credential $Cred

$datastore = Get-Datastore $DSName
New-PSDrive -Location $datastore -Name ds -PSProvider VimDatastore -Root "\"

Copy-DatastoreItem -item $FilePathName -Destination $Destination -Force

Remove-PSDrive -Name ds

disconnect-viserver -Confirm:$false