# Changelog

All notable changes to this project will be documented in this file.
**Changes that are visual in nature are not considered breaking and will typically only result in a minor version bump.**
However, when those changes are made, there will be a specific **VISUAL CHANGES** section within the version notes.
If you are a designer or otherwise need to be pixel-perfect, please pay special attention to those sections.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## v1.0.7 - 2024-04-17

## v1.0.7 - 2024-04-17

## v1.0.7 - 2024-04-17

## v1.0.7 - 2024-04-17

## 0.0.1 - 2024-04-16

## 4.3.0 - 2024-04-15

### Added

- `TimeField` now supports `controlled` prop (defaults to false) which allows it to work similar to native react controlled inputs where it always displays the `value` and updates it via calling `onChange`

## 4.2.1 - 2024-04-11

### Fixed

- `TimeField` component now always returns numbers in `onChange` event for mobile.
- `Combobox`: `onHighlight` is properly passed down.
- TypeScript: `NumberField` types now allow `string` for `value`, `max`, and `min`
- TypeScript: `mediaQueries` and `variants` types are improved for many components

### Security Updates

- bump express from 4.18.1 to 4.19.2
- bump tar from 6.1.11 to 6.2.1

## 4.2.0 - 2024-04-03

### VISUAL CHANGES

- `Radio`: default fill color is now blue, rather than theme-defined primary color

### Changes

- Added `error` prop to `Radio` to visually indicate an error state
- Type improvements
  - Box - Infers types based on `as`
  - Badge
  - Button - Infers types based on `as`
  - Card - Infers types based on `as`
  - Combobox.Popover
  - Dropdown
  - FieldSet
  - Input
  - Link - Infers types based on `as`
  - List - Infers types based on `as`
  - NumberField - Infers types based on `as`. Types now correctly show that onChange can return number or string.
  - Page
  - PagerView
  - Pagination
  - Radio
  - Select - Infers value
  - Sidebar
  - Sortable
  - StackView - Infers types based on `as`
  - Table
  - Theme
  - TokenInput
  - Toolbar
  - Tooltip - title is now optional
  - WrapView
- Update lodash imports to decrease dependency size

### Infrastructure

- add working linting using eslint

## 4.1.0 - 2024-03-12

### Changes

- Dropdown: trigger cursor is `not-allowed` when the Dropdown is `disabled`
- Select: change to `role="combobox"`
- Type improvements:
  - DateField
  - TimeField
  - DataTable

### Bugfix

- Fix `Cannot read properties of undefined (reading 'scrollWidth')` in React 18's Strict Mode
- DateField: `disabled` state now passed to `DateField`

### Infrastructure

- `jest` upgraded from 26 to 29
- add type checking to PR process with Balto

## 4.0.1 - 2024-02-26

### Bugfix

- Fix error in using `Tab.TabPanel`

## 4.0.0 - 2024-02-21

### Breaking

- commonjs output is no longer provided.

### Changes

- Build process is now done via rollup https://github.com/planningcenter/tapestry-react/pull/411
- Update `Day` component in `Calendar` to better indicate disabled days
- Update `Input` to support readOnly state
- Update `ToggleSwitch` for better a11y label support
- All files are converted to TypeScript and types are adjusted with a loose version of where they will end up.
- Use SWC for tests and gatsby site build ing

### Bugfix

- Upgrade internal packages to fix security issues.

## 3.0.0 - 2024-02-08

### Changed

- Update `Logo` component to display logos for all Planning Center products

### Bugfix

- Upgrade internal packages to fix security issues.

## 2.10.0 - 2024-01-22

### Added

- Add `zIndex` prop to `Tooltip` to fine-tune position when elements overlap visually
- Add `home` color to default theme
- Add new `TabNav` component
- Use token value from `@planningcenter/tapestry-design-token` to set the border-radius on `Button`
- Add new `Dialog` component

### Bugfix

- `Menu.Item` displays `renderLeft` properly when defined.

### Changed

