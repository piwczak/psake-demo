Include ".\helpers.ps1"

properties {
	$testMessage = 'Executed Test!'
	$cleanMessage = 'Executed Clean!'

	$solutionDirectory = (Get-Item $solutionFile).DirectoryName
	$outputDirectory= "$solutionDirectory\.build"
	$temporaryOutputDirectory = "$outputDirectory\temp"

	$publishedNUnitTestsDirectory = "$temporaryOutputDirectory\_PublishedNUnitTests"
	$publishedxUnitTestsDirectory = "$temporaryOutputDirectory\_PublishedxUnitTests"
	$publishedMSTestTestsDirectory = "$temporaryOutputDirectory\_PublishedMSTestTests"

	$testResultDirectory = "$outputDirectory\TestResults"
	$NUnitTestResultDirectory = "$testResultDirectory\NUnit"
	$xUnitTestResultDirectory = "$testResultDirectory\xUnit"
	$MSTestTestResultDirectory = "$testResultDirectory\MSTest"

	$buildConfiguration = "Release"
	$buildPlatform = "Any CPU"

	$packagePath = "$solutionDirectory\packages"
	$NUnitExe = (Find-PackagePath $packagePath "NUnit.Runners") + "\Tools\nunit-console-x86.exe"
	$xUnitExe = (Find-PackagePath $packagePath "xUnit.Runner.Console") + "\Tools\xunit-console.exe"
	$vsTestExe = (Get-ChildItem ("C:\Program Files (x86)\Microsoft Visual Studio*\Common7\IDE\CommonExtenstions\Microsoft\TestWindow\vstest.console.exe")).FullName | 
	Sort-Object $_ | select -last 1
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

	Write-Host "Checking that all required tools are available"

	#Check that all tools are available
	Assert (Test-Path $NUnitExe) "NUnit Console could not be found"
	Assert (Test-Path $xUnitExe) "xUnit Console could not be found"
	Assert (Test-Path $vsTestExe) "VSTest Console could not be found"

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

task TestNUnit `
	-depends Compile `
	-description "Run NUnit tests" ` 
	-precondition { return Test-Path $publishedNUnitTestsDirectory} `
{
	$testAssemblies = Prepare-Tests -testRunnerName "NUnit" `
									-publishedTestsDirectory $publishedNUnitTestsDirectory `
								    -testResultsDirectory $NUnitTestResultDirectory

	Exec { &$NUnitExe $testAssemblies /xml:$NUnitTestResultDirectory\NUnit.xml /nologo /noshadow }
}

task TestXUnit `
	-depends Compile `
	-description "Run NUnit tests"` 
	-precondition { return Test-Path $publishedxUnitTestsDirectory} `
{
	$testAssemblies = Prepare-Tests -testRunnerName "xUnit" `
									-publishedTestsDirectory $publishedxUnitTestsDirectory `
								    -testResultsDirectory $xUnitTestResultDirectory

	Exec { &$xUnitExe $testAssemblies -xml $NUnitTestResultDirectory\xUnit.xml -nologo -noshadow }
}

task TestMSTest `
	-depends Compile `
	-description "Run NUnit tests"` 
	-precondition { return Test-Path $publishedMSTestTestsDirectory} `
{
	$testAssemblies = Prepare-Tests -testRunnerName "MSTest" `
									-publishedTestsDirectory $publishedMSTestTestsDirectory `
								    -testResultsDirectory $MSTestTestResultDirectory

	#vstest console doesn't have any option to change the output directory so we need to change working directory
	Push-Location $MSTestTestResultDirectory
	Exec { &$vsTestExe $testAssemblies /Logger:trx }
	Pop-Location 

	#move the .trc file back to $MSTestTestResultDirectory
	Move-Item -path $MSTestTestResultDirectory\TestResults\*.trx -Destination $MSTestTestResultDirectory\MSTest.trx

	Remove-Item $MSTestTestResultDirectory\TestResults
}

task Test `
	-depends Compile, TestNUnit, TestXUnit, TestMSTest `
	-description "Run unit tests"` 
{

}

task Test -depends Compile, Clean -description "Run unit tests" { 
  Write-Host $testMessage
}

task Clean -description "Remove temporary files" { 
  Write-Host $cleanMessage
}