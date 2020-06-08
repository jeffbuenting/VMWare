#    # ----- remove temp boot order
#        # ----- Gather VM info we will need
#        $VM = Get-VM -Name $VMName
#
#        $VMXPath = $VM.ExtensionData.Config.Files.VmPathName
#        $VMXDS = Get-Datastore $VMXPath.split(' ')[0].trim('[',']')
#        $VMXName = $VMXPath.split(' ')[1].Replace( '/','\')
#        $Folder = $VM.Folder
#
#        # ----- If VM is in resouce pool use that otherwise just use the cluster as the resource
#        if ( $($VM.ResourcePool) ) {
#            $ResourcePool = $VM.ResourcePool
#        }
#        Else {
#            $ResourcePool = (Get-Cluster -VM $VM).Name
#        }
#
#        # ----- It seems that when you change the Bootoptions via PowerCLI, it also changes the BIOS order.  And removing the BootOrder from the VMX does not set the order back.  SO setting it with Powerclie and then clearing
#
#        $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
#
#        $BootOptions = New-Object VMware.Vim.VirtualMachineBootOptions
#
#        $BootableCDRom = New-Object -Type VMware.Vim.VirtualMachineBootOptionsBootableCdromDevice
#
#        $HDiskDeviceName = "Hard disk 1"
#        $HDiskDeviceKey = ($vm.ExtensionData.Config.Hardware.Device | ?{$_.DeviceInfo.Label -eq $HDiskDeviceName}).Key
#        $BootableHDisk = New-Object -TypeName VMware.Vim.VirtualMachineBootOptionsBootableDiskDevice -Property @{"DeviceKey" = $HDiskDeviceKey}
#
#        $BootOrder = $BootableCDRom
#
#        $BootOptions.BootOrder = $BootableHDisk,$BootOrder
#
#        $Spec.BootOptions = $BootOptions
#
#        $VM.ExtensionData.reconfigvm( $Spec )
#
#        # ----- Remove and Reregister so VMX changes happen
#        Remove-Inventory -Item $VM -Confirm:$False
#
#        # ----- Register VM (use clustername as the default resourcepool)
#        $VM = New-VM -VMFilePath $VMXPath -Location $Folder -ResourcePool $ResourcePool
#
#        # ----- Apparently the settings don't change unless the VM boots.  Booting and shuting down
#        Start-VM -VM $VM 
#        Wait-Tools -vm $VM
#
#        Shutdown-VMGuest -vm $VM -Confirm:$False 
#
#        $VM = Get-VM -Name $VMName
#
#        # ----- Wait for VM to be powered off.
#        Write-Output "Waiting until the VM is in a PoweredOff State prior to changing boot order"
#        while ( $VM.PowerState -ne 'PoweredOff' ) {
#            Start-Sleep -s 5
#            Write-Output "Powerstate = $($VM.Powerstate)"
#            $VM = Get-VM -Name $VMName
#        }
#
#
#
#
#        # ----- Clearing Bios.bootORder from VMX
#
#        # ----- Editing the VMX to be safe unregister VM
#        Remove-Inventory -Item $VM -Confirm:$False
#
#        # ----- Copy locally to edit and rename as backup
#        Copy-DatastoreItem  -Item "$($VMXDS.DatastoreBrowserPath)\$VMXName" -Destination c:\temp\$($VMName).vmx.old
#
#        # ----- Renaming to .old as backup
#        #Rename-Item c:\temp\$($VMName).vmx -NewName c:\temp\$($VMName).vmx.old
#
#        Get-Content -Path c:\temp\$($VMName).vmx.old | Select-String -Pattern bios.bootOrder -NotMatch | Set-Content -Path c:\temp\$($VMName).vmx
#
#
#        # ----- back to datastore and register VM
#        Copy-DatastoreItem -Item c:\temp\$($VMName).vmx -Destination "$($VMXDS.DatastoreBrowserPath)\$VMXName"
#
#        # ----- Register VM (use clustername as the default resourcepool)
#        $VM = New-VM -VMFilePath $VMXPath -Location $Folder -ResourcePool $ResourcePool 
#
#   #     $spec = New-Object VMware.Vim.VirtualMachineConfigSpec 
#   #     $Spec.BootOPtions = New-Object VMware.Vim.VirtualMachineBootOptions 
#   #     $SPec.BootOptions.BootOrder = $Null
#   #
#   #     ## reconfig the VM to use the spec with the new BootOrder
#   #     $vm.ExtensionData.ReconfigVM_Task($spec)