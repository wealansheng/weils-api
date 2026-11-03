---
name: Weils API
description: A restrained light blue-gray Windows API workspace.
colors:
  primary: "#3567E8"
  ink: "#263449"
  muted: "#65748A"
  shell: "#F4F6F9"
  line: "#E4E9F0"
  selection: "#EAF0FB"
  white: "#FFFFFF"
  green: "#23835A"
  red: "#BD3C49"
  amber: "#A96818"
  table: "#F8FAFC"
  syntax-key: "#4665A0"
  syntax-literal: "#986B28"
typography:
  title:
    fontFamily: "Microsoft YaHei, Segoe UI, Arial"
    fontSize: "16px"
    fontWeight: 600
  heading:
    fontFamily: "Microsoft YaHei, Segoe UI, Arial"
    fontSize: "17px"
    fontWeight: 600
  body:
    fontFamily: "Microsoft YaHei, Segoe UI, Arial"
    fontSize: "13px"
  small:
    fontFamily: "Microsoft YaHei, Segoe UI, Arial"
    fontSize: "12px"
  label:
    fontFamily: "Microsoft YaHei, Segoe UI, Arial"
    fontSize: "11px"
  method:
    fontFamily: "Consolas, Microsoft YaHei"
    fontSize: "10px"
    fontWeight: 600
  code:
    fontFamily: "Consolas, Microsoft YaHei"
    fontSize: "13px"
    lineHeight: 1.65
rounded:
  checkbox: "3px"
  status: "4px"
  row: "5px"
  icon: "6px"
  control: "7px"
  rail: "8px"
spacing:
  compact: "8px"
  field: "12px"
  section: "16px"
  workspace: "20px"
  roomy: "24px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.white}"
    rounded: "{rounded.control}"
    padding: "0px 18px"
    height: "36px"
  button-outlined:
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    height: "34px"
  button-text:
    textColor: "{colors.primary}"
  input:
    backgroundColor: "{colors.white}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    padding: "11px 12px"
  nav-selected:
    backgroundColor: "{colors.selection}"
    textColor: "{colors.primary}"
    rounded: "{rounded.rail}"
    width: "60px"
    height: "67px"
  request-row-selected:
    backgroundColor: "{colors.selection}"
    textColor: "{colors.ink}"
    rounded: "{rounded.row}"
    height: "34px"
    padding: "0px 8px"
  section-tab-selected:
    textColor: "{colors.primary}"
    height: "40px"
    padding: "0px 16px"
  status:
    rounded: "{rounded.status}"
    padding: "3px 8px"
    typography: "{typography.small}"
---

# Design System: Weils API

## Overview

**Creative North Star: "浅色蓝灰 API 工作台"**

A clean, restrained Windows desktop API tool. White work areas sit inside a cool-gray shell; slate text, pale-blue selection and cobalt actions keep the request and response legible together. The confirmed visual language is practical and compact.

Microsoft YaHei and the Windows fallback stack serve Chinese UI text; Consolas separates URLs, methods and response content. Density comes from short rows and thin separators rather than decorative cards. This records the shipped Flutter implementation, with no new visual identity.

**Key Characteristics:**
- White workspace and cool-gray shell.
- Pale-blue selection with cobalt action and active-state cues.
- Compact desktop controls, thin borders and readable code.

Evidence: `lib/ui/theme.dart`, `common.dart`, `workspace_page.dart`, `request_editor.dart`, `history_detail.dart` and `dialogs.dart`; cross-checked against `.impeccable/review/native-editor.png`. `PRODUCT.md` and the surface contract supply the already-confirmed language and shell constraints. Values expressed as px in the portable frontmatter correspond to Flutter logical pixels, not physical Windows pixels. Component tokens describe observed defaults; Flutter Material 3 supplies inherited states where the app does not override them.

## Colors

One cobalt accent sits against cool white and blue-gray neutrals. Semantic and syntax colors describe data, rather than additional brand accents. Exact values are owned by the frontmatter.

### Primary

