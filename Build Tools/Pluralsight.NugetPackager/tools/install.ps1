param (
	$InstallPath,
	$ToolsPath,
	$Package,
	$Project
)

$rootnamespace = $Project.Properties.Item("RootNamespace").Value
$templateFileName = "template.nuspec"
$targetFileName = $rootnamespace + ".nuspec"

$templateFile = $Project.ProjectItem.Item($templateFileName)
$targetFile = $Project.ProjectItem.Item($targetFileName)

if ($targetFile)
{
	$templateFile.Delete()
}
else 
{
	$templateFile.Name = $targetFileName
	$templateFile.Proeperties.Item("BuildAction").Value = [int]2
}

$Project.Save()