# Figma MCP setup, node parsing, concept mapping, package scaffold, assets

Supporting detail for `supy-figma-implement-design`'s Steps 0, 1, 2, 4, and "Default package
location." Read the parent `SKILL.md` first — this file is reference material, not a standalone
procedure.

## Step 0 — Set up Figma MCP (if not already configured)

If any Figma MCP call fails because the server is not connected, pause and guide the user through
setup for their AI tool.

**Figma MCP server URL:** `https://mcp.figma.com/mcp`

Setup varies by tool:

- **Claude Code**: `claude mcp add figma --url https://mcp.figma.com/mcp`
- **Cursor**: add to `.cursor/mcp.json` with url `https://mcp.figma.com/mcp`
- **OpenAI Codex**: `codex mcp add figma --url https://mcp.figma.com/mcp`
- **Gemini CLI**: configure in Gemini's MCP settings

After setup, the user may need to authenticate via OAuth and restart their tool.

## Node ID parsing

**URL format:** `https://figma.com/design/:fileKey/:fileName?node-id=1-2`

- **File key** — the segment after `/design/`.
- **Node ID** — the value of the `node-id` query parameter.

**Example:**

- URL: `https://figma.com/design/kL9xQn2VwM8pYrTb4ZcHjF/DesignSystem?node-id=42-15`
- File key: `kL9xQn2VwM8pYrTb4ZcHjF`
- Node ID: `42-15`

**Note:** with the `figma-desktop` MCP, `fileKey` is not needed — the server uses the currently
open file automatically, so only `nodeId` is required.

## Figma → Flutter concept mapping

| Figma concept | Flutter equivalent |
| --- | --- |
| Auto Layout (vertical) | `Column` |
| Auto Layout (horizontal) | `Row` |
| No Auto Layout | `Stack` or `SizedBox` with positioned children |
| Fill Container (main axis) | `Expanded` child |
| Fill Container (cross axis) | `CrossAxisAlignment.stretch` |
| Hug Contents | `MainAxisSize.min` |
| Fixed width/height | `SizedBox(width: ..., height: ...)` |
| Padding | `Padding(padding: EdgeInsets.all(...))` |
| Gap (item spacing) | `SizedBox(height: ...)` or `SizedBox(width: ...)` |
| Corner radius | `BorderRadius.circular()` in `BoxDecoration` |
| Drop shadow | `BoxShadow` in `BoxDecoration` |
| Background color | `ColoredBox` or `DecoratedBox` |
| Clip content | `ClipRRect`, `ClipOval` |
| Scrollable content | `SingleChildScrollView`, `ListView.builder` |
| Absolute positioning | `Positioned` inside `Stack` |
| Opacity | `Opacity` widget or color alpha channel |

## Scaffolding a new UI package

If the project has no shared UI package yet, scaffold one following Supy conventions:

```text
packages/design/lib/src/widgets/src/
  lib/
    src/
      colors/
        app_colors.dart
      spacing/
        app_spacing.dart
      theme/
        app_theme.dart
      typography/
        app_text_styles.dart
      widgets/
        widgets.dart        # Barrel file
    ui_kit.dart             # Top-level barrel file
  test/
    src/
      widgets/
  assets/
    icons/
    images/
  pubspec.yaml
  analysis_options.yaml
  dart_test.yaml
```

### Register in workspace (Melos/Pub workspaces)

If the project uses Dart workspaces or Melos, add the new package to the root `pubspec.yaml`:

```yaml
workspace:
  - shared/ui_kit  # Add this line
```

Then run `flutter pub get` from the project root.

## Asset placement

Place assets in the appropriate directory within the target package:

```text
packages/design/lib/src/widgets/src/
  assets/
    icons/          # SVG icons (use flutter_svg for rendering)
    images/         # Raster images (PNG, JPG, WebP)
    fonts/          # Custom font files (if needed)
```

Register assets in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/icons/
    - assets/images/
```

**Asset rules:**

- If the Figma MCP server returns a `localhost` source URL, use it directly to download the asset.
- Do not import a new icon package (e.g. `font_awesome_flutter`) to work around a missing asset.
- Do not use placeholder assets when a `localhost` source is provided.
- Prefer SVGs for icons/simple graphics, rendered with `flutter_svg`. For complex illustrations,
  rasterize to PNG if SVG rendering is problematic.
- Naming: `snake_case`, prefixed `ic_` for icons and `img_` for images (e.g. `ic_arrow_right.svg`,
  `img_hero_banner.png`).
