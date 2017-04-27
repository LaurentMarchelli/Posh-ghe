#
# ghe_config.ps1 : GheConfig Implementation Classes
# 

class GheConfigCmd : GheCommand
{
	[GheConfig]$Config

	GheConfigCmd([GheConfig]$Config, [String]$Query) : base($Query) 
		{ $this.Config = $Config }
	
	# Virtual callback method used to parse the result
	[void] SetResponse([System.Object]$Response)
	{
		# Call base class
		([GheCommand]$this).SetResponse($Response)

		# Convert parameters list into parameters dictionary
		$conf_list = $this.Response.Output
		$conf_res = $this.Config
		$last_key = $null
		ForEach($conf_obj in $conf_list)
		{
			switch -regex ($conf_obj)
            {
				"^-----END .*-----$"
				{ 
					$conf_res[$last_key] += "`r`n" + $conf_obj
					$last_key = $null
					break
				}

				# With "ghe-config -l" value is separated from the parameter by the first equal
				# With "ghe-config --get-regexp -l" value is separated from the parameter by the first space
				
				"^([^= ]*)[= ](-----BEGIN .*-----)$"
				{ 
					$last_key = $matches[1]
					$conf_res[$last_key] = $matches[2]
					break
				}
				
				"^([^= ]*)[= ](.*)$" # Parameter / Value
				{ 
					if($last_key -eq $null)
					{ 
						$conf_res[$matches[1]] = $matches[2] 
						break
					}
				}

				"^.*$"
				{
					if($last_key -ne $null)
						{ $conf_res[$last_key] += "`r`n" + $conf_obj }
					else
						{ Write-Output("[ERROR] : Unable to parse {0}" -f $conf_obj) }
					break
				}
			}
		}
	}
}

class GheConfig : System.Collections.Specialized.OrderedDictionary
{
	GheConfig([GheClient]$GheClient) : base()
		{ $this._create($GheClient, $null) }

	GheConfig([GheClient]$GheClient, [String]$RegEx) : base()
		{ $this._create($GheClient, $RegEx) }
		
	hidden [void] _create(
		[GheClient]$GheClient,
		[String]$RegEx)
	{
		# Create the linux command text
		if(!$RegEx)
			{ $CommandText = "ghe-config -l" }
		else
			{ $CommandText = "ghe-config --get-regexp '{0}'" -f $RegEx }

		# Create a Property to save the command (Not a Dictionnary Key !)
		$CommandObj = [GheConfigCmd]::new($this, $CommandText)
		$this | Add-Member NoteProperty -Name _Command -Value $CommandObj

		# Run ssh command to get the result
		$GheClient.SendCommand($CommandObj)
	}
}
