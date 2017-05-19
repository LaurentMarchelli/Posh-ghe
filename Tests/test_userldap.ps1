#
# test_userldap.ps1
#

Param(
	[Parameter(Mandatory=$true)][String]$ServerUri,
	[Parameter(Mandatory=$true)][String]$AdminToken,
	[Parameter(Mandatory=$false)][UInt16]$SshHostPort=122,
	[Parameter(Mandatory=$true)][String]$SshKeyPath,
	[Parameter(Mandatory=$false)][String]$SuspendedRegEx=$null,
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
	if($SuspendedRegEx)
	{
		$GheLDAPColl = Get-GheLDAPUsers `
			-ServerUri $ServerUri -AdminToken $AdminToken `
			-SshHostPort $SshHostPort -SshKeyPath $SshKeyPath `
			-SuspendedRegEx $SuspendedRegEx -CsvExportFile $CsvExportFile
	}
	else
	{
		$GheLDAPColl = Get-GheLDAPUsers `
			-ServerUri $ServerUri -AdminToken $AdminToken `
			-SshHostPort $SshHostPort -SshKeyPath $SshKeyPath `
			-CsvExportFile $CsvExportFile
	}

	# Display the active users list (for sample)
	# $GheLDAPColl.Values | Where {$_.suspension_status -ne "suspended"} | Out-gridview
	# $GheLDAPColl.Values | Out-gridview

	Remove-Module Posh-ghe
}
End
{
	Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"
}