- Update eslint config to use typescript-eslint parser
- Convert components using Flow to use Typescript
  - Badge.Status
  - Box
  - Button.Input
  - Calendar
  - Checkbox
  - CheckboxGroup
  - Combobox
  - Combobox.Input
  - EditActions
  - Field
  - HeadingUppercase
  - Heading
  - Highlight
  - Icon
  - Logo
  - Modal
  - Progress
  - Radio
  - StackView
  - StepperField
  - Summary
  - Textarea
  - Wizard
- Calendar: update incorrect `onDateChange` prop type
- Calendar: make `date`, `initialDate`, `minDate`, `maxDate`, `onDateChange`, `onDateSelect`, and `weekStartsOn` props optional
- Update `Button` border-radius from `3px` to `4px` to match the current UX Design spec
- Update `Input.Inline` and `Input.InputBox` border-radius from `3px` to `4px` to match current UX Design spec
- Update `Badge` to fix typescript errors
- Update `@planningcenter/icons` to `15.3.0`
- Separate themes get separate `emotion` caches
- Update `Link` component
  - Make `<a>` default HTML element rendered
  - Adjust type expectation for `to` from `boolean` to `string`
- Update `eslint-config-react-app` to `7.0.1`
- Update `ToggleSwitch` to make label trigger the switch
- Update Jest config to ignore `/dist` directory
- Clean up types in `Combobox.Popover`

## [2.9.2] - 2023-11-02

### Added

- Adds convenience `tr` shorthand for access to packages/tapestry-react scripts
- Adds optional increment/decrement buttons to `NumberField`

### VISUAL CHANGES

- Update `Button` `success` and `error` themes to match spec colors.

### Fixed

- CSS color alias matching now works with camel case object keys
- Fixes a bug in `TimeField` where the hour can be set to `24`.

## [2.9.1] - 2023-10-17

### Fixed

- Fix behavior of `DataTable`'s sticky children - header row & pagination - in `FilterLayout`.

### Changed

- Enhance `ToggleSwitch` accessibility with `role=switch` and `aria-checked`

## [2.9.0] - 2023-10-04

### Added

- Adds new ToggleSwitch component.
- Adds `uxCompliant` frontmatter option for docs pages. When set to `true`, component will have a badge indicating that it is UX compliant.

### Changed

- Upgrade `@planningcenter/react-beautiful-dnd` to `v13.4.0` to address mobile drag and drop issues
- Updates `Button` to accept a `disabled` style object from the theme definition
- Updates `Button` to support themable `focus` and `focusVisible` styles
- Updates to `TimeField` component
  - rebuilds component using Typescript and simpler/clarified time update functions
  - now accepts an entered value with a "leading zero" (i.e. "02")
  - on any mobile device, `TimeField` renders a standard `<input type="time" />` and allows device to use standard/native UI to update the value
- Fix inaccurate `DataTable` column re-measurement in `FilterLayout` when `sidebarWidth` is set to `fill`.

### Docs

- Fix broken internal links
- Update Algolia Docsearch index to get search working again

## [2.8.2] - 2023-08-29

### Fixed

- Prevents `DateField` component from submitting a form when tapping "Enter" and instead will just close the calendar popover.

## [2.8.1] - 2023-08-24

### Fixed

- Fix bug (introduced in 2.8.0) in the `DateField` component that prevented users from changing the month or year within the calendar view.

## [2.8.0] - 2023-08-17

### Changes

- Updates `peerDependencies` to indicate support for React versions `>=16.8` and `<19`
- Updates the `disabled` prop on `Button` to prevent certain events from firing, instead of adding a native `disabled` attribute in the DOM. This will allow composing components (like `Tooltip`) to work.
- Removes keyboard navigation from `Calendar` component. This was not working as expected, particularly in combination with the `DateField` component, and will be re-addressed in a future release.
- Adds keyboard support to `DateField` component. You are now able to type (or paste) a date directly in the text field, and navigate the calendar modal with the arrow keys. Previously the only way to interact with the date picker was with your mouse.

### Fixed

- Updates `ComboBox` input for voice-over accessibility of the selected list item

## [2.7.0] - 2023-07-27

### VISUAL CHANGES

- Updates `success`, `warning`, and `error` status colors to match latest design spec.

### Changes

