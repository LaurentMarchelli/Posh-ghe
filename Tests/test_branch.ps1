#
# test_branch.ps1
#

Param(
	[Parameter(Mandatory=$true)][String]$ServerUri,
	[Parameter(Mandatory=$true)][String]$AdminToken,
	[Parameter(Mandatory=$false)][UInt16]$SshHostPort=122,
	[Parameter(Mandatory=$true)][String]$SshKeyPath,
	[Parameter(Mandatory=$true)][string]$OrgaName,
	[Parameter(Mandatory=$true)][string]$RepoName,
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
	$BranchColl = Get-GheBranches -ServerUri $ServerUri -AdminToken $AdminToken -SshHostPort $SshHostPort -SshKeyPath $SshKeyPath `
		-Organization $OrgaName -Repository $RepoName -CsvExportFile $CsvExportFile

	# $BranchColl.Values | Out-gridview
	Remove-Module Posh-ghe
}
End
{
	Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"
}