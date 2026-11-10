$ErrorActionPreference = 'Stop'
$project = Join-Path $PSScriptRoot 'Slovníky-MDG-authoring.qea'
$exports = Join-Path $PSScriptRoot 'exports'
New-Item -ItemType Directory -Force $exports | Out-Null
$repo = New-Object -ComObject EA.Repository
try {
    if (-not $repo.OpenFile($project)) { throw "Could not open $project" }
    $profiles = @(
        @('Slovníky – UML Profile', 'uml-profile.xml'),
        @('Slovníky – Toolbox Profile', 'toolbox-profile.xml'),
        @('Slovníky – Diagram Profile', 'diagram-profile.xml')
    )
    $root = $repo.Models.GetAt(0)
    foreach ($entry in $profiles) {
        $package = $null
        foreach ($candidate in $root.Packages) {
            if ($candidate.Name -eq $entry[0]) { $package = $candidate; break }
        }
        if (-not $package) { throw "Missing package $($entry[0])" }
        $file = Join-Path $exports $entry[1]
        $diagram = $package.Diagrams.GetAt(0)
        if ($diagram.Name -ne 'Slovníky') {
            $diagram.Name = 'Slovníky'
            if (-not $diagram.Update()) { throw "Could not name profile diagram in $($entry[0])" }
        }
        $saved = $repo.SaveDiagramAsUMLProfile($diagram.DiagramGUID, $file)
        if (-not $saved) { throw "EA could not export $($entry[0]); save this profile manually once in EA." }
        Write-Output $file
    }
} finally {
    try { $repo.CloseFile() } catch {}
    try { $repo.Exit() } catch {}
}