- Updates package + documentation to the latest version of `@planningcenter/icons`.
- Includes the new `toolbar` icon set to the `Icon` component documentation.
- Adds two `data-dnd-ignore-scrollable` attributes to `DataTable` for better drag and drop behavior from `@planningcenter/react-beautiful-dnd`.
- Replaces deprecated `create-emotion-server` with `@emotion/server`.

### Fixed

- `Button` now properly handles the `disabled` state when `type="submit"`.

## [2.6.2] - 2023-07-06

- Add `required` prop to `Input` component

## [2.6.1] - 2023-05-18

- Fixes a bug in `Collapse` where the combination of `instant` & `lazy` props and dynamic content may lead to incorrectly sized containers.
- Fixes a bug in `Dropdown` where Safari's handling of the `blur` DOM event was preventing the popover from closing when a user clicks on the trigger element.

### VISUAL CHANGES

- Update border radius, box shadow, and padding of `Modal` to match the most recent design spec.

## [2.6.0] - 2023-05-01

### Changes

- Update `ThemeProvider` to append color values to a scoped DOM element vs the document `:root`. This change allows multiple Tapestry React themes to be consumed by a single app.
- Update `Popover` to accept color values from `ThemeProvider`
- Update `Portal` to accept color values from `ThemeProvider`
- Update `DragDrop` to inherit global color values from `ThemeProvider`
- Update top-level `ThemeProvider` element to `Box` component
- Update `InputLabel` to implement `ThemeProvider`
- Changes scope of `tapestry-react-reset` class to include all elements inside of `ThemeProvider`
- Add `ThemeProvider` support to `Scrim`, `Modal` and `Popover`
- Adjust scope and CSS properties of `tapestry-react-reset` class
- Expose click events for `onRowClick` in `DataTable` and `onClick` in `Dropdown`
- Update documentation to update dark/light mode with React.Context hook
- Add custom install, build, and test Github workflow commands
- Add type of `BoxProps` into type defintion for `ThemeProvider`
- Update dependency `@planningcenter/icons` version to `v14.12.0`
- Update lodash imports to decrease dependency size

### Fixed

- `TimeField` no longer clips text for `lg` or `xl` sizes
- `Dropdown.Link` no longer opens duplicate tabs/windows
- `Button` is less aggressive in throwing errors when checking for `type=""`. Add tests around these changes.
- Add better Typescript types for `Divider`, `Spinner`, `Page*`, `Checkbox`, `Input.*`, `List.*`, `Select.*`, and `Sortable.*`
- Make sure `Input` wraps an input HTML element
- Properly cleanup `pageInView` event listeners created in `Tooltip`

## [2.5.2] - 2023-03-09

### Fixed

- `Tooltip` was not staying open properly when hovering over a composed title, as in the Services item file browser implementation

## [2.5.1] - 2023-03-03

### Fixed

- Fixed `Button` development breaking change with a short-term fix by downgrading `throw Error` to `console.log`.
- `Checkbox` will properly silence a11y warning if a parent `label` is present.

### Changes

- `ThemeProvider` support in `Pagination`

## [2.5.0] - 2023-02-28

### Changes

- `Button` support for `type="button|submit|reset"`

## [2.4.0] - 2023-02-20

### Changes

- Update `@planningcenter/icons` version from `14.0.0` to `14.11.0`.
- Update the Dash docset to reference the correct `planningcenter` github repo.

### Fixed

- `Sidebar` has the correct warning for child components.

### VISUAL CHANGES

- Change background opacity of `Scrim` to `40%` to match our design spec.

## [2.3.0] - 2023-02-09

### Fixed

- `Button` is now rendered as a HTML `<button>` when no `href` prop is passed.

## [2.2.0] - 2023-01-09

### Changes

- Converted `Combobox` to hooks and applied the `ThemeProvider`.
- Converted `Wizard` to hooks and applied the `ThemeProvider`.
- Converted `Tooltip` to hooks and applied the `ThemeProvider`.
- Converted `SegmentedControl` to hooks and applied the `ThemeProvider`.
- Converted `Field` to hooks and applied the `ThemeProvider`.
- Converted `SegmentedTabs` to hooks and applied the `ThemeProvider`.
- Converted `DateField` to hooks and applied the `ThemeProvider`.
- Converted `Tabs` to hooks and applied the `ThemeProvider`.

