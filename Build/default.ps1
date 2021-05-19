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
	$publishedApplicationDirectory = "$temporaryOutputDirectory\_PublishedApplications"
	$publishedWebsitesDirectory = "$temporaryOutputDirectory\_PublishedWebsites"
	$publishedLibrariesDirectory = "$temporaryOutputDirectory\_PublishedLibraries"

	$testResultDirectory = "$outputDirectory\TestResults"
	$NUnitTestResultDirectory = "$testResultDirectory\NUnit"
	$xUnitTestResultDirectory = "$testResultDirectory\xUnit"
	$MSTestTestResultDirectory = "$testResultDirectory\MSTest"

	$testCoverageDirectory = "$outputDirectory\TestCoverage"
	$testCoverageReportPath = "$testCoverageDirectory\OpenCover.xml"
	$testCoverageFilter = "+[*]* -[xunit.*]* -[*.NUnitTests]* -[*.Tests]* -[*.xUnitTests]*"
	$testCoverageExcludeByAttribute = "System.Diagnostics.CodeAnalysis.ExcludeFromCodeCoverageAttribute"
	$testCoverageExcludeByFile = "*\*Designer.cs;*\*.g.cs;*\*.g.i.cs"

	$packagesOutputDirectory = "$outputDirectory\Packages"
	$applicationsOutputDirectory = "$packagesOutputDirectory\Applications"
	$librariesOutputDirectory = "$packagesOutputDirectory\Libraries"

	$buildConfiguration = "Release"
	$buildPlatform = "Any CPU"

	$packagePath = "$solutionDirectory\packages"
	$NUnitExe = (Find-PackagePath $packagePath "NUnit.Runners") + "\Tools\nunit-console-x86.exe"
	$xUnitExe = (Find-PackagePath $packagePath "xUnit.Runner.Console") + "\Tools\xunit-console.exe"
	$vsTestExe = (Get-ChildItem ("C:\Program Files (x86)\Microsoft Visual Studio*\Common7\IDE\CommonExtenstions\Microsoft\TestWindow\vstest.console.exe")).FullName | 
	Sort-Object $_ | select -last 1
	$openCoverExe = (Find-PackagePath $packagePath "OpenCover") + "\Tools\OpenCover.Console.exe"
	$reportGeneratorExe = (Find-PackagePath $packagePath "ReportGenerator") + "\Tools\ReportGenerator.exe"
	$7ZipExe = (Find-PackagePath $packagePath "7-Zip.CommandLine") + "\Tools\7za.exe"
	$nugetExe = (Find-PackagePath $packagePath "NuGet.CommandLine") + "\Tools\NuGet.exe"
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
	Assert (Test-Path $openCoverExe) "OpenCover Console could not be found"
	Assert (Test-Path $reportGeneratorExe) "ReportGenerator Console could not be found"
	Assert (Test-Path $7ZipExe) "7-Zip Command Line could not be found"
	Assert (Test-Path $nugetExe) "NuGet Command Line could not be found"

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

	Exec { msbuild $SolutionFile "/p:Configuration=$buildConfiguration;Platform=$buildPlatform;OutDir=$temporaryOutputDirectory;NuGetExePath=$nugetExe" }
}

