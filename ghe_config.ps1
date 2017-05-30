#
# ghe_config.ps1 : GheConfig Implementation Classes
# 

class GheConfig : System.Collections.Specialized.OrderedDictionary
{
	# Intance (GheConfig) Singleton pattern
	static [GheConfig] Get([GheClient] $GheClient)
		{ return [GheConfig]::Get($GheClient, $null) }
	
	static [GheConfig] Get([GheClient] $GheClient, [String] $RegEx)
	{
		# Create the configuration cache if it does not exists
		if($GheClient._Config -eq $null)
		{
			$config = [GheConfig]::new($GheClient, $RegEx)
			# Attach the configuration to the client for subsequent call cache
			$GheClient | Add-Member NoteProperty -Name _Config -Value $config -Force
		}
		return $GheClient._Config
	}

	Hidden [GheCommand] $_Command

	GheConfig([GheClient] $GheClient) : base()
		{ $this._create($GheClient, $null) }

	GheConfig([GheClient] $GheClient, [String] $RegEx) : base()
		{ $this._create($GheClient, $RegEx) }
		
	hidden [void] _create(
		[GheClient] $GheClient,
		[String] $RegEx)
	{
		# Create the linux command text
		if(!$RegEx)
			{ $CommandText = "ghe-config -l" }
		else
			{ $CommandText = "ghe-config --get-regexp '{0}'" -f $RegEx }

		# The tricky way to set the class property without adding a key / value
		# pair to the [hashtable].
		$CommandObj = [GheCommand]::new($CommandText)
		[GheConfig].GetProperty("_Command").SetValue(
			$this, $CommandObj)

		# Run ssh command to get the result
		$GheClient.SendCommand($CommandObj)

		# Convert Response parameters list into parameters dictionary
		$conf_list = $CommandObj.Response.Output
		$last_key = $null
		ForEach($conf_obj in $conf_list)
		{
			switch -regex ($conf_obj)
            {
				"^-----END .*-----$"
				{ 
					$this[$last_key] += "`r`n" + $conf_obj
					$last_key = $null
					break
				}

				# With "ghe-config -l" value is separated from the parameter by the first equal
				# With "ghe-config --get-regexp -l" value is separated from the parameter by the first space
				
				"^([^= ]*)[= ](-----BEGIN .*-----)$"
				{ 
					$last_key = $matches[1]
					$this[$last_key] = $matches[2]
					break
				}
				
				"^([^= ]*)[= ](.*)$" # Parameter / Value
				{ 
					if($last_key -eq $null)
					{ 
						$this[$matches[1]] = $matches[2] 
						break
					}
				}

				"^.*$"
				{
					if($last_key -ne $null)
						{ $this[$last_key] += "`r`n" + $conf_obj }
					else
						{ Write-Output("[ERROR] : Unable to parse {0}" -f $conf_obj) }
					break
				}
			}
		}


	}
}
