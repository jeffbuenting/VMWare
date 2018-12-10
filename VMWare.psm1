Function Get-VMWareVMReconfiguration {

<#
    .Synopsis
        List VM Reconfigurations

    .Description
        audit changes made to a virtual machine

    .Parameter Event
        Event of type VmReconfiguredEvent.  Any other type of event will throw an error

    .Example
        List changes in the month of November for the following vm: Server01

        (Get-VIEvent -Entity Server01) | where { $_.gettype().name -eq 'VmReconfiguredEvent' } | Get-VMWareVMReconfiguration

    .Link
        Modified script from this link

 
        http://www.lucd.info/2009/12/18/events-part-3-auditing-vm-device-changes/

    .Note
        Author : Jeff Buenting
        Date : 2018 DEC 03
        
#>

    [CmdletBinding()]
    Param (
        [parameter( Mandatory = $True, ValueFromPipeline = $True)]
        [VMWare.Vim.VmReconfiguredEvent[]]$Event
    )

    Process {
        Foreach ( $E in $Event ) {
            Write-verbose "Auditing $($E.VM.name)"

            $event.ConfigSpec.DeviceChange | Foreach {
			    if($_.Device -ne $null){
				    $report = New-Object PSObject -Property @{
					    VMname = $E.VM.Name
					    Date = $E.CreatedTime
					    User = $E.UserName
					    Device = $_.Device.GetType().Name
					    Operation = $_.Operation
				    }

                    Write-Output $Report
			    }
		    }
        }
    }
}

# -------------------------------------------------------------------------------------