### Fixed

- Fixed bug in `Card` where border radius of some child components was being unintentionally changed.
- Fixed a console warning for `Badge` passing the `square` attribute to `StackView`.

## [2.1.2] - 2022-12-09

### Fixed

- Fixed an issue with `Pagination` with custom colors and fix active/focus color.
- Fixed instances of components with oversized `boxSizes`
  - Added `avatarSizes` object for use in `Avatar`
  - Reverted `boxSizes` to their previous values

## [2.1.1] - 2022-11-21

### Fixed

- Fixed a TypeError in `Calendar.Day`. Removed usage of `Icon.Status` in favor of a more simple `Icon` implementation.

### Added

- Added the `Menu.Heading` & `Menu.Item` sub components to the documentation site.

## [2.1.0] - 2022-10-27

### VISUAL CHANGES

- Several default `Avatar` sizes have been tweaked to match UX spec
  - `<Avatar size="md">` is now 36x36 instead of 32x32
  - `<Avatar size="lg">` is now 48x48 instead of 40x40
  - `<Avatar size="xl">` is now 72x72 instead of 64x64

### Changes

- Avatar now has a new size, "xxl", which is 112x112
- Pagination styles changed to match UX spec
  - Next/prev buttons are now both to the left of individual page buttons
  - Mobile breakpoint now uses a default `visiblePages` value of 5
- Update Contributing guide
- Add prop type defs to `Button` `hover` and `focus`
- Update references to `ministrycenter` packages to `planningcenter`
- Remove no longer used or necessary development scripts and packages
- Add a CODEOWNERS file to communicate code owners
- Hide collapsed children from accessibility tree in `Collapse`
- Update README for better instructions post-deploy
- Use our own fork of `react-beautiful-dnd`

### Fixed

- accept exactly 2 arguments for `React.forwardRef` in `Scrim` to keep it from spouting errors in the console
- Use correct `Button` prop of `focus` in `Pagination`
- Use correct favicon location
- Enable `variantFilled` to show filled icons in `Icon.Status`

### Docs

- lots of docs updates and improvements
- previously undocumented components now have docs!

### Security

- upgraded outdated versions of dependencies from within the `site` and `dash` workspaces

## [2.0.0] - 2022-08-25

### BREAKING CHANGES

- **ColumnView, GridView, StackView, TileView, WrapView**: `spacing` prop no longer accepts negative values or bare strings
  - Removes the affordance of passing negative values to `spacing` in `StackView`. Requires that consumers style desired overlap of `children` directly.
  - Requires that bare strings passed to `spacing` **as spacers** be wrapped in a `<Text>` component
- **Icons**: all icons require a prefix (e.g. `general.plus`, `services.audio`)
  - See https://github.com/planningcenter/tapestry-react/pull/40 for details of icon replacement values

### Changed

- Unifies the `spacing` api within layout components - `ColumnView`, `GridView`, `StackView`, `TileView`, `WrapView`
  - Updates the `spacing` api to be driven by CSS `gap` instead of conditionally applied margins
    - The result should be more concise implementations and logical behavior when passing the `mediaQueries` prop to `StackView`
    - Adds the ability to pass valid CSS `gap` values to `spacing`
    - Unifies the values that can be passed to `spacing` (aside from the special case of `<StackView spacing={<Component />} />`)
- Moves the application of negative margins to `Group` `children` into the `Group` component itself
- Improve keyboard navigability within `Popover`
- Replaces built-in icons with imported icons from the `@planningcenter/icons` package
  - Icons now require a prefix, including new prefix options: `services` and `tapestry`

## [1.4.0] - 2022-06-28

### Changed

- Prevent `<Field>`'s `children` from overflowing horizontally
- Require popperjs/core 2.9.0 to prevent error

## [1.3.0] - 2022-05-18

### Changed

