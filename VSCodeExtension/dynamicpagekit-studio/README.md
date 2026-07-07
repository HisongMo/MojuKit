# DynamicPageKit Studio for VS Code

Internal VS Code extension for editing DynamicPageKit page projects.

## Features

- Expandable page tree for `pages/*/index.dkml` page directories, with direct DKML/DKSS/JS/JSON/Compiled file entries.
- DKML, DKSS, controlled JS DSL, and JSON editing support.
- Completion and basic TextMate highlighting for DKML/DKSS/DynamicPage JS.
- Formatting through `DynamicPageKitCLI`.
- Problems diagnostics from the shared Swift `DynamicPageKitCore` compiler.
- Local preview server compatible with the existing iOS MojuKitPreview:
  - `GET /active-page.json`
  - `GET /events`
  - `GET /manifest.json`
  - `GET /page/{target}.json`
- iPhone Simulator launch flow for the existing `MojuKit` target with `--dynamicpage-preview-host`.

## Local Development

Open this folder in VS Code and run the extension host.

This repository includes `out/extension.js`, so the extension can be loaded without running TypeScript compilation first. Validate the runtime entrypoint with:

```bash
npm run compile
```

## Settings

- `dynamicPageKit.hostProjectPath`: path to the `MojuKitPreview` project containing `Package.swift` and `MojuKitPreview.xcodeproj`.
- `dynamicPageKit.previewPort`: local preview server port, default `8088`.

## Commands

- `DynamicPageKit: Refresh Pages`
- `DynamicPageKit: Open Page`
- `DynamicPageKit: New Page`
- `DynamicPageKit: Delete Page`
- `DynamicPageKit: Import JSON`
- `DynamicPageKit: Save and Compile`
- `DynamicPageKit: Start Preview`
- `DynamicPageKit: Restart Host`
- `DynamicPageKit: Refresh Active Page`
