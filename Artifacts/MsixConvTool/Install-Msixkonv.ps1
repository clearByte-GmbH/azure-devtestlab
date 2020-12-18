#Dateinamen muss noch mitgegben werden

###################################################################################################
#
# PowerShell configurations
#

# NOTE: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.
#       This is necessary to ensure we capture errors inside the try-catch-finally block.
$ErrorActionPreference = 'Stop'

# Suppress progress bar output.
$ProgressPreference = 'SilentlyContinue'

# Ensure we force use of TLS 1.2 for all downloads.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

###################################################################################################
#
# Handle all errors in this script.
#

trap
{
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    $message = $Error[0].Exception.Message
    if ($message)
    {
        Write-Host -Object "`nERROR: $message" -ForegroundColor Red
    }

    Write-Host "`nThe artifact failed to apply.`n"

    # IMPORTANT NOTE: Throwing a terminating error (using $ErrorActionPreference = "Stop") still
    # returns exit code zero from the PowerShell script when using -File. The workaround is to
    # NOT use -File when calling this script and leverage the try-catch-finally block and return
    # a non-zero exit code from the catch block.
    exit -1
}

###################################################################################################
#
# Functions used in this script.
#



#Appman Sequencer on amd64-x64_en-us.msi
function Install-Msix
{
    [CmdletBinding()]
    param
    (
        [String]
        $Msix
    )
     
   Add-AppxPackage -Path $Msix
}



function DownloadFilesFromRepo 
{
        $baseUri = "https://api.github.com/"
        $folderargs = "repos/$Owner/$Repository/contents/$Path"
        $wr = Invoke-WebRequest -Uri $($baseuri+$folderargs) -UseBasicParsing
        $objects = $wr.Content | ConvertFrom-Json
        $files = $objects | Where-Object {$_.type -eq "file"} | Select-Object -exp download_url
        $directories = $objects | Where-Object {$_.type -eq "dir"}
        
        $directories | ForEach-Object { 
            DownloadFilesFromRepo -Owner $Owner -Repository $Repository -Path $_.path -DestinationPath $($DestinationPath+$_.name)
        }
    
        
        if (-not (Test-Path $DestinationPath)) {
            # Destination path does not exist, let's create it
            try {
                New-Item -Path $DestinationPath -ItemType Directory -ErrorAction Stop
            } catch {
                throw "Could not create path '$DestinationPath'!"
            }
        }
        foreach ($file in $files) {
           if ((Split-Path $file -Leaf).EndsWith('.msixbundle'))
           { 
            $fileDestination = Join-Path $DestinationPath (Split-Path $file -Leaf)
                try {
                    Invoke-WebRequest -Uri $file -OutFile $fileDestination -ErrorAction Stop -Verbose
                    "Grabbed '$($file)' to '$fileDestination'"
                } catch {
                    throw "Unable to download '$($file.path)'"
                }
            }
        } 
 
       
       
}


###################################################################################################
#
# Main execution block.
# .\Install-AppvSeq.ps1 "clearByteGmbH" "azure-devtestlab-devsource" "AppVSeq" "C:\Users\cblocadmin\AppData\Local\Temp\ucFiles"

$Owner= "clearByteGmbH"
$Repository = "azure-devtestlab-devsource"
$Path = "MsixConvTool"
$Msix = "MSIXPackagingTool_x64.x86_1.2020.402.0.msixbundle"
$DestinationPath = "$env:TEMP\ucFiles"

try
{
    Push-Location $PSScriptRoot

    DownloadFilesFromRepo 

    #DownloadFilesFromRepo "clearByteGmbH" "azure-devtestlab-devsource" "AppVSeq" "C:\Users\cblocadmin\AppData\Local\Temp\ucFiles"  
    Install-Msix -Msix $DestinationPath\$Msix

    Write-Host "`nThe artifact was applied successfully.`n"
}
finally
{
    Pop-Location
}

