# Flutter Agent Skills

Agent skills for Flutter development, vendored from the official
[flutter/skills](https://github.com/flutter/skills) repository, maintained by
the Flutter team.

These skills provide tailored, repeatable instructions for happy-path Flutter
app development workflows. By giving the agent domain expertise and reliable
workflows, they reduce mistakes and help agents complete tasks following
best practices.

They live in the universal `.agents/skills/` folder so that any compatible
coding agent can discover and use them.

## Available Skills

| Skill | Description |
|---|---|
| [flutter-add-integration-test](flutter-add-integration-test/SKILL.md) | Configures Flutter Driver for app interaction and converts MCP actions into permanent integration tests. |
| [flutter-add-widget-preview](flutter-add-widget-preview/SKILL.md) | Adds interactive widget previews to the project using the `previews.dart` system. |
| [flutter-add-widget-test](flutter-add-widget-test/SKILL.md) | Implements component-level tests using `WidgetTester` to verify UI rendering and user interactions. |
| [flutter-apply-architecture-best-practices](flutter-apply-architecture-best-practices/SKILL.md) | Architects a Flutter application using the recommended layered approach (UI, Logic, Data). |
| [flutter-build-responsive-layout](flutter-build-responsive-layout/SKILL.md) | Uses `LayoutBuilder`, `MediaQuery`, or `Expanded`/`Flexible` to create adaptive layouts. |
| [flutter-fix-layout-issues](flutter-fix-layout-issues/SKILL.md) | Fixes Flutter layout errors (overflows, unbounded constraints). |
| [flutter-implement-json-serialization](flutter-implement-json-serialization/SKILL.md) | Creates model classes with `fromJson`/`toJson` using `dart:convert`. |
| [flutter-setup-declarative-routing](flutter-setup-declarative-routing/SKILL.md) | Configures `MaterialApp.router` using `go_router` for URL-based navigation. |
| [flutter-setup-localization](flutter-setup-localization/SKILL.md) | Adds `flutter_localizations` and `intl` and configures app localization. |
| [flutter-use-http-package](flutter-use-http-package/SKILL.md) | Uses the `http` package to execute GET, POST, PUT, or DELETE requests. |

## Updating

These skills were vendored from <https://github.com/flutter/skills>. To refresh
them, re-copy the contents of that repository's `skills/` directory, or use the
upstream tooling:

```bash
npx skills update
```

## License

These skills are Copyright The Flutter Authors and distributed under the
BSD-3-Clause license. See [LICENSE](LICENSE) for the full text.
