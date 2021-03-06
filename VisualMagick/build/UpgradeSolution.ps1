function CheckExitCode($msg)
{
	if ($LastExitCode -ne 0)
	{
		Write-Error $msg
		Exit 1
	}
}

function CreateTargetName2010($xml, $configuration)
{
  $uri = "http://schemas.microsoft.com/developer/msbuild/2003"

  [System.Xml.XmlNamespaceManager] $nsmgr = $xml.NameTable
  $nsmgr.AddNamespace("msb", $uri)

  $propertyGroup = $xml.SelectSingleNode("//msb:PropertyGroup[msb:OutDir]", $nsmgr)
  if ($propertyGroup -eq $null)
  {
    return
  }

  $targetName = $propertyGroup.SelectSingleNode("msb:TargetName[contains(@Condition, '$configuration')]", $nsmgr)
  if ($targetName -ne $null)
  {
    return
  }

  $outDir = $propertyGroup.SelectSingleNode("msb:OutDir[contains(@Condition, '$configuration')]", $nsmgr)
  if ($outDir -eq $null)
  {
    return
  }

  $outputFile = $xml.SelectSingleNode("//msb:ItemDefinitionGroup[contains(@Condition, '$configuration')]//msb:OutputFile", $nsmgr)
  if ($outputFile -eq $null)
  {
    return
  }

  $i = $outputFile.InnerText.LastIndexOf("\") + 1
  $j = $outputFile.InnerText.LastIndexOf(".")
  $name = $outputFile.InnerText.SubString($i, $j-$i)

  $targetName = $xml.CreateElement("TargetName", $uri)
  $targetName.InnerText = $name

  [void]$targetName.Attributes.Append($xml.CreateAttribute("Condition"))
  $targetName."Condition" = $outDir."Condition"

  [void]$propertyGroup.AppendChild($targetName)

  [void]$outputFile.ParentNode.RemoveChild($outputFile)
}

function CreateTargetName2012($xml, $configuration)
{
  $uri = "http://schemas.microsoft.com/developer/msbuild/2003"

  [System.Xml.XmlNamespaceManager] $nsmgr = $xml.NameTable;
  $nsmgr.AddNamespace("msb", $uri);

  $propertyGroup = $xml.SelectSingleNode("//msb:PropertyGroup[contains(@Condition, '$configuration') and msb:OutDir]", $nsmgr)
  if ($propertyGroup -eq $null)
  {
    return
  }

  $targetName = $propertyGroup.SelectSingleNode("msb:TargetName", $nsmgr)
  if ($targetName -ne $null)
  {
    return;
  }

  $outputFile = $xml.SelectSingleNode("//msb:ItemDefinitionGroup[contains(@Condition, '$configuration')]//msb:OutputFile", $nsmgr)
  if ($outputFile -eq $null)
  {
    return
  }

  $i = $outputFile.InnerText.LastIndexOf("\") + 1
  $j = $outputFile.InnerText.LastIndexOf(".")
  $name = $outputFile.InnerText.SubString($i, $j-$i)

  $targetName = $xml.CreateElement("TargetName", $uri)
  $targetName.InnerText = $name
  [void]$propertyGroup.AppendChild($targetName)

  [void]$outputFile.ParentNode.RemoveChild($outputFile)
}

function EnableMultiProcessorCompilation($xml)
{
  $uri = "http://schemas.microsoft.com/developer/msbuild/2003"

  [System.Xml.XmlNamespaceManager] $nsmgr = $xml.NameTable
  $nsmgr.AddNamespace("msb", $uri)

  $clCompiles = $xml.SelectNodes("//msb:ClCompile", $nsmgr)
  foreach ($clCompile in $clCompiles)
  {
    $multiProcessorCompilation = $clCompile.SelectSingleNode("msb:MultiProcessorCompilation", $nsmgr)
    if ($multiProcessorCompilation -ne $null)
    {
      continue
    }

    $multiProcessorCompilation = $xml.CreateElement("MultiProcessorCompilation", $uri)
    $multiProcessorCompilation.InnerText = "true"
    [void]$clCompile.AppendChild($multiProcessorCompilation)
  }
}

function FixProjectFile($fileName, $version)
{
  Write-Host "Fixing: $fileName"

  $xml = [xml](get-content $fileName)
  if ($version -eq 2010)
  {
    CreateTargetName2010 $xml "Debug"
    CreateTargetName2010 $xml "Release"
  }
  else
  {
    CreateTargetName2012 $xml "Debug"
    CreateTargetName2012 $xml "Release"
  }
  EnableMultiProcessorCompilation $xml
  $xml.Save($fileName)
}

function FixProjectFiles($version)
{
  foreach ($fileName in [IO.Directory]::GetFiles(".", "*.vcxproj", [IO.SearchOption]::AllDirectories))
  {
    FixProjectFile $fileName $version
  }
}

function UpgradeSolution($fileName)
{
  Write-Host "Upgrading solution: $fileName"
  devenv /upgrade $fileName
  CheckExitCode "Upgrade failed."
}

function UpgradeSolutions()
{
  foreach ($fileName in [IO.Directory]::GetFiles(".", "*.sln"))
  {
    UpgradeSolution $fileName
  }
}

UpgradeSolutions
FixProjectFiles $args[0]
