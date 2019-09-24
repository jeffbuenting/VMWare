function Get-VMWareVMStatIOPS {

<#
    .SYNOPSIS
        Retrieves the IOPS used by a VM datastore

#>

    [CmdletBinding()]
    param (
        [Parameter ( ParameterSetName = 'VM', Mandatory = $True, ValueFromPipeline = $True )]
        [PSObject[]]$VM
    )

    Process {
        foreach ( $V in $VM ) {
            # ----- If $VM is not a VM Object
            Switch ( $V.GetType().Name ) {
                'UniversalVirtualMachineImpl' {
                    Write-Verbose "VM is a VM Object"
                }

                'string' {
                    Write-Verbose "VM is a string, getting VM Object"
                    $V = Get-VM -Name $V
                }

                default {
                    Write-Verbose "$($VM.gettype().name)"
                    Throw "Get-VMWareVMStatIOPS : an object other than a VM object or a VM name (String) was passed."
                }
            }

            # ----- Get the stats
            $Stats = Get-Stat -Entity $V -Realtime -Stat "disk.numberwrite.summation","disk.numberread.summation" -Start ((Get-Date).AddMinutes(-5))

            $Stats | foreach {
                
            }

            Write-Output 
        }
    }


}