- **Cobalt (`primary`)**: send/create buttons, active labels, focus borders, selected tabs and the API mark.
- **Pale Blue (`selection`)**: selected rail destination, work tab, request row and history row.

### Neutral

- **White (`white`)**: work panes, input fills and dialog surfaces.
- **Cool Shell (`shell`)**: app header, activity rail and workspace tab strip.
- **Slate Ink (`ink`)**: primary interface and code text.
- **Muted Slate (`muted`)**: secondary metadata, hints, inactive tabs and utility icons.
- **Thin Border (`line`)**: pane separators, input strokes and table dividers.
- **Table Wash (`table`)**: parameter table headers and the read-only historical URL container.

### Semantic and syntax roles

- **Green (`green`)**: GET, successful response text and JSON strings.
- **Red (`red`)**: DELETE, errors and unsuccessful response text.
- **Amber (`amber`)**: POST and warning iconography.
- **Syntax Key (`syntax-key`)** and **Syntax Literal (`syntax-literal`)**: JSON keys and primitive literals. Other HTTP methods use cobalt. Cancelled response status uses muted slate.

**The Selection and Action Rule.** Use pale blue for selected surfaces and cobalt for actions, active labels and tab underlines.

## Typography

**Body Font:** Microsoft YaHei, with Segoe UI and Arial fallbacks.
**Label/Mono Font:** Consolas, with Microsoft YaHei fallback.

The native desktop UI uses one compact sans stack; code uses a distinct fixed-width face. There is no reusable display-face role. Typography frontmatter omits inherited weight or line-height values that the source does not explicitly set.

### Hierarchy

- **Title**: the themed medium title role; semibold, used as the base heading role.
- **Heading**: semibold request and dialog headings.
- **Body**: ordinary UI text and controls.
- **Small**: metadata, request names and secondary text.
- **Label**: rail captions, helper text and compact table headings; natural Chinese/English case.
- **Method**: semibold monospace method labels in resource rows.
- **Code**: response/body content, with an explicit airy line-height. URL fields override this line-height to 1.2; table code fields use 12px and 1.2.

The implementation additionally uses a 23px semibold home heading, 19px sidebar heading, 18px app/settings/help headings and 14px response/empty-state headings. These are contextual sizes, not a newly imposed mathematical scale.

**The UI and Code Rule.** Keep the Windows UI stack for interface text and Consolas for code content and method labels.

## Layout

The desktop shell has a 52px header, a 76px activity rail, a resource sidebar and a flexible white workspace. The sidebar is 270px at widths of at least 1400px, otherwise 250px. The footer is 33px; workspace tabs occupy 44px. Content is laid out at a minimum of 1000 × 600 logical pixels and becomes scrollable below that extent. This is the shipped Windows behavior, with no mobile navigation transformation.

Repeated spacing centers on compact gaps, field insets, section gaps and workspace gutters in the frontmatter. The editor uses 20px side gutters; ordinary inputs have horizontal 12px and vertical 11px content insets. Parameter rows are 36px and their header is 33px; section tabs are 40px. Not all source spacing is a multiple of a single base unit.

The URL/method control and send button are 40px tall. The request editor starts with a 184px parameter region, clamped to at least 120px, above a 12px vertical resize target and a flexible response. The maximum request height reserves 150px for the remaining area, subject to the source's lower clamp. History detail uses a fixed proportional request area (33%, clamped to 130–220px) above the response. Long names ellipsize; code is selectable with horizontal and vertical scrolling.

## Elevation & Depth

The persistent workspace is flat: thin separators and tonal selection establish hierarchy. Filled buttons explicitly use zero elevation. Dialogs are white with transparent surface tint and retain Flutter Material 3 modal treatment; no app-specific shadow or modal-radius token is defined. Do not mistake a framework default for a custom house shadow.

**The Flat Workspace Rule.** Separate persistent work areas with tone and thin borders; primary buttons have zero elevation.

No bespoke animation duration or easing is defined. InkWell and Material controls retain inherited hover/focus feedback; splash ripples are disabled. Request progress uses Flutter progress indicators. Tooltips wait 500ms; transient feedback SnackBars commonly last two seconds. These timings are interaction behavior, not a new animation system.

