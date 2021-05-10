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
		[Parameter(Position=2,Mandatory=1)]$testResultDirectory
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

	$testAssembliesPaths = $projects | ForEach-Object {$_.FullName + "\" + $_.Name + ".dll"}

	$testAssemblies = [string]::Join(" ", $testAssembliesPaths)

	return $testAssemblies
}