function Get-VMWareOrphanedFiles {

<#
    .SYNOPSIS
        Find orphaned files on a datastore

    .DESCRIPTION
        This function will scan the complete content of a datastore.
        It will then verify all registered VMs and Templates on that
        datastore, and compare those files with the datastore list.
        Files that are not present in a VM or Template are considered
        orphaned

    .NOTES
        Author:  Luc Dekens
        Edited by : Jeff Buenting
            Date: 2018 Dec 06

    .PARAMETER Datastore
        The datastore that needs to be scanned

    .EXAMPLE
        PS> Get-VMWareOrphanedFiles -Datastore DS1

    .EXAMPLE
        PS> Get-Datastore -Name DS* | Get-VMWareOrphanedFiles

    .EXAMPLE
        Count files by datastore and used space.

        Get-DataStore | Get-VMWareOrphanedFiles | group-object -Property datastore | foreach-object { New-object PSObject -Property @{ datastore=$_.name;Count=$_.count;Total=($_.group | measure-object -Property size -sum).sum/1TB} }

    .Link
        www.lucd.info/2016/09/13/orphaned-files-revisited/
#>

    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [PSObject[]]$Datastore
    )


    Begin{
        
        Try {
            # ----- Search datastore sub folders parameters
            $flags = New-Object -TypeName VMware.Vim.FileQueryFlags -ErrorAction Stop
            $flags.FileOwner = $true
            $flags.FileSize = $true
            $flags.FileType = $true
            $flags.Modification = $true
            $qFloppy = New-Object VMware.Vim.FloppyImageFileQuery -ErrorAction Stop
            $qFolder = New-Object VMware.Vim.FolderFileQuery -ErrorAction Stop
            $qISO = New-Object VMware.Vim.IsoImageFileQuery -ErrorAction Stop
            $qConfig = New-Object VMware.Vim.VmConfigFileQuery -ErrorAction Stop

            $qConfig.Details = New-Object VMware.Vim.VmConfigFileQueryFlags -ErrorAction Stop                       
            $qConfig.Details.ConfigVersion = $true
           $qTemplate = New-Object VMware.Vim.TemplateConfigFileQuery -ErrorAction Stop
            $qTemplate.Details = New-Object VMware.Vim.VmConfigFileQueryFlags -ErrorAction Stop
            $qTemplate.Details.ConfigVersion = $true
            $qDisk = New-Object VMware.Vim.VmDiskFileQuery -ErrorAction Stop
            $qDisk.Details = New-Object VMware.Vim.VmDiskFileQueryFlags -ErrorAction Stop
            $qDisk.Details.CapacityKB = $true
            $qDisk.Details.DiskExtents = $true
            $qDisk.Details.DiskType = $true
            $qDisk.Details.HardwareVersion = $true
            $qDisk.Details.Thin = $true
            $qLog = New-Object VMware.Vim.VmLogFileQuery -ErrorAction Stop
            $qRAM = New-Object VMware.Vim.VmNvramFileQuery -ErrorAction Stop
            $qSnap = New-Object VMware.Vim.VmSnapshotFileQuery -ErrorAction Stop 
            $searchSpec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec -ErrorAction Stop
            $searchSpec.details = $flags
            $searchSpec.Query = $qFloppy,$qFolder,$qISO,$qConfig,$qTemplate,$qDisk,$qLog,$qRAM,$qSnap
            $searchSpec.sortFoldersFirst = $true
        }
        catch {
            $ExceptionMessage = $_.Exception.Message
            $ExceptionType = $_.Exception.GetType().Fullname
            Throw "Get-VMWareOrphanedFiles : Error setting SearchDatastoreSubFolders Parameters.`n`n     $ExceptionMessage`n`n $ExceptionType"
        }
    }

    Process{
        foreach($ds in $Datastore) {

            Try {
                # ----- Accepts datastore names and then converts to datastore object if needed
                if($ds.GetType().Name -eq "String"){
                    Write-Verbose "Input is a string.  Getting Datastore"
                    $ds = Get-Datastore -Name $ds -ErrorAction Stop
                }
            }
            catch {
                $ExceptionMessage = $_.Exception.Message
                $ExceptionType = $_.Exception.GetType().Fullname
                Throw "Get-VMWareOrphanedFiles : Error Getting Datastore from string input.`n`n     $ExceptionMessage`n`n $ExceptionType"
            }

            Write-Verbose "Datastore = $($DS | out-string)"
 
            # ----- Only shared VMFS datastore
            if($ds.Type -eq "VMFS" -and $ds.ExtensionData.Summary.MultipleHostAccess -and $ds.Accessible){
                Write-Verbose -Message "$(Get-Date)`t$((Get-PSCallStack)[0].Command)`tLooking at $($ds.Name)"
  
                # ----- Define file DB
                $fileTab = @{}

                # ----- This hash table will be used to determine which file/folder is orphaned or not. First all the files the method fins are placed in the hash table. Then the files that belong to VMs and Templates are removed. Finally some system files are removed. What is left are orphaned files.
 
                Try {
                    # ----- Get datastore files
                    $dsBrowser = Get-View -Id $ds.ExtensionData.browser
                    $rootPath = "[" + $ds.Name + "]"

            write-verbose $($DSbrowser | out-string)

                    $searchResult = $dsBrowser.SearchDatastoreSubFolders($rootPath, $searchSpec) #| Sort-Object -Property {$_.FolderPath.Length}
                }
                catch {
                    $ExceptionMessage = $_.Exception.Message
                    $ExceptionType = $_.Exception.GetType().Fullname
                    Throw "Get-VMWareOrphanedFiles : Error Getting DataStore Files.`n`n     $ExceptionMessage`n`n $ExceptionType"
                }
             
                # ----- extract file object from SearchResult
                foreach($folder in $searchResult){
                    foreach ($file in $folder.File){
                        Write-Verbose "Processing $($File.path)"

                        $key = "$($folder.FolderPath)$(if($folder.FolderPath[-1] -eq ']'){' '})$($file.Path)"
                        $fileTab.Add($key,$file)

                        # ----- Take care of the folder entries. If a file inside a folder is encountered, the script also removes the folder itself from the hash table
                        $folderKey = "$($folder.FolderPath.TrimEnd('/'))"       
                        if($fileTab.ContainsKey($folderKey)){
                            $fileTab.Remove($folderKey)
                        }
                    }
                }

                # ----- Remove files from the list belonging to existing VMs
                Get-VM -Datastore $ds #| Foreach {
               #     write-verbose "VM = $($_ | out-string)"
               #     $_.ExtensionData.LayoutEx.File | Foreach {
               #         if($fileTab.ContainsKey($_.Name)){
               #             $fileTab.Remove($_.Name)
               #         }
               #     }
               # }
 
                # ----- Remove files from the list belonging to existing Templates
                Get-Template -ErrorAction Stop | where {$_.DatastoreIdList -contains $ds.Id} | %{
                    $_.ExtensionData.LayoutEx.File | %{
                        if($fileTab.ContainsKey($_.Name)){
                            $fileTab.Remove($_.Name)
                        }
                    }
                }

                # ----- Remove system files & folders from list.  Any file in a folder that begins with a . ro VMKDump
                $systemFiles = $fileTab.Keys | where{$_ -match "] \.|vmkdump"}
                $systemFiles | Foreach {
                    $fileTab.Remove($_)
                }
 
                # ----- Organise remaining files.  These are the orphaned files
                if($fileTab.Count){
                      $fileTab.GetEnumerator() | Foreach {
                            $obj = [ordered]@{
                                  Name = $_.Value.Path
                                  Folder = $_.Name
                                  Size = $_.Value.FileSize
                                  CapacityKB = $_.Value.CapacityKb
                                  Modification = $_.Value.Modification
                                  Owner = $_.Value.Owner
                                  Thin = $_.Value.Thin
                                  Extents = $_.Value.DiskExtents -join ','
                                  DiskType = $_.Value.DiskType
                                  HWVersion = $_.Value.HardwareVersion
                                  DataStore = $DS.Name
                            }
 
                            New-Object -type PSObject -Property $obj
                      }
 
                      Write-Verbose -Message "$(Get-Date)`t$((Get-PSCallStack)[0].Command)`tFound orphaned files on $($ds.Name)!"
                }
                else{
                     Write-Verbose -Message "$(Get-Date)`t$((Get-PSCallStack)[0].Command)`tNo orphaned files found on $($ds.Name)."
                }
            }
            Else {
                Write-Warning "Get-VMWareOrphanedFiles : Skipping $($DS.Name) as it is not a VMFS datastore."
            }
        }
    }
}