## Shapes

Compact softened rectangles carry the interface. Controls and work-tab top corners use `control`; activity destinations use `rail`. Resource rows use `row`, history rows and icon buttons use `icon`, status badges use `status`, and checkboxes use `checkbox`. Normal pane and field strokes are 1px; focused outlined fields use a cobalt 1.5px stroke, and active section tabs use a cobalt 2px underline. The checkbox has a 1.2px cool-gray stroke supplied directly by the theme. Panes remain rectangular, without a repeated decorative card treatment.

## Components

### Buttons

Restrained and task-focused. Primary buttons use cobalt, white text, the control radius, a minimum height of 36px and horizontal 18px padding; their explicit type is 13px, medium weight. Send is sized to 91 × 40px; the home create action is 39px tall. Outlined buttons use slate text, the line stroke and a 34px minimum height. Text buttons use cobalt. Icon buttons use muted slate, 18px icons, a 30px minimum target, 5px padding and the icon radius. Hover, focus, pressed and disabled resolution is inherited from Flutter Material 3 unless the widget overrides it.

### Inputs / Fields

White filled outlined fields use the control radius and line stroke, switching to the focused cobalt stroke. Search is a compact 34px variant with 12px text. The request name uses an underline on focus instead of the standard outline. Parameter/header cells also use underline-style editing. The composite URL row has one surrounding border, an internal method separator and monospace URL text.

Generated request-header names and values are read-only, selectable and use `muted`; their description reads “默认”. User-added header cells retain `ink` and ordinary editable controls. An enabled same-name custom header replaces the generated row case-insensitively; disabling it restores the generated row. The Headers section keeps “添加Header” visible beneath its scrollable rows. Its initial request-pane height is 260px, while other request sections start at 184px; the divider remains resizable.

### Navigation

The only rail destinations are **接口管理** and **请求历史**. Each destination is a 60 × 67px rounded target with a 23px Material icon and an 11px caption. Selected state combines selection fill, cobalt text/icon and semibold caption. Settings remains top-right; help remains bottom-right. These are confirmed shell commitments.

Work tabs use rounded top corners, a pale-blue active background and cobalt semibold 12px text. Labels constrain to 160px and ellipsize. A 5px dot marks unsaved edits; close controls remain separate targets. Section tabs use muted 13px text at rest, cobalt semibold text and an underline when active.

### Resource and history rows

Selected rows use pale blue and retain their method text, rather than recoloring the whole row with a method color. Resource rows are 34px high with 12px request names and 10px semibold method labels. History rows add timestamp and response metadata. Their selection opens a read-only snapshot; **编辑并重发** creates an independent draft. Preserve the visible distinction between immutable history and editable requests.

### Response status and code

Response badges use semantic text on the same semantic color at 8% opacity, compact insets and the status radius. Status text is accompanied by elapsed time and captured size. JSON preview colors keys, strings and literals; plain text stays slate. Empty, running, error and cancelled states have their own text and Material icon. Code remains selectable and scrollable.

### Dialogs

White modal surfaces use semibold 17–18px headings and ordinary UI text. Name-entry, dirty-close, settings and help dialogs share the button/field system. Recovery dialogs present real storage failures and preserve the retry/cancel choices; their existence does not add a new visual family.

The sidecar's HTML/CSS specimens are portable documentation approximations of these native widgets. They are not runtime components, do not import Flutter and do not redefine inherited Material behavior. Synthesized tonal strips are panel previews, not shipped palette tokens.

## Do's and Don'ts

### Do:
- Do use the existing white, shell, selection and line roles for pane hierarchy.
- Do keep request and response together and allow code content to scroll in both axes.
- Do pair status and method colors with readable text labels.
- Do retain the confirmed Chinese navigation and utility labels.

### Don't:
- Don't introduce branch or environment controls, extra rail destinations, or extra shell utility entries.
- Don't replace the confirmed blue-gray palette with the discarded warm or purple directions.
- Don't promote screenshot sample requests, response metrics or generated preview ramps into product defaults.
