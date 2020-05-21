$Cred = Get-credential


Connect-viserver 192.168.1.16 -Credential $Cred

$VM = Get-VM kw-test

$spec = New-Object VMware.Vim.VirtualMachineConfigSpec

$BootOptions = New-Object VMware.Vim.VirtualMachineBootOptions

$BootableCDRom = New-Object -Type VMware.Vim.VirtualMachineBootOptionsBootableCdromDevice

$HDiskDeviceName = "Hard disk 1"
$HDiskDeviceKey = ($vm.ExtensionData.Config.Hardware.Device | ?{$_.DeviceInfo.Label -eq $HDiskDeviceName}).Key
$BootableHDisk = New-Object -TypeName VMware.Vim.VirtualMachineBootOptionsBootableDiskDevice -Property @{"DeviceKey" = $HDiskDeviceKey} 

$BootOptions.BootOrder = $BootableCDRom, $BootableHDisk

$Spec.BootOptions = $BootOptions

$VM.ExtensionData.reconfigvm( $Spec )