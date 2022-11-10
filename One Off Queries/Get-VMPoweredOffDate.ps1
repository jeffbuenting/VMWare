# $VCSA = Read-Host 'vCenter ServerName'

# Connect-VIServer -Server $VCSA

$Report = @()

$VMFolder = Get-folder -Name "Powered Off VMs" 

$PoweredOffVMs = get-vm -Location $VMFolder 

$Datastores = Get-Datastore | select-Object Name, Id

foreach ( $VM in $PoweredOffVMs ) {

    $POEvent = Get-VIEvent -Entity $VM -MaxSamples ([int]::MaxValue) | Where-Object {$_ -is [VMware.Vim.VmPoweredOffEvent]} | Group-Object -Property {$_.Vm.Name}
   
     $lastPO = $POEvent.Group | Sort-Object -Property CreatedTime -Descending | Select-Object -First 1
    # $vm = Get-VIObjectByVIView -MORef $_.Group[0].VM.VM

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

$Computers = $report | Sort-Object VMName | where PowerOFF -eq $Null #| FT VMName, Powerstate, PowerOFF



# disconnect-viserver * -confirm:$false 