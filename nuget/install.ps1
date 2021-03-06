param($installPath, $toolsPath, $package, $project)
# based on Excel-DNA install script
Write-Host "Starting ExcelDnaDoc install script"

$projName = $project.Name
$isFSharp = ($project.Type -eq "F#")
# Look for and rename old .dna file
$newDnaFile = $project.ProjectItems | Where-Object { $_.Name -eq "ExcelDnaDoc-Template.dna" }
$newDnaFileName = "${projName}-AddIn.dna"
$oldDnaFile = $project.ProjectItems | Where-Object { $_.Name -eq $newDnaFileName }

if ($null -ne $oldDnaFile)
{
	# found prior template installed with Excel-DNA
	$newDnaFile.Delete()
	$oldDnaFilePath = $oldDnaFile.Properties.Item("FullPath").Value

	# add reference to ExcelDna.Documentation
	[xml]$xmlDoc = Get-Content $oldDnaFilePath

	#check if reference already exists
	$refExists = "false"
	foreach($ref in $xmlDoc.DnaLibrary.Reference) 
	{  
		if ($ref."Path" -eq "ExcelDna.Documentation.dll")
		{
			$refExists = "true"
		}
	}

	if ($refExists -eq "false")
	{
		$xmlElt = $xmlDoc.CreateElement("Reference")
		$xmlAtt = $xmlDoc.CreateAttribute("Path")
		$xmlAtt.Value = "ExcelDna.Documentation.dll"
		$xmlElt.Attributes.Append($xmlAtt)
		$xmlAtt = $xmlDoc.CreateAttribute("Pack")
		$xmlAtt.Value = "true"
		$xmlElt.Attributes.Append($xmlAtt)
		$xmlDoc.LastChild.AppendChild($xmlElt)
	}

	$xmlDoc.Save($oldDnaFilePath)
}
else
{
	# We don't have a file already so create dna template for ExcelDnaDoc
	Write-Host "`tCreating -AddIn.dna file"
		
	# Rename and fill in ExcelDnaDoc-Template.dna file.
	#Write-Host $newDnaFile.Name 
	#Write-Host $newDnaFileName
	$newDnaFile.Name = $newDnaFileName
	if ($isFSharp)
	{
		$newDnaFile.Properties.Item("BuildAction").Value = ([Microsoft.VisualStudio.FSharp.ProjectSystem.BuildAction]::Content)
	}
	else
	{
		$newDnaFile.Properties.Item("BuildAction").Value = 2 # Content
	}    
	$newDnaFile.Properties.Item("CopyToOutputDirectory").Value = 2 # Copy If Newer

	# These replacements match strings in the content\ExcelDnaDoc-Template.dna file
	$dnaFullPath = $newDnaFile.Properties.Item("FullPath").Value
	$outputFileName = $project.Properties.Item("OutputFileName").Value
	(get-content $dnaFullPath) | foreach-object {$_ -replace "%OutputFileName%", $outputFileName } | set-content $dnaFullPath
	(get-content $dnaFullPath) | foreach-object {$_ -replace "%ProjectName%"   , $projName       } | set-content $dnaFullPath
}

# initialize settings for razor templates
$templateNames = "TableOfContentsTemplate.cshtml", "ProjectFileTemplate.cshtml", "MethodListTemplate.cshtml", "helpstyle.css",
				 "FunctionTemplate.cshtml", "CommandTemplate.cshtml", "CommandListTemplate.cshtml", "CategoryTemplate.cshtml"

$helpContentFolder =  $project.ProjectItems | Where-Object { $_.Name -eq "HelpContent" }
$templateFiles = $helpContentFolder.ProjectItems | Where-Object { $templateNames -contains $_.Name}

$webConfigFile = $helpContentFolder.ProjectItems | Where-Object { $_.Name -eq "web.config.txt" }
$webConfigFile.Name = "web.config"

foreach($file in $templateFiles)
{
	$file.Properties.Item("CopyToOutputDirectory").Value = 2 # Copy If Newer
}

Write-Host "`tAdding post-build commands"
# We'd actually like to put $(ProjectDir)tools\Excel-DNA.0.30.0\tools\ExcelDna.xll
$fullPath = $project.Properties.Item("FullPath").Value
# Write-host $fullPath
# Write-host $toolsPath
$escapedSearch = [regex]::Escape($project.Properties.Item("FullPath").Value)
$toolMacro = $toolsPath -replace $escapedSearch, "`$(ProjectDir)"
$postBuild = "`"${toolMacro}\ExcelDnaDoc.exe`" `"`$(TargetDir)${projName}-AddIn.dna`" /Y"
$prop = $project.Properties.Item("PostBuildEvent")
if ($prop.Value -eq "") {
	$prop.Value = $postBuild
} 
else 
{
	$prop.Value += "`r`n$postBuild"
}

Write-Host "Completed ExcelDnaDoc install script"
