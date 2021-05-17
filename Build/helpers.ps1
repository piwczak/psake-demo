function Find-PackagePath
{
	[CmdletBinding()]
	param(
		[Parameter(Position=0,Mandatory=1)]$packagePath,
		[Parameter(Position=1,Mandatory=1)]$packageName
	)

	return (Get-ChildItem ($packagePath + "\" + $packageName + "*").FullName | Sort-Object $_ | select -Last 1
}

function Prepare-Tests
{
	[CmdletBinding()]
	param(
		[Parameter(Position=0,Mandatory=1)]$testRunnerName,
		[Parameter(Position=1,Mandatory=1)]$publishedTestsDirectory,
		[Parameter(Position=2,Mandatory=1)]$testResultDirectory,
		[Parameter(Position=3,Mandatory=1)]$testCoverageDirectory
	)

	$projects = Get-ChildItem $publishedTestsDirectory

	if ($projects.Count -eq 1)
	{
		Write-Host "1 $testRunnerName project has been found"
	}
	else 
	{
		Write-Host $projects.Count " $testRunnerName projects have been found"
	}

	Write-Host ($projects | Select $_.Name)

	#Create the test result directory if needed
	if(!(Test-Path $testResultDirectory))
	{
		Write-Host "Creating test result directory located at $testResultDirectory"
		mkdir $testResultDirectory | Out-Null
	}

	if (!(Test-Path $testCoverageDirectory)) 
	{
		Write-Host "Creating test coverage directory located at $testCoverageDirectory"
		mkdir $testCoverageDirectory | Out-Null
	}

	$testAssembliesPaths = $projects | ForEach-Object {"`"`"" + $_.FullName + "\" + $_.Name + ".dll`"`""}

	$testAssemblies = [string]::Join(" ", $testAssembliesPaths)

	return $testAssemblies
}

function Run-Tests 
{
	[CmdletBinding()]
	param(
		[Parameter(Position=0,Mandatory=1)]$openCoverExe,
		[Parameter(Position=1,Mandatory=1)]$targetExe,
		[Parameter(Position=2,Mandatory=1)]$targetArgs,
		[Parameter(Position=3,Mandatory=1)]$coveragePath,
		[Parameter(Position=4,Mandatory=1)]$filter,
		[Parameter(Position=5,Mandatory=1)]$excludeByAttribute
		[Parameter(Position=6,Mandatory=1)]$excludeByFile
	)

	Write-Host "Running tests"

	Exec { &$openCoverExe -target:$targetExe -targetargs:$targetArgs -output:$coveragePath -register:user -filter:$filter -excludebyattribute:$excludeByAttribute `
						  -excludebyfile:$excludeByFile -skipautoprops -mergebyhash -mergeoutput -hideskipped:All -returntargetcode }
}