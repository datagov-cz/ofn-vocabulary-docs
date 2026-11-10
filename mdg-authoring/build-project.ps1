param(
    [string]$ProjectPath = (Join-Path $PSScriptRoot 'Slovníky-MDG-authoring.qea')
)

$ErrorActionPreference = 'Stop'
$mdgPath = Join-Path $PSScriptRoot '..\slovníkyMDG-datasets.xml'
$basePath = 'C:\Program Files\Sparx Systems\EA\EABase.qea'

if (-not (Test-Path $ProjectPath)) {
    Copy-Item $basePath $ProjectPath
    (Get-Item $ProjectPath).IsReadOnly = $false
}

[xml]$mdg = Get-Content -Raw -Encoding UTF8 $mdgPath
$repo = New-Object -ComObject EA.Repository

function Save-EA($item, $label) {
    if (-not $item.Update()) { throw "Could not save $label : $($item.GetLastError())" }
}

function Add-Package($parent, $name, $description) {
    $package = $parent.Packages.AddNew($name, 'Package')
    $package.Notes = $description
    Save-EA $package "package $name"
    $package.Element.Stereotype = 'profile'
    Save-EA $package.Element "profile marker $name"
    $parent.Packages.Refresh()
    return $package
}

function Add-Diagram($package, $name, $description) {
    $diagram = $package.Diagrams.AddNew($name, 'Logical')
    $diagram.Notes = "Alias=Slovníky;Notes=$description;"
    Save-EA $diagram "diagram $name"
    $package.Diagrams.Refresh()
    return $diagram
}

function Add-Element($package, $diagram, $name, $stereotype, $alias, $notes, $x, $y) {
    $element = $package.Elements.AddNew($name, 'Class')
    $element.Stereotype = $stereotype
    if ($alias) { $element.Alias = $alias }
    if ($notes) { $element.Notes = $notes }
    Save-EA $element "element $name"
    $package.Elements.Refresh()
    $position = "l=$x;r=$($x+220);t=$y;b=$($y+130);"
    $shape = $diagram.DiagramObjects.AddNew($position, '')
    $shape.ElementID = $element.ElementID
    Save-EA $shape "diagram object $name"
    $diagram.DiagramObjects.Refresh()
    return $element
}

function Add-Attribute($element, $name, $type, $default, $description, $classifierId = 0) {
    $attribute = $element.Attributes.AddNew($name, $type)
    if ($null -ne $default) { $attribute.Default = [string]$default }
    if ($description) { $attribute.Notes = $description }
    if ($classifierId) { $attribute.ClassifierID = [string]$classifierId }
    Save-EA $attribute "attribute $name"
    $element.Attributes.Refresh()
}

function Add-Extension($diagram, $source, $target) {
    $connector = $source.Connectors.AddNew('', 'Extension')
    $connector.SupplierID = $target.ElementID
    Save-EA $connector "extension from $($source.Name) to $($target.Name)"
    $source.Connectors.Refresh()
    $link = $diagram.DiagramLinks.AddNew('', '')
    $link.ConnectorID = $connector.ConnectorID
    Save-EA $link 'extension diagram link'
    return $connector
}

