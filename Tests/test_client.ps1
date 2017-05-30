#
# test_client.ps1
#

Param(
	[Parameter(Mandatory=$true)][String]$ServerUri,
	[Parameter(Mandatory=$true)][String]$AdminToken,
	[Parameter(Mandatory=$false)][UInt16]$SshHostPort=122,
	[Parameter(Mandatory=$true)][String]$SshKeyPath
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
	$GheClient = Get-GheClient -ServerUri $ServerUri -AdminToken $AdminToken -SshHostPort $SshHostPort -SshKeyPath $SshKeyPath

	#######################################
	#	 Testing SendCommand Feature
	#######################################
	# Define expected result (reference)
	$result1 = "ghe-announce: /usr/local/bin/ghe-announce`r`n"
			
	# Try to get the expected result
	$CommandText = 'whereis ghe-announce'
	$CommandObj = $GheClient.SendCommand($CommandText)
	$result2 = $CommandObj.Response.Output | Out-string

	# Check results are identicals : Expected against real
	if($result1 -eq $result2)
		{ Write-Output ("[OK] Test Passed : '{0}' " -f $CommandText) }
	else
		{ Write-Output ("[ERROR] Test failed : '{0}'" -f $CommandText)}

	#######################################
	#	Testing SendAnnounce Feature
	#######################################
	$CommandObj = $GheClient.SendAnnounce("This is a test Announce")
	$CommandObj = $GheClient.ClearAnnounce()

	Remove-Module Posh-ghe
}
End
{
	Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"
}