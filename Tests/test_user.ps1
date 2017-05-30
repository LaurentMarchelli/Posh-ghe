#
# test_users.ps1
#

Param(
	[Parameter(Mandatory=$true)][String]$ServerUri,
	[Parameter(Mandatory=$true)][String]$AdminToken,
	[Parameter(Mandatory=$false)][UInt16]$SshHostPort=122,
	[Parameter(Mandatory=$true)][String]$SshKeyPath,
	[Parameter(Mandatory=$true)][string]$CsvExportFile
)

###############################################################################
#                            Main program
###############################################################################
Begin
{
	Write-Debug "PsBoundParameters:"
    $PSBoundParameters.GetEnumerator() | % { Write-Debug $_ }

	if($PSBoundParameters['Debug']) { $DebugPreference = 'Continue' }
    Write-Debug "DebugPreference: $DebugPreference"

    Write-Verbose "$($MyInvocation.MyCommand.Name):: Function started"
}
Process
{
	Import-Module $PSScriptRoot\..\Posh-ghe.psd1
	$GheGHubColl = Get-GheUsers -ServerUri $ServerUri -AdminToken $AdminToken -SshHostPort $SshHostPort -SshKeyPath $SshKeyPath `
		-CsvExportFile $CsvExportFile
	
	# Display the active users list (for sample)
	# $GheGHubColl.Values | Where {$_.suspension_status -ne "suspended"} | Out-gridview
	# $GheGHubColl.Values | Out-gridview

	Remove-Module Posh-ghe
}
End
{
	Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"
}