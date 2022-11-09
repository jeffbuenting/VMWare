# $VCSA = Read-Host 'vCenter ServerName'

Connect-VIServer -Server $VCSA

$Report = @()

$VMs = get-vm |Where-object {$_.powerstate -eq "poweredoff"}

$Datastores = Get-Datastore | select-Object Name, Id

Get-VIEvent -Entity $VMs -MaxSamples ([int]::MaxValue) | Where-Object {$_ -is [VMware.Vim.VmPoweredOffEvent]} | Group-Object -Property {$_.Vm.Name} | ForEach-Object {

    $lastPO = $_.Group | Sort-Object -Property CreatedTime -Descending | Select-Object -First 1
    $vm = Get-VIObjectByVIView -MORef $_.Group[0].VM.VM

    $row = '' | Select-Object VMName,Powerstate,OS,Host,Cluster,Datastore,NumCPU,MemMb,DiskGb,PowerOFF
    $row.VMName = $vm.Name
    $row.Powerstate = $vm.Powerstate
    $row.OS = $vm.Guest.OSFullName
    $row.Host = $vm.VMHost.name
    $row.Cluster = $vm.VMHost.Parent.Name 
    $row.Datastore = $Datastores | Where-Object {$_.Id -eq ($vm.DatastoreIdList | Select-Object -First 1)} | Select-Object -ExpandProperty Name
    $row.NumCPU = $vm.NumCPU
    $row.MemMb = $vm.MemoryMB
    $row.DiskGb = Get-HardDisk -VM $vm | Measure-Object -Property CapacityGB -Sum | Select-Object -ExpandProperty Sum
    $row.PowerOFF = $lastPO.CreatedTime

    $report += $row

}

#$report | Sort-Object Name # | Export-Csv -Path "C:\XXXXX\Powered_Off_VMs.csv" -NoTypeInformation -UseCulture

disconnect-viserver * -confirm:$false 