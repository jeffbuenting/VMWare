Function Get-VMWareVMMethod {

    <#
        .SYNOPSIS
            Lists the methods and their Statuses


        .Links
            https://www.virtuallyghetto.com/2016/07/how-to-easily-disable-vmotion-cross-vcenter-vmotion-for-a-particular-virtual-machine.html
            https://github.com/lamw/vghetto-scripts/blob/master/powershell/enable-disable-vsphere-api-method.ps1

    #>

    [CmdletBinding()]
    param (
        [Parameter ( Position = 0,Mandatory = $True, ValueFromPipeline = $True  )]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]]$VM

    )

    Process {
        Foreach ( $V in $VM ) { 
            Write-Verbose "Processing $($VM.Name) for disabled methods"

            $DM = [PSCustomObject]@{
                Name = $V.Name
                DisabledMethod = $V.extensiondata.DisabledMethod
            }

            Write-Output $DM
        }
    }
}

#---------------------------------------------------------------------------------------

Function Set-VMWareVMMethod {

    [CmdletBinding()]
    param (
        [Parameter ( Position = 0,Mandatory = $True, ValueFromPipeline = $True  )]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]]$VM,

        [parameter (Mandatory = $True)]
        [PSCredential]$Credential,

        [String]$MOBServer,

        [ValidateSet ('vMotion')]
        [String]$Method,

        [Bool]$Enable

    )

    Begin {
        # ----- build the MOB url depending on the method
        switch ( $Method ) {
            'vMotion' {
                Write-Verbose 'vMotion MOB url'

                if ( $Enable ) {
                    Write-Verbose "Enable vMotion"

                    $Url = "https://$MOBServer/mob/?moid=AuthorizationManager&method=enableMethods"
                }
                Else{
                    Write-Verbose "Disable vMotion"

                    $Url = "https://$MOBServer/mob/?moid=AuthorizationManager&method=disableMethods"
                }

                $MethodTask = 'RelocateVM_Task'
            }
                
            default {
                Throw "Set-VMWareMethod : Unknown method, $Method"
            }
        }

        Write-Verbose $Url

        # Initial login to vSphere MOB using GET and store session using $vmware variable
        $results = Invoke-WebRequest -Uri $Url -SessionVariable vmware -Credential $credential -Method GET

        # Extract hidden vmware-session-nonce which must be included in future requests to prevent CSRF error
        # Credit to https://blog.netnerds.net/2013/07/use-powershell-to-keep-a-cookiejar-and-post-to-a-web-form/ for parsing vmware-session-nonce via Powershell
        if($results.StatusCode -eq 200) {
            $null = $results -match 'name="vmware-session-nonce" type="hidden" value="?([^\s^"]+)"'
            $sessionnonce = $matches[1]
        } else {       
            Throw "Set-VMWareMethod : Failed to login to vSphere MOB"       
        }       
    }

    Process {
        Foreach ( $V in $VM ) {
            Write-Verbose "Updating $MethodTask on $($VM.Name)"

            $VMView = Get-View -VIObject $VM

            # The POST data payload must include the vmware-session-nonce variable + URL-encoded
            $body = @"
vmware-session-nonce=$sessionnonce&entity=%3Centity+type%3D%22ManagedEntity%22+xsi%3Atype%3D%22ManagedObjectReference%22%3E$($VMView.MoRef.Value)%3C%2Fentity%3E%0D%0A&method=%3Cmethod%3E$MethodTask%3C%2Fmethod%3E
"@
            
            $Body

        }
    }


}