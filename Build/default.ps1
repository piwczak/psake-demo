properties {
	$testMessage = 'Executed Test!'
	$cleanMessage = 'Executed Clean!'

	$solutionDirectory = (Get-Item $solutionFile).DirectoryName
	$outputDirectory= "$solutionDirectory\.build"
	$temporaryOutputDirectory = "$outputDirectory\temp"

	$buildConfiguration = "Release"
	$buildPlatform = "Any CPU"
}

task default -depends Test

FormatTaskName "`r`n`r`n-------- Executing {0} Task --------"

task Init `
	-description "Initialises the build by removing previous artifacts and creating output directories" `
	-requiredVariables outputDirectory, temporaryOutputDirectory `
{
	Assert ("Debug", "Release" -contains $buildConfiguration) `
		   "Invalid build configuration '$buildConfiguration'. Valid values are 'Debug' or 'Release'"

	Assert ("x86", "x64", "Any CPU" -contains $buildPlatform) `
		   "Invalid build platform '$buildPlatform'. Valid values are 'x86', 'x64' or 'Any CPU'"

	# Remove previous build results
	if (Test-Path $outputDirectory) 
	{
		Write-Host "Removing output directory located at $outputDirectory"
		Remove-Item $outputDirectory -Force -Recurse
	}

	Write-Host "Creating output directory located at $outputDirectory"
	New-Item $outputDirectory -ItemType Directory | Out-Null

	Write-Host "Creating temporary output directory located at $temporaryOutputDirectory" 
	New-Item $temporaryOutputDirectory -ItemType Directory | Out-Null
}
 
task Compile `
	-depends Init `
	-description "Compile the code" `
	-requiredVariables solutionFile, buildConfiguration, buildPlatform, temporaryOutputDirectory `
{ 
	Write-Host "Building solution $solutionFile"
	#msbuild $SolutionFile "/p:Configuration=$buildConfiguration;Platform=$buildPlatform;OutDir=$temporaryOutputDirectory"

	Exec { msbuild $SolutionFile "/p:Configuration=$buildConfiguration;Platform=$buildPlatform;OutDir=$temporaryOutputDirectory" }
}

task Test -depends Compile, Clean -description "Run unit tests" { 
  Write-Host $testMessage
}

task Clean -description "Remove temporary files" { 
  Write-Host $cleanMessage
}