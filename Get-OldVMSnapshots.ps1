<# 
.SYNOPSIS 
	Script to report on old vmware snapshots

.DESCRIPTION 
	Script to report on old vmware snapshots. Can save report to a csv file or email csv file to specified recipients. 

.PARAMETER DaysOld
    Specify the number of days of which the snapshot must be older in order to be included in the results.

.PARAMETER VIServers
    Specify FQDN or IP addresses of one or more vCentre servers. To specify multiple servers separate each server with a comma. If you are already connected to a vCentre server the script will ignore this input.

.PARAMETER EmailOutput
    Specify this switch if you would like the output CSV file to be emailed to one or more recipients.

.PARAMETER EmailSubject
    If EmailOutput is specified use EmailSubject to set the subject line of the outgoing email.

.PARAMETER EmailTo
    If EmailOutput is specified use EmailTo to specify the intended recipients of the outgoing email. Can be a single email address or a comma separated list of email addresses.

.PARAMETER EmailFrom
    If EmailOutput is specified use EmailFrom to specify the email address for the outgoing email to be sent via.

.PARAMETER EmailSMTP
    If EmailOutput is specified use EmailSMTP to specify the FQDN or IP address of an SMTP server.

.PARAMETER EmailBody
    If EmailOutput is specified use EmailBody to write the body text of the outgoing email.

.PARAMETER CSVOutput
    Specify this switch if you would like the output to be saved to a CSV file.

.PARAMETER CSVOutputPath
    If CSVOutput is specified use CSVOutputPath to specify the full path of the CSV file.

.EXAMPLE
    .\Get-OldVMSnapshots.ps1 -DaysOld 2 -VIServers vCentreServer.example.com

.EXAMPLE
    .\Get-OldVMSnapshots.ps1 -DaysOld 2 -VIServers vCentreServer.example.com -CSVOutput -CSVOutputPath D:\test.csv

.EXAMPLE
    .\Get-OldVMSnapshots.ps1 -DaysOld 2 -VIServers vCentreServer.example.com -EmailOutput -EmailSubject "Testing VMware Snapshot Report" -EmailTo "Joe.Bloggs@example.com" -EmailFrom "sender@example.com" -EmailSMTP "smtp.example.com" -EmailBody "Dear Users,`n`nPlease find attached a report of all virtual machines with snapshots which were created more than 2 days ago.`n`nRegards`n`nInfrastructure Team"

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
    [string]$EmailTo = "Joe.Bloggs@example.com",
    [parameter(ParameterSetName='Email',Mandatory=$true)]
    [string]$EmailFrom = "sender@example.com",
    [parameter(ParameterSetName='Email',Mandatory=$true)]
    [string]$EmailSMTP = "smtp.example.com",
    [parameter(ParameterSetName='Email')]
    [string]$EmailBody = "Dear Users,`n`nPlease find attached a report of all virtual machines with snapshots which were created more than $DaysOld days ago.`n`nRegards`n`nInfrastructure Team",
    [parameter(ParameterSetName='CSV')]
    [switch]$CSVOutput,
    [parameter(ParameterSetName='CSV',Mandatory=$true)]
    [string]$CSVOutputPath = ""
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
        # Get all virtual machine objects for connected vCentre servers
        $VMs = Get-VM

        # Create empty Output variable
        $Output = @()

        # Start looping through each virtual machine object
        ForEach ($VM in $VMs)
        {
            TRY
            {
                # Get all snapshots for current virtual machine
                $Snapshots = Get-Snapshot -VM $VM
                
                # Start looping through snapshots for current virtual machine
                ForEach($Snapshot in $Snapshots)
                {
                    # If snapshot is older the DaysOld variable specified, add to Output variable
                    If ($Snapshot.Created -lt (Get-Date).AddDays(-$DaysOld))
                    {
                        # Format before adding to Output variable                        $Snap = $Snapshot | Select-Object @{N="VM Name";E={$Snapshot.VM}},@{N="Snapshot Name";E={$Snapshot.Name}},@{N="Created";E={$Snapshot.Created.Date.ToString("dd/MM/yyyy")}},`                        @{N="Size GB";E={[math]::Round($Snapshot.SizeGB,2)}}
                        
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
            #$EmailBody = $Output | Sort-Object "VM Name" | ConvertTo-Html -Fragment | Out-String
            $Output | Sort-Object "VM Name" | Export-Csv -Path "$env:TEMP\OldVMSnapshots.csv" -NoTypeInformation
            Send-MailMessage -To $EmailTo -From $EmailFrom -Subject $EmailSubject -Body $EmailBody -SmtpServer $EmailSMTP -Attachments "$env:TEMP\OldVMSnapshots.csv"    
        }

        ELSEIF ($CSVOutput)
        {
            $Output | Sort-Object "VM Name" | Export-Csv -Path $CSVOutputPath -NoTypeInformation
        }
        ELSEIF (-not($EmaiOutput) -or ($CSVOutput))
        {
            $Output | Sort-Object "VM Name"
        }

         
    }#TRY
    CATCH
    {
        Write-Warning -Message "Something wrong happened in the script."
        Write-Warning -Message $Error[0].Exception.Message
        
    }#CATCH
}#PROCESS