- Increase to horizontal padding on `Menu.Item` and `Menu.Heading` to align with the [current specification](https://www.figma.com/file/PJrldLtH5qVWqZ5tx6x0qTTa?embed_host=notion&kind=&node-id=5968%3A3930&viewer=1).
  - Note: since `Dropdown` is happy to render children that are not wrapped in `Dropdown.Item/Heading`, this update may cause some misalignment if those custom children have a horizontal padding value other than `16px`.
- Pass the `to` prop through the `Button` component when the `as` prop is used

## [1.2.0] - 2022-03-16

### Changed

- Bring `Page*` components inline with Tapestry spec

## [1.1.0] - 2022-03-09

### Changed

- `ActionsDropdown` duplicates style updates
- fix `NumberField` deleting with a pad prop; this was a little messed up with the transfer from UI-Kit v16.0.1 to tapestry-react v1.0.0

## [1.0.0] - 2022-03-03

- Essentially a rename of [UI-Kit v16.0.1]

[4.2.0]: https://github.com/planningcenter/tapestry-react/releases/tag/v4.2.0
[4.1.0]: https://github.com/planningcenter/tapestry-react/releases/tag/v4.1.0
[4.0.1]: https://github.com/planningcenter/tapestry-react/releases/tag/v4.0.1
[4.0.0]: https://github.com/planningcenter/tapestry-react/releases/tag/v4.0.0
[3.0.0]: https://github.com/planningcenter/tapestry-react/releases/tag/v3.0.0
[2.10.0]: https://github.com/planningcenter/tapestry-react/releases/tag/v2.10.0
[2.9.2]: https://github.com/planningcenter/tapestry-react/releases/tag/v2.9.2
[2.9.1]: https://github.com/planningcenter/tapestry-react/releases/tag/v2.9.1
[2.9.0]: https://github.com/planningcenter/tapestry-react/releases/tag/v2.9.0
[2.8.2]: https://github.com/planningcenter/tapestry-react/releases/tag/v2.8.2
[2.8.1]: https://github.com/planningcenter/tapestry-react/releases/tag/v2.8.1
[2.8.0]: https://github.com/planningcenter/tapestry-react/releases/tag/v2.8.0
[2.7.0]: https://github.com/planningcenter/tapestry-react/releases/tag/v2.7.0
[2.6.2]: https://github.com/planningcenter/tapestry-react/releases/tag/v2.6.2
[2.6.1]: https://github.com/planningcenter/tapestry-react/releases/tag/v2.6.1
[2.6.0]: https://github.com/planningcenter/tapestry-react/releases/tag/v2.6.0
[2.5.2]: https://github.com/planningcenter/tapestry-react/releases/tag/v2.5.2
[2.5.1]: https://github.com/planningcenter/tapestry-react/releases/tag/v2.5.1
[2.5.0]: https://github.com/planningcenter/tapestry-react/releases/tag/v2.5.0
[2.4.0]: https://github.com/planningcenter/tapestry-react/releases/tag/v2.4.0
[2.3.0]: https://github.com/planningcenter/tapestry-react/releases/tag/v2.3.0
[2.2.0]: https://github.com/planningcenter/tapestry-react/releases/tag/v2.2.0
[2.1.2]: https://github.com/planningcenter/tapestry-react/releases/tag/v2.1.2
[2.1.1]: https://github.com/planningcenter/tapestry-react/releases/tag/v2.1.1
[2.1.0]: https://github.com/planningcenter/tapestry-react/releases/tag/v2.1.0
[2.0.0]: https://github.com/planningcenter/tapestry-react/releases/tag/v2.0.0
[1.4.0]: https://github.com/planningcenter/tapestry-react/releases/tag/v1.4.0
[1.3.0]: https://github.com/planningcenter/tapestry-react/releases/tag/v1.3.0
[1.2.0]: https://github.com/planningcenter/tapestry-react/releases/tag/v1.2.0
[1.1.0]: https://github.com/planningcenter/tapestry-react/releases/tag/v1.1.0
[1.0.0]: https://github.com/planningcenter/tapestry-react/releases/tag/v1.0.0
[ui-kit v16.0.1]: https://github.com/planningcenter/ui-kit/releases/tag/v16.0.1
