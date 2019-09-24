# ----- grab 10 gig network port groups
$Network = Get-view -ViewType Network -Filter @{'Name'='dv-10gig-'}

# ----- VMs using these port groups
$Network | Foreach { $_.UpdateViewData( "VM.Name","VM.Guest.Net")}

# ----- Loop thru VMs
$Network | Foreach { $_.LinkedView.Vm } | Foreach {   
    Write-Output "Working on $($_.Name)"

    # ----- Get IP info so we can add it to new NIC
    $Parent = $_.Name
    $VM = $_.Guest

 #   $VM.Net.ipconfig.dhcp.ipv4


    $VM.Net | where Network -like 'dv-10gig*' | foreach {
        
        $_
        
        $Net = New-Object -TypeName PSObject -Property (@{
            Parent = $parent
            IPAddress = [String]$_.IPAddress
            Subnet = $_.IPConfig.IPAddress.PrefixLength
            DNS = [String]$_.DNSConfig.IPAddress 
            Network = $_.Network
            OldMAC = $_.MacAddress
        })

        $Net

        # ----- Add New NIC
        #Get-VM -Name $Net.Parent | New-NetworkAdapter -Portgroup $Net.Network -Type Vmxnet3

        # ----- Disconnect Old NIC in Vmware

        # ----- Remove IP from old NIC


        # ----- Update New NIC IP

        # ----- Connect via VMWare

    }


}