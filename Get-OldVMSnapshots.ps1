<# 
.SYNOPSIS 
	Script to report on old vmware snapshots
.DESCRIPTION 
	Script to report on old vmware snapshots. Can save report to a csv file or email recipients. 
.PARAMETER
.EXAMPLE
.NOTES 
#>

[CmdletBinding()]
PARAM (
    [int]$DaysOld = '2',
    [Parameter(HelpMessage = "Enter at least one vCentre server FQDN or IP address. Multiple vCentre servers should be separated by a comma.")]
    [array]$VIServers = "",
    [parameter(ParameterSetName='Email')]
    [switch]$EmaiOutput,
    [parameter(ParameterSetName='Email',Mandatory=$true)]
    [string]$EmailSubject = "VMware Old Snapshots Report",
    [parameter(ParameterSetName='Email',Mandatory=$true)]
    [string]$EmailTo = "Ryan Kowalewski <ryan.kowalewski@salisbury.nhs.uk>",
    [parameter(ParameterSetName='Email',Mandatory=$true)]
    [string]$EmailFrom = "Powershell Alert <ryan.kowalewski@salisbury.nhs.uk>",
    [parameter(ParameterSetName='Email',Mandatory=$true)]
    [string]$EmailSMTP = "exvs.shc.local"
)

BEGIN
{
    TRY
    {

        # Verify VMware Snapin is loaded
        IF (-not (Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue))
        {
            Write-Verbose -Message "BEGIN - Loading Vmware Snapin VMware.VimAutomation.Core..."
            Add-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction Stop -ErrorVariable ErrorBeginAddPssnapin
        }

        # Verify VMware Snapin is connected to at least one vcenter 
        IF (-not ($global:DefaultVIServer.count -gt 0)) 
        { 
			Write-Verbose -Message "BEGIN - Currently not connected to a vCenter server, please specify -VIServers..." 
			Connect-VIServer -Server $VIServers -ErrorAction Stop -ErrorVariable ErrorBeginConnectViServer 
		}
    }#TRY
    CATCH
    {
        IF ($ErrorBeginAddPssnapin)
        {
            Write-Warning -Message "BEGIN - VMware Snapin VMware.VimAutomation.Core does not seem to be available"
            Write-Error -message $Error[0].Exception.Message
        }

        IF ($ErrorBeginConnectViServer) 
        { 
            Write-Warning -Message "BEGIN - Couldnt connect to the Vcenter" 
            Write-Error -message $Error[0].Exception.Message 
        } 
    }#CATCH
}#BEGIN  	 

PROCESS
{
    TRY
    {
        
        $VMs = Get-VM
        $Output = @()

        ForEach ($VM in $VMs)
        {
            TRY
            {
                $Snapshots = Get-Snapshot -VM $VM
                
                ForEach($Snapshot in $Snapshots)
                {
                    If ($Snapshot.Created -lt (Get-Date).AddDays(-$DaysOld))
                    {
                                    $Snap = $Snapshot | Select-Object @{N="VM Name";E={$Snapshot.VM}},@{N="Snapshot Name";E={$Snapshot.Name}},@{N="Created";E={$Snapshot.Created.Date.ToString("dd/MM/yyyy")}},`                        @{N="Size GB";E={[math]::Round($Snapshot.SizeGB,2)}}
            
                        $Output = $Output + $Snap
                    }
                }
            }#TRY
            CATCH
            {
                Write-Warning -Message "Something wrong happened with $($VM.Name)."
                Write-Warning -Message $Error[0].Exception.Message
            }#CATCH
        }

        IF ($EmailOutput)
        {
            $EmailBody = $Output | Sort-Object "VM Name" | ConvertTo-Html -Fragment | Out-String
            Send-MailMessage -To $EmailTo -From $EmailFrom -Subject $EmailSubject -Body $EmailBody -BodyAsHtml -SmtpServer $EmailSMTP     
        }

         
    }#TRY
    CATCH
    {
        Write-Warning -Message "Something wrong happened in the script."
        Write-Warning -Message $Error[0].Exception.Message
        
    }#CATCH
}#PROCESS