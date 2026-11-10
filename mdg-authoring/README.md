# OFN Slovníky MDG authoring project

Open `Slovníky-MDG-authoring.qea` in Enterprise Architect. This is the **source model for the MDG**, not a model that uses the MDG. Its three profile packages contain:

- **UML Profile:** the ten stereotypes, their tagged value attributes and enumerations, metaclass extensions, and a `QuickLink` Document Artifact with the 14 endpoint rules.
- **Toolbox Profile:** the original **Slovníky** page and the separate **Datové sady** page.
- **Diagram Profile:** the **Slovníky** diagram type.

Each package contains one profile diagram named `Slovníky`. The name matters: the toolbox item references use the `Slovníky::` namespace. The package names distinguish the three areas in EA's Browser.

## Edit and generate

1. Edit the profile elements and connectors in the `.qea` project. To change a tagged value, edit an attribute on its stereotype. Enumeration options are attributes on the `Enum_*` elements. To change Quick Linker rules, edit the linked document on the `QuickLink` artifact; `QuickLink.txt` is a text copy for reference.
2. Save the project. Run `export-profiles.ps1` in Windows PowerShell, or save each of the three `Slovníky` diagrams as a UML Profile in EA. This writes `exports/uml-profile.xml`, `exports/toolbox-profile.xml`, and `exports/diagram-profile.xml`.
3. In EA, choose **Specialize → Technologies → Publish Technology → Publish Technology**, create a new MTS file, and select the exported files on their respective wizard pages: UML Profile, Toolbox Profile, and Diagram Profile. Use technology ID `ofnVoc` and output a new MDG XML file.
4. Run `py mdg-authoring/finalize-mdg.py path\to\generated-mdg.xml` from the repository root. This replaces any wizard sample named `Template Name` with the actual model template and copies `slovníkyPattern.xml` beside the generated MDG. Install or register **that generated MDG** with its adjacent pattern file, then restart EA before using the Model Builder. Avoid keeping an older `ofnVoc` MDG registered at the same time.

If you regenerate from an MTS file, also replace its sample `<ModelTemplates>` entry with the following block inside `<MDG.Selections>` before running the EA wizard again:

```xml
<ModelTemplates>
  <Model name="Příkladový slovník z metodiky popisu dat"
         description="Ukázkový slovník pojmů a vztahů"
         location="slovníkyPattern.xml" default="yes"
         icon="34" isFramework="false"/>
</ModelTemplates>
```

The existing `../slovníkyMDG-datasets.xml` is the reference output. The project was checked by exporting all three profiles from EA. The MDG references `../slovníkyPattern.xml` as a model template. It contains the example vocabulary diagram and a second diagram with a dataset, a CSV file distribution, and an API service distribution. The dataset uses `standard` term collection and is linked to the existing `Řidič` and `Řidičský průkaz` terms through the stereotyped `týká se pojmu` association. Both example associations have the three classification values needed for `sdílí_údaj`. Its `adresa LKD` package tag is intentionally empty; fill it with an absolute HTTPS IRI before converting a model created from the template. The `example.org` distribution URLs, ISVS code `1234`, and CC BY terms of use are illustrative values; replace them with values appropriate to the real dataset before publication. With a temporary HTTPS `adresa LKD` supplied, the converter produces the dataset and both distributions without missing required fields.

`build-project.ps1` reconstructs a fresh authoring project from the reference MDG using the installed EA automation interface. It refuses to overwrite a project that already contains profile packages, so edits made in EA remain safe.
