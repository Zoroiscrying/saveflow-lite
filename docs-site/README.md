# SaveFlow Lite Docs Site

This folder is the public English documentation-site source for SaveFlow Lite.

The site uses Docusaurus because the current target is a GitHub-hosted docs
site with a conventional docs sidebar, version-friendly structure, and static
build output.

## Requirements

- Node.js 20 or newer
- npm

The workspace currently does not vendor `node_modules`.

`package.json` pins `webpack` to `5.95.0`.
This avoids a Docusaurus 3.10 / `webpackbar` compatibility issue observed with
newer Webpack 5 releases during production builds.

## Local Preview

```powershell
cd docs-site
npm install
npm run start
```

The local server normally opens at `http://localhost:3000`.

When adding or removing docs files, restart the dev server so Docusaurus reloads
the sidebar and route table.

For the most release-like preview, build and serve the static output:

```powershell
cd docs-site
npm run build
npm run serve
```

## Production Build

```powershell
cd docs-site
npm install
npm run build
```

The static output is generated into `docs-site/build`.

## GitHub Pages

The public `saveflow-lite` repository receives this folder through release sync.
It also receives `.github/workflows/deploy-saveflow-lite-docs.yml`, which builds
this site with Node 20 and deploys it with GitHub Pages Actions.

The workflow is guarded so it only deploys from `Zoroiscrying/saveflow-lite`,
not from the multi-plugin development workspace.

## Documentation Boundary

Public user docs belong here or in `addons/saveflow_lite/docs` while they are
being migrated.

Internal planning docs should not be linked from the public docs site.

The public `saveflow-lite` repository sync includes this folder, but Godot Asset
Library archive downloads remain limited to `addons/` by `.gitattributes`.

## Static Images

Public docs images live under `static/img/saveflow`.

Use stable paths from markdown:

```md
![Short descriptive alt text](/img/saveflow/example.svg)
```

Keep screenshot capture checklists outside published docs pages.

## Code Blocks

Always add a language to fenced code blocks so Docusaurus can load the right
Prism grammar and show the language badge:

````md
```gdscript
SaveFlow.save_scope("slot_1", room_scope, metadata)
```
````

Use `gdscript`, `csharp`, `powershell`, `text`, or `md` for the current docs.
