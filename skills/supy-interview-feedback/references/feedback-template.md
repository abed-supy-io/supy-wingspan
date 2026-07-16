# Flutter Project Interview Feedback

Use this structure verbatim for `INTERVIEW_FEEDBACK.md`. Replace every bracketed prompt with the
actual assessment; keep the headings, scores, and "Focus" / "Critical Assessment" scaffolding for
each section. Everything from here down (starting with section 1) is the literal document body.

---

## 1. Architecture & Dependency Injection

**Score:** `[1-5]`

### Layering & Modularity

[Assess clear separation between Data (repositories, data sources), Domain (business logic,
entities), and Presentation (UI, state). Evaluate if modules/features are isolated and reusable
(e.g., using a feature-first structure).]

**Focus:**

- Are layers clearly separated or is business logic mixed with UI?
- Is there a coherent feature-first or layer-first structure?
- Can features be tested independently?

**Critical Assessment:**

- **This prevents...** [Explain how poor layering creates technical debt]
- **This complicates...** [Identify maintainability issues]
- **This introduces risk...** [Highlight scalability concerns]

### Dependency Injection

[Check for `get_it`/`sl` usage following Supy's pattern: registrations centralized in
`injection_container.dart`, or per-feature in `<feature>/injection/<feature>_dependencies.dart`.
Assess if dependencies are injected consistently and if concrete implementations are decoupled
from interfaces/abstractions.]

**Focus:**

- Is `get_it`/`sl` used correctly, with the registration split (singletons vs. factories)
  matching object lifecycle?
- Are abstractions (repository interfaces) used to decouple implementations?
- Is `BuildContext` avoided inside Blocs and repositories?
- Does the domain ever reach into `GetIt` directly (it shouldn't — resolution happens at the
  presentation boundary)?

**Critical Assessment:**

- **This prevents...** [Explain testability issues from poor DI]
- **This complicates...** [Identify coupling problems]
- **This introduces risk...** [Highlight maintenance concerns]

---

## 2. State Management

**Score:** `[1-5]`

### State Management Solution

[Identify the state management solution (e.g., Bloc/Cubit, Riverpod, Provider). Assess if the
solution is used correctly (e.g., one state manager per feature/concern), if state changes are
minimal and atomic, and if the UI rebuilds are optimized (e.g., using selectors or listeners
appropriately). Look for logic *outside* the state manager (a negative).]

**Focus:**

- Is `Bloc` used (not `Cubit`) with an explicit, sealed event/state contract?
- Is one Bloc provided per feature concern, at the owning feature widget (not a parent)?
- Are state changes atomic and using `copyWith`/`freezed` unions where appropriate?
- Are events separate top-level classes (not inline lambdas)?
- Is `context` or any UI reference absent from Bloc event handlers?
- Is `bloc_test` used for Bloc unit tests?

**Critical Assessment:**

- **This prevents...** [Explain how poor state management hinders feature development]
- **This complicates...** [Identify debugging and testing issues]
- **This introduces risk...** [Highlight future complexity]

---

## 3. UI / UX

**Score:** `[1-5]`

### Look & Feel

[Assess adherence to modern mobile design standards (Material Design, Cupertino). Look for good
use of whitespace, consistent theming, and clear navigation flow.]

**Focus:**

- Does the UI follow Material Design or Cupertino conventions?
- Is there consistent theming (colors, typography, spacing)?
- Is navigation logical and intuitive?

### Loading & Error States

[Check if all asynchronous operations (API calls, data loads) have explicit loading indicators and
clear, user-friendly error messages on failure.]

**Focus:**

- Are loading states shown for async operations?
- Are errors displayed to users clearly?
- Are there retry mechanisms where appropriate?

### Widget Modularization

[Look for small, reusable, and single-responsibility widgets. Too much logic in one build method is
a negative. Use of StatelessWidget and StatefulWidget should be appropriate.]

**Focus:**

- Are widgets broken down into small, reusable components?
- Are build methods concise and focused?
- Is StatelessWidget used where possible?

### Execution Issues

[Note any noticeable jank, performance issues, duplicate API calls on rebuilds, or unnecessary
widget rebuilds (often visible in development tools).]

**Focus:**

- Are there performance issues or unnecessary rebuilds?
- Do API calls get triggered multiple times unnecessarily?
- Is the app responsive and smooth?

**Critical Assessment:**

- **This prevents...** [Explain how poor UI patterns hurt user experience]
- **This complicates...** [Identify maintainability issues]
- **This introduces risk...** [Highlight consistency and quality concerns]

