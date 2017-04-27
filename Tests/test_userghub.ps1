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
Process
{
	Import-Module $PSScriptRoot\..\Posh-ghe.psd1
	$GheGHubColl = Get-GheGHubUsers -ServerUri $ServerUri -AdminToken $AdminToken -SshHostPort $SshHostPort -SshKeyPath $SshKeyPath `
		-CsvExportFile $CsvExportFile
	
	# Display the active users list (for sample)
	# $GheGHubColl.Values | Where {$_.suspension_status -ne "suspended"} | Out-gridview
	# $GheGHubColl.Values | Out-gridview

	Remove-Module Posh-ghe
}
