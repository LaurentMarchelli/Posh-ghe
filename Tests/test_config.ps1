#
# test_config.ps1
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
Process
{
	Import-Module $PSScriptRoot\..\Posh-ghe.psd1
	$GheClient = Get-GheClient -ServerUri $ServerUri -AdminToken $AdminToken -SshHostPort $SshHostPort -SshKeyPath $SshKeyPath
	
	# Test with different configuration parameters
	$ListRegEx = @(
		$null,
		"^core\..*$",
		"^customer\..*$",
		"^license\..*$",
		"^github-ssl\..*$",
		"^smtp\..*$",
		"^syslog\..*$",
		"^mapping\..*$",
		"^ldap\..*$",
		"^cas\..*$",
		"^saml\..*$",
		"^ntp\..*$",
		"^snmp\..*$",
		"^pages\..*$",
		"^collectd\..*$")

	ForEach($CommandRegEx in $ListRegEx)
	{ 
		if(!$CommandRegEx)
		{
			$CommandText = "ghe-config -l"
			$OutputFmt = "{0}={1}"
		}
		else
		{
			$CommandText = "ghe-config --get-regexp '{0}'" -f $CommandRegEx
			$OutputFmt = "{0} {1}"
		}

		# Get raw configuration data into result1 (reference)
		$CommandObject = $GheClient.SendCommand($CommandText)
		$result1 = $CommandObject.Response.Output | Out-string

		# Get and dump analyzed configuration data
		$Config = Get-GheConfig -GheClient $GheClient -Filter $CommandRegEx
		$result2 = $Config.Keys.ForEach({ $OutputFmt -f $_, $Config[$_] }) | Out-String

		# Check results are identicals : dump analysed data against reference
		if($result1 -eq $result2)
			{ Write-Output ("[OK] Test Passed : '{0}' " -f $CommandText) }
		else
			{ Write-Output ("[ERROR] Test failed : '{0}'" -f $CommandText)}

	}

	Remove-Module Posh-ghe
}
