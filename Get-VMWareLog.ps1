function Get-VMWareVMLog {

<#
    .SYNOPSIS
        Retrieve the virtual machine logs

    .DESCRIPTION
        The function retrieves the logs from one or more
        virtual machines and stores them in a local folder

    .NOTES
        Author:  Luc Dekens
        Jeff Buenting:  I modified this to fit my needs.  added some error handling etc.  But credit goes to Luc Dekens.

    .PARAMETER VM
        The virtual machine(s) for which you want to retrieve
        the logs.
        .PARAMETER Path
        The folderpath where the virtual machines logs will be
        stored. The function creates a folder with the name of the
        virtual machine in the specified path.

    .EXAMPLE
        PS> Get-VMLog -VM $vm -Path "C:\VMLogs"

    .EXAMPLE
        PS> Get-VM | Get-VMLog -Path "C:\VMLogs"


    .LINKS
        http://www.lucd.info/2011/02/27/virtual-machine-logging/
#>

    param(
        [parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [PSObject[]]$VM,

        [parameter(Mandatory=$true)]
        [string]$Path
    )

    process{
        foreach($obj in $VM){
            if($obj.GetType().Name -eq "string"){
                $obj = Get-VM -Name $obj
            }
        }

        $logPath = $obj.Extensiondata.Config.Files.LogDirectory
        Write-Verbose "LogPath = $LogPath"

        $dsName = $logPath.Split(']')[0].Trim('[')
        $vmPath = $logPath.Split(']')[1].Trim(' ')

        # ----- what if the datastore name is used in more than one datacenter?
        $Datacenter = $Obj | Get-datacenter | Select-object -ExpandProperty Name

        $ds = Get-Datastore -Name $dsName -Location $Datacenter
        $drvName = "MyDS" + (Get-Random)

        New-PSDrive -Location $ds -Name $drvName -PSProvider VimDatastore -Root '\' | Out-Null
        Copy-DatastoreItem -Item ($drvName + ":" + $vmPath + "*.log") -Destination ($Path + "\" + $obj.Name + "\") -Force:$true
        Remove-PSDrive -Name $drvName -Confirm:$false
    }
}