task TestNUnit `
	-depends Compile `
	-description "Run NUnit tests" ` 
	-precondition { return Test-Path $publishedNUnitTestsDirectory} `
{
	$testAssemblies = Prepare-Tests -testRunnerName "NUnit" `
									-publishedTestsDirectory $publishedNUnitTestsDirectory `
								    -testResultsDirectory $NUnitTestResultDirectory `
									-testCoverageDirectory $testCoverageDirectory

	#Exec { &$NUnitExe $testAssemblies /xml:$NUnitTestResultDirectory\NUnit.xml /nologo /noshadow }
	$targetArgs = "$testAssemblies /xml:`"`"$NUnitTestResultDirectory\NUnit.xml`"`" /nologo /noshadow"

	Run-Tests -openCover $openCOverExe -targetExe $nunitExe -targetArgs $targetArgs -coveragePath $testCoverageReportPath -filter $testCoverageFilter `
			  -excludeByAttribute $testCoverageExcludeByAttribute -excludeByFile $testCoverageExcludeByFile
}

task TestXUnit `
	-depends Compile `
	-description "Run NUnit tests"` 
	-precondition { return Test-Path $publishedxUnitTestsDirectory} `
{
	$testAssemblies = Prepare-Tests -testRunnerName "xUnit" `
									-publishedTestsDirectory $publishedxUnitTestsDirectory `
								    -testResultsDirectory $xUnitTestResultDirectory `
									-testCoverageDirectory $testCoverageDirectory

	#Exec { &$xUnitExe $testAssemblies -xml $xUnitTestResultDirectory\xUnit.xml -nologo -noshadow }
	$targetArgs = "$testAssemblies -xml`"`"$xUnitTestResultDirectory\xUnit.xml`"`" -nologo -noshadow"

	Run-Tests -openCover $openCOverExe -targetExe $xunitExe -targetArgs $targetArgs -coveragePath $testCoverageReportPath -filter $testCoverageFilter `
			  -excludeByAttribute $testCoverageExcludeByAttribute -excludeByFile $testCoverageExcludeByFile
}

task TestMSTest `
	-depends Compile `
	-description "Run NUnit tests"` 
	-precondition { return Test-Path $publishedMSTestTestsDirectory} `
{
	$testAssemblies = Prepare-Tests -testRunnerName "MSTest" `
									-publishedTestsDirectory $publishedMSTestTestsDirectory `
								    -testResultsDirectory $MSTestTestResultDirectory `
									-testCoverageDirectory $testCoverageDirectory

	#vstest console doesn't have any option to change the output directory so we need to change working directory
	Push-Location $MSTestTestResultDirectory
	#Exec { &$vsTestExe $testAssemblies /Logger:trx }

	$targetArgs = "$testAssemblies /Logger:trx"

	Run-Tests -openCover $openCOverExe -targetExe $vsTestExe -targetArgs $targetArgs -coveragePath $testCoverageReportPath -filter $testCoverageFilter `
			  -excludeByAttribute $testCoverageExcludeByAttribute -excludeByFile $testCoverageExcludeByFile
}

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

task Test -depends Compile, Clean -description "Run unit tests" 
{ 
	if (Test-Path $testCoverageReportPath)
	{
		# Generate HTML test coverage report
		Write-Host "`r`nGenerating HTML test coverage report"
		Exec { &$reportGeneratorExe $testCoverageReportPath $testCoverageDirectory }

		Write-Host "Parsing OpenCover results"

		# Load the coverage report as XML
		$coverage = [xml](Get-Content -Path $testCoverageReportPath)

		$coverageSummary = $coverage.CoverageSession.Summary

		#Write class coverage
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsCCovered' value='$($coverageSummary.visitedClasses)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsCTotal' value='$($coverageSummary.numClasses)']"
		Write-Host ("##teamcity[buildStatisticValue key='CodeCoverageC' value='{0:N2}']" -f(($coverageSummary.visitedClasses / $coverageSummary.numClasses)*100))

		#Report method coverage
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsMCovered' value='$($coverageSummary.visitedMethods)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsMTotal' value='$($coverageSummary.numMethods)']"
		Write-Host ("##teamcity[buildStatisticValue key='CodeCoverageM' value='{0:N2}']" -f(($coverageSummary.visitedMethods / $coverageSummary.numMethods)*100))

		#Report branch coverage
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsBCovered' value='$($coverageSummary.visitedBranchPoints)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsBTotal' value='$($coverageSummary.numBranchPoints)']"
		Write-Host ("##teamcity[buildStatisticValue key='CodeCoverageB' value='{0:N2}']" -f(($coverageSummary.visitedBranchPoints / $coverageSummary.numBranchPoints)*100))

		#Report statement coverage
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsSCovered' value='$($coverageSummary.visitedSequencePoints)']"
		Write-Host "##teamcity[buildStatisticValue key='CodeCoverageAbsSTotal' value='$($coverageSummary.numSequenecePoints)']"
		Write-Host ("##teamcity[buildStatisticValue key='CodeCoverageS' value='$($coverageSummary.sequenceCoverage)']"
	}
	else 
	{
		Write-Host "No coverage file found at: $testCoverageReportPath"
	}
}

task Package `
	-depends Compile, Test `
	-description "Package applications" `
	-requiredVariables publishedWebsitesDirectory, publishedApplicationsDirectory, applicationsOutputDirectory, publishedLibrariesDirectory, librariesOutputDirectory ` 
{
	#Merge published websites and published applications paths
	$applications = @(Get-ChildItem $publishedWebsitesDirectory) + @(Get-ChildItem $publishedApplicationsDirectory)

	if ($applications.Length -gt 0 -and !(Test-Path $applicationsOutputDirectory))
	{
		New-Item $applicationsOutputDirectory -ItemType Directory | Out-Null
	}

	foreach($application in $applications) 
	{
		$nuspecPath = $application.FullName + "\" + $application.Name + ".nuspec"

		Write-Host "Looking for nuspec file at $nuspecPath"

		if (Test-Path $nuspecPath) 
		{
			Write-Host "Packing $($application.Name) azs NuGet package"
			
			#Load the nuspec file as XML
			$nuspec = [xml](Get-Content -Path $nuspecPath)
			$metadata = $nuspec.package.metadata

			#Edit the metadata
			$metadata.version = $metadata.version.Replace("[buildNumber]", $buildNumber)
			if (!$isMainBranch) 
			{
				$metadata.version = $metadata.version + "-$branchName"
			}

			$metadata.releaseNotes = "Build Nubmer: $buildNumber`r`nBranch Name: $brnachName`r`nCommit Hash: $gitCommitHash"

			# Save the nuspec file
			$nuspec.Save((Get-Item $nuspecPath))

			#package as NuGet package
			Exec { &$nugetExe pack $nuspecPath -OutputDirectory $applicationOutputDirectory }
		}
		else 
		{
			Write-Host "Packaging $($application.Name) as a zip file"

			$archivePath = "$($applicationsOutputDirectory)\$($application.Name).zip"
			$inputDirectory = "$($application.FullName)\*"

			Exec { &$7ZipExe a -r -mx3 $archivePath $inputDirectory }
		}

		# Moving NuGet libraries to the package directory
		if (Test-Path $publishedLibrariesDirectory)
		{
			if (!(Test-Path $librariesOutputDirectory))
			{
				Mkdir $librariesOutputDirectory | Out-Null

				Get-ChildItem -Path $publishedLibrariesDirectory -Filter "*.nupkg" -Recurse | Move-Item -Destination $librariesOutputDirectory
			}
		}
	}
}

task Clean `
	-depends Compile, Test, Package `
	-description "Remove temporary files" `
	-requiredVariables temporaryOutputDirectory
{ 
	if (Test-Path $temporaryOutputDirectory)
	{
		Write-Host "Removing temporary output directory located at $temporaryOutputDirectory"

		Remove-Item $temporaryOutputDirectory -Force -Recurse
	}
}