---

## 4. Testing

**Score:** `[1-5]`

### Test Coverage

[Report on the overall percentage of code coverage. Note if key layers are covered (e.g., business
logic, repositories, state managers) versus only trivial UI tests.]

**Focus:**

- What is the approximate test coverage? (Supy's app bar is ≥80%.)
- Are critical business logic paths tested?
- Are tests focused on behavior or implementation details?

### Test Quality

[Assess the quality of tests. Are they isolated (using mocks/fakes)? Are they clear
(Arrange-Act-Assert pattern)? Are they testing the *behavior* (what) and not the implementation
details (how)?]

**Focus:**

- Are tests isolated using `mocktail`, mocking at the boundary (datasource/repository) rather than
  the class under test?
- Do tests follow the Arrange-Act-Assert pattern?
- Are tests testing behavior or implementation?
- Are tests clear and maintainable?

**Critical Assessment:**

- **This prevents...** [Explain how poor testing blocks refactoring]
- **This complicates...** [Identify debugging and confidence issues]
- **This introduces risk...** [Highlight regression and quality concerns]

---

## 5. CI/CD

**Score:** `[1-5]`

### Automation Pipeline

[Check for the presence of a CI configuration file (e.g., GitHub Actions, GitLab CI). Look for
steps that automate `flutter format`, `flutter analyze`, `flutter test`, and potentially building
an artifact.]

**Focus:**

- Is there a CI/CD pipeline configured?
- Does it run format, analyze, and test?
- Are builds automated?

**Critical Assessment:**

- **This prevents...** [Explain how missing CI/CD slows development]
- **This complicates...** [Identify quality control issues]
- **This introduces risk...** [Highlight deployment and consistency concerns]

---

## 6. Error Handling

**Score:** `[1-5]`

### Error Reporting Packages

[Note if any specific packages (e.g., `sentry_flutter`, `firebase_crashlytics`) are used for
logging or reporting errors.]

**Focus:**

- Are error reporting packages integrated?
- Is there a strategy for production error tracking?

### State Management Error Handling

[Check if errors are explicitly modeled and communicated through the state manager rather than
just printing to console or throwing unhandled exceptions. Identify which profile the project
follows — `Either<Failure, T>` (dartz, Profile A) or bare `Future` + `throwAppException` +
`PageState` (Profile B) — and assess consistency within that profile, not against the other one.]

**Focus:**

- Are errors modeled as part of application state (a `Failure`/`error` state, or a `PageState`
  `failure` case)?
- Is the chosen profile applied consistently, with no mixing of `Either` and thrown
  `AppException` patterns in the same project?
- Is error information preserved for debugging?

### UI Error Feedback

[Assess if error messages are displayed to the user clearly and are non-technical. Look for
user-friendly elements like retry buttons where appropriate.]

**Focus:**

- Are error messages user-friendly?
- Are retry mechanisms provided?
- Do users get actionable feedback on errors?

**Critical Assessment:**

- **This prevents...** [Explain how poor error handling hurts debugging]
- **This complicates...** [Identify user experience issues]
- **This introduces risk...** [Highlight reliability and support concerns]

---

## 7. Documentation

**Score:** `[1-5]`

### README

[Check for essential sections: Project description, Setup instructions, How to run tests, and
Prerequisites/Dependencies.]

**Focus:**

- Is there a comprehensive README?
- Can someone clone and run the project from README instructions?
- Are prerequisites and dependencies documented?

### Code Comments

[Look for well-formatted Dart documentation comments (`///`) on public classes, methods, and
properties. Check that comments explain *why* something is done, not just *what* it does.]

**Focus:**

- Are public APIs documented with `///` comments?
- Do comments explain "why" not just "what"?
- Is complex logic explained clearly?

**Critical Assessment:**

- **This prevents...** [Explain how poor documentation slows onboarding]
- **This complicates...** [Identify maintenance and collaboration issues]
- **This introduces risk...** [Highlight knowledge transfer concerns]

---

## 8. Dependencies

**Score:** `[1-5]`

### Dependency Selection

[Assess the quality and necessity of chosen packages. Are dependencies minimal and well-regarded in
the Flutter community? Avoidance of unnecessary "kitchen sink" packages is a positive.]

**Focus:**

- Are dependencies appropriate and necessary?
- Are packages well-maintained and community-trusted?
- Are there unnecessary dependencies?

### Dependency Maintenance

[Check if dependencies in `pubspec.yaml` are the latest stable versions. Note if any packages are
severely outdated or use non-standard version constraints.]

**Focus:**

- Are dependencies up-to-date?
- Are version constraints appropriate (`^` for compatibility)?
- Are there any deprecated packages?

**Critical Assessment:**

- **This prevents...** [Explain how poor dependency choices create technical debt]
- **This complicates...** [Identify upgrade and maintenance issues]
- **This introduces risk...** [Highlight security and compatibility concerns]

---

## 9. Supy Way (Supy Engineering Standards)

**Score:** `[1-5]`

### Architecture Alignment

[Check for adherence to Supy's feature-first project structure and layered architecture — see
`config/standards/flutter/architecture.md`.]

**Focus:**

- Does the project follow Supy's architectural patterns (feature-first, dependencies pointing
  inward, pure-Dart domain)?