function Get-Rtf($value) {
    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append('{\rtf1\ansi\deff0 ')
    foreach ($character in $value.ToCharArray()) {
        $code = [int][char]$character
        if ($character -eq "`n") { [void]$builder.Append('\par '); continue }
        if ($character -eq "`r") { continue }
        if ($character -in @('\', '{', '}')) { [void]$builder.Append('\') }
        if ($code -gt 127) {
            if ($code -gt 32767) { $code -= 65536 }
            [void]$builder.Append("\u$($code)?")
        } else {
            [void]$builder.Append($character)
        }
    }
    [void]$builder.Append('}')
    return $builder.ToString()
}

try {
    if (-not $repo.OpenFile((Resolve-Path $ProjectPath).Path)) {
        throw "Could not open $ProjectPath"
    }
    $repo.SuppressEADialogs = $true
    $root = $repo.Models.GetAt(0)
    if ($root.Packages.Count -ne 0) {
        throw 'The authoring project already contains profile packages. Use a fresh EABase.qea to rebuild it.'
    }
    $root.Name = 'OFN Slovníky MDG – authoring'
    Save-EA $root 'root model'

    $umlPackage = Add-Package $root 'Slovníky – UML Profile' 'Stereotypes and tagged values for the OFN Slovníky technology.'
    $toolboxPackage = Add-Package $root 'Slovníky – Toolbox Profile' 'The Slovníky and Datové sady toolbox pages.'
    $diagramPackage = Add-Package $root 'Slovníky – Diagram Profile' 'The Slovníky diagram type.'
    $umlDiagram = Add-Diagram $umlPackage 'Slovníky' 'Stereotypes, metaclasses, tagged values and QuickLink definitions.'
    $toolboxDiagram = Add-Diagram $toolboxPackage 'Slovníky' 'Two toolbox pages for the Slovníky diagram.'
    $diagramDiagram = Add-Diagram $diagramPackage 'Slovníky' 'The custom Slovníky diagram type.'

    $metaclasses = @{}
    $metaNames = @('Package', 'Class', 'Association')
    for ($i = 0; $i -lt $metaNames.Count; $i++) {
        $metaclasses[$metaNames[$i]] = Add-Element $umlPackage $umlDiagram $metaNames[$i] 'metaclass' '' '' 930 (50 + 210 * $i)
    }
    $directedAssociation = Add-Element $umlPackage $umlDiagram 'Association' 'metaclass' '' 'Directed association for typVztahu.' 930 690
    Add-Attribute $directedAssociation 'direction' 'String' 'Source -> Destination' ''

    $profileElements = @{}
    $enumerations = @{}
    $stereotypes = $mdg.SelectNodes('/MDG.Technology/UMLProfiles/UMLProfile/Content/Stereotypes/Stereotype')
    for ($i = 0; $i -lt $stereotypes.Count; $i++) {
        $definition = $stereotypes[$i]
        $x = 40 + 290 * ($i % 3)
        $y = 50 + 240 * [math]::Floor($i / 3)
        $element = Add-Element $umlPackage $umlDiagram $definition.GetAttribute('name') 'stereotype' $definition.GetAttribute('metatype') $definition.GetAttribute('notes') $x $y
        $profileElements[$definition.GetAttribute('name')] = $element
        $metatype = $definition.GetAttribute('metatype')
        if ($metatype) { Add-Attribute $element '_metatype' 'string' $metatype '' }
        $apply = $definition.SelectSingleNode('./AppliesTo/Apply')
        $baseType = $apply.GetAttribute('type')
        $targetMetaclass = if ($definition.GetAttribute('name') -eq 'typVztahu') { $directedAssociation } else { $metaclasses[$baseType] }
        Add-Extension $umlDiagram $element $targetMetaclass | Out-Null
        foreach ($tag in $definition.SelectNodes('./TaggedValues/Tag')) {
            $tagName = $tag.GetAttribute('name')
            $tagType = 'String'
            $classifierId = 0
            if ($tag.GetAttribute('type') -eq 'enumeration') {
                $values = $tag.GetAttribute('values')
                if (-not $enumerations.ContainsKey($values)) {
                    $enumName = 'Enum_' + ($enumerations.Count + 1)
                    $enum = Add-Element $umlPackage $umlDiagram $enumName 'enumeration' '' "Values: $values" 1270 (50 + 180 * $enumerations.Count)
                    $enum.Type = 'Enumeration'
                    Save-EA $enum "enumeration $enumName"
                    foreach ($option in $values.Split(',')) {
                        Add-Attribute $enum $option 'String' '' ''
                    }
                    $enumerations[$values] = $enum
                }
                $tagType = $enumerations[$values].Name
                $classifierId = $enumerations[$values].ElementID
            }
            Add-Attribute $element $tagName $tagType $tag.GetAttribute('default') $tag.GetAttribute('description') $classifierId
        }
    }

    $toolboxMetaclass = Add-Element $toolboxPackage $toolboxDiagram 'ToolboxPage' 'metaclass' '' '' 830 250
    $pages = $mdg.SelectNodes('/MDG.Technology/UIToolboxes/UMLProfile/Content/Stereotypes/Stereotype')
    for ($i = 0; $i -lt $pages.Count; $i++) {
        $pageDefinition = $pages[$i]
        $page = Add-Element $toolboxPackage $toolboxDiagram $pageDefinition.GetAttribute('name') 'stereotype' $pageDefinition.GetAttribute('alias') $pageDefinition.GetAttribute('notes') 60 (80 + 260 * $i)
        Add-Extension $toolboxDiagram $page $toolboxMetaclass | Out-Null
        foreach ($tag in $pageDefinition.SelectNodes('./TaggedValues/Tag')) {
            Add-Attribute $page $tag.GetAttribute('name') 'String' $tag.GetAttribute('default') $tag.GetAttribute('description')
        }
    }

    $diagramMetaclass = Add-Element $diagramPackage $diagramDiagram 'Diagram_Logical' 'metaclass' '' '' 550 120
    $diagramDefinition = $mdg.SelectSingleNode('/MDG.Technology/DiagramProfile/UMLProfile/Content/Stereotypes/Stereotype')
    $diagramStereo = Add-Element $diagramPackage $diagramDiagram $diagramDefinition.GetAttribute('name') 'stereotype' '' $diagramDefinition.GetAttribute('notes') 70 120
    Add-Extension $diagramDiagram $diagramStereo $diagramMetaclass | Out-Null
    foreach ($property in $diagramDefinition.SelectNodes('./AppliesTo/Apply/Property')) {
        Add-Attribute $diagramMetaclass $property.GetAttribute('name') 'String' $property.GetAttribute('value') ''
    }

    $quickLink = $mdg.SelectSingleNode('/MDG.Technology/UMLProfiles/UMLProfile/Content/QuickLink').GetAttribute('data')
    [System.IO.File]::WriteAllText((Join-Path $PSScriptRoot 'QuickLink.txt'), $quickLink, (New-Object System.Text.UTF8Encoding($false)))
    $rtfPath = Join-Path $env:TEMP 'slovniky-mdg-quicklink.rtf'
    [System.IO.File]::WriteAllText($rtfPath, (Get-Rtf $quickLink), [System.Text.Encoding]::ASCII)
    $artifact = $umlPackage.Elements.AddNew('QuickLink', 'Artifact')
    $artifact.Stereotype = 'document'
    Save-EA $artifact 'QuickLink artifact'
    $shape = $umlDiagram.DiagramObjects.AddNew('l=1270;r=1490;t=1300;b=1410;', '')
    $shape.ElementID = $artifact.ElementID
    Save-EA $shape 'QuickLink diagram object'
    if (-not $artifact.LoadLinkedDocument($rtfPath)) { throw 'Could not load QuickLink linked document.' }

    Save-EA $umlDiagram 'UML profile diagram'
    Save-EA $toolboxDiagram 'toolbox profile diagram'
    Save-EA $diagramDiagram 'diagram profile diagram'
    Write-Output "Created $ProjectPath with $($stereotypes.Count) stereotypes, $($pages.Count) toolbox pages and QuickLink rules."
} finally {
    try { $repo.CloseFile() } catch {}
    try { $repo.Exit() } catch {}
}