- Is there clear separation of concerns?
- Would this fit into a Supy production codebase?

### Supy Tooling

[Assess use of Supy's standard stack: `flutter_bloc` with explicit `Bloc` (not Cubit), `get_it`,
`go_router` + `context.go()`, `mocktail`, `bloc_test`, and `sentry_flutter`.]

**Focus:**

- Are `very_good_analysis` (+ `bloc_lint`) lint rules configured?
- Is `go_router` used with `context.go('/path')` and a `path` constant declared on the page?
- Is `get_it`/`sl` the DI mechanism, with the singleton/factory split matching object lifecycle?
- Are design tokens (`context.supyColors`/`context.colors`, spacing scale, `SupyRadius`,
  `context.textTheme`/`SupyTypography`) used instead of raw values?
- Is `mocktail` used for mocking and `bloc_test` for state testing?

### BLoC Usage (if applicable)

[Assess if Bloc is used following Supy's strict rules: always `Bloc` (never `Cubit`), every event
an explicit separate class, one Bloc per feature concern provided at the owning feature widget,
`bloc_test` for all Bloc tests.]

**Focus:**

- Is `Bloc` used exclusively (no `Cubit`)?
- Are all events explicit top-level classes with descriptive names?
- Is each Bloc provided at its feature widget — not a parent?
- Are states immutable (`freezed` unions, or `Equatable` + `copyWith`)?
- Does `bloc_test` cover happy path, error, and loading states?

### Coding Standards

[Check for adherence to Supy's coding standards beyond the standard Dart lints.]

**Focus:**

- Does code pass `very_good_analysis` (+ `bloc_lint`) lints?
- Are Supy naming conventions followed?
- Is code style consistent with Supy standards?

**Critical Assessment:**

- **This prevents...** [Explain how misalignment creates integration friction]
- **This complicates...** [Identify onboarding and collaboration issues]
- **This introduces risk...** [Highlight standardization concerns]

---

## Summary & Decision

### Overall Impression

[Provide 2-3 sentences summarizing the candidate's work. Be honest but professional.]

### Top Strengths

1. **[Strength 1]** — [Brief explanation]
2. **[Strength 2]** — [Brief explanation]
3. **[Strength 3]** — [Brief explanation]

### Top Concerns

1. **[Concern 1]** — [Brief explanation with impact]
2. **[Concern 2]** — [Brief explanation with impact]
3. **[Concern 3]** — [Brief explanation with impact]

### Hiring Decision

**[RECOMMENDED / BORDERLINE / NOT RECOMMENDED]**

**Justification:**
[Provide 2-3 sentences explaining the decision. Consider:]

- Would this candidate be productive on Supy projects immediately?
- Are the deficiencies coachable or fundamental?
- Does the candidate demonstrate growth potential and learning ability?

**RECOMMENDED** — Solid work demonstrating professional competence and Supy standards alignment.
Minor gaps can be addressed through onboarding.

**BORDERLINE** — Shows promise but has significant gaps. Consider for junior roles or with
additional screening. May need substantial mentoring.

**NOT RECOMMENDED** — Fundamental deficiencies in critical areas. Would require extensive training
to meet Supy standards. Not ready for production work.

---

## Document checklist

Each of the 9 sections above must have:

1. A clear score (integer 1-5).
2. Specific examples from the codebase.
3. Critical assessment using "This prevents/complicates/introduces" language for negatives.
4. Recognition of strengths where applicable.
5. Focus on actionable, specific observations.

The final Summary & Decision section must include:

- Overall impression (2-3 sentences).
- Top 3 Strengths (bulleted with explanations).
- Top 3 Concerns (bulleted with impact).
- Clear hiring decision (RECOMMENDED/BORDERLINE/NOT RECOMMENDED).
- Justification (2-3 sentences).
