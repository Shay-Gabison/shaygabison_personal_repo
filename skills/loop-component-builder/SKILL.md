---
name: loop-component-builder
description: "Build a Microsoft-supported Adaptive Card-based Loop component from scratch as a TypeScript Teams/Microsoft 365 app. Use when the user asks to create, scaffold, prototype, or convert an app into a Loop component; mentions Adaptive Card Loop components, portable live cards, link unfurling, Universal Actions, metadata.webUrl, or a component that works across Teams, Outlook, and Microsoft 365. Produces a runnable app with persistence, refresh, actions, manifest wiring, tests, and deployment instructions."
domain: microsoft-365-development
confidence: high
---

# Loop Component Builder

Build a complete TypeScript application that produces a Microsoft-supported
**Adaptive Card-based Loop component**. The generated result is a Teams message
extension with link unfurling, Universal Actions, a stable `metadata.webUrl`,
backend persistence, per-user authorization, refresh behavior, and Microsoft 365
manifest support.

This skill builds Adaptive Card-based Loop components. It does not create native
Loop workspaces or arbitrary `.loop` files, and it must not claim that Microsoft
Graph exposes Loop workspace or page creation APIs.

## Supported Architecture

Use the documented Microsoft model:

```text
Teams/Microsoft 365 host
        |
        | link unfurl or message-extension result
        v
Adaptive Card 1.6 with metadata.webUrl
        |
        | Action.Execute / refresh
        v
TypeScript bot or message-extension backend
        |
        v
Persistent component state
```

The component must be:

- **Live**: render current persisted state whenever it is opened or refreshed.
- **Actionable**: support a meaningful inline mutation through `Action.Execute`.
- **Embedded**: render completely inside the host.
- **Portable**: use a stable, unique HTTPS URL in `metadata.webUrl`.

## Workflow

### 1. Gather Only Missing Requirements

Extract requirements from the conversation first. If any required value is
missing, use `ask_user` once:

- Component name and purpose
- Fields users can view and edit
- Who may view and mutate the component
- Persistence choice: in-memory demo, SQLite, PostgreSQL, Azure Cosmos DB, or an
  existing repository-standard store
- Hosting target: local development, Azure App Service, Azure Container Apps,
  or an existing platform
- Whether to start a new project or modify an existing Teams/Microsoft 365 app

Default to:

- TypeScript with strict type checking
- The current Microsoft-recommended Teams/Microsoft 365 app scaffolder
- A repository abstraction with an in-memory development implementation
- Optimistic concurrency using a numeric version or ETag
- Teams-first local debugging plus Microsoft 365 manifest support

Do not ask for tenant IDs, app IDs, secrets, or deployment credentials until the
scaffold actually requires them. Never embed secrets in source or manifests.

### 2. Verify the Current Microsoft Toolchain

Before generating a new project, check the current Microsoft Learn guidance for
Adaptive Card-based Loop components and the current Teams/Microsoft 365
scaffolding command. Product tooling changes over time, so do not invent package
names, CLI flags, manifest schema versions, or SDK APIs from memory.

The implementation must preserve these platform requirements:

- Teams message extension with a search command
- Link unfurling for the component's canonical URL
- Universal Actions for Adaptive Cards
- `refresh.action.type` set to `Action.Execute`
- A stable and unique `metadata.webUrl`
- App manifest version 1.13 or later
- Microsoft 365 channel and SSO configuration when extending beyond Teams
- Adaptive Card version 1.6 unless current official guidance requires another
  version

If the official sample is archived, use it only to understand the protocol. Do
not copy its old dependency versions or obsolete SDK structure into a new app.

### 3. Scaffold the Application

For a new project:

1. Use the current official scaffolder rather than manually inventing the whole
   Teams project.
2. Select TypeScript and a message-extension-capable template.
3. Keep generated infrastructure files unless they conflict with the selected
   hosting target.
4. Inspect `package.json`, the app manifest, environment files, and generated
   handlers before editing.

For an existing project:

1. Read repository instructions first.
2. Locate the manifest, message-extension handlers, bot registration, Adaptive
   Card builders, routing, persistence, and tests.
3. Follow existing architecture and naming.
4. Make surgical changes rather than introducing a parallel framework.

Use `references/implementation-contract.md` as the minimum output contract.

### 4. Model Component State

Create explicit domain types. At minimum:

```ts
export interface ComponentState<TData> {
  id: string;
  version: number;
  updatedAt: string;
  updatedBy: string;
  data: TData;
}
```

Add a repository interface with `get`, `create`, and compare-and-set `update`
operations. A mutation must reject stale versions instead of silently
overwriting another user's changes.

For an in-memory demo store, state clearly that it is non-durable and unsuitable
for multi-instance production hosting. Keep the repository boundary so a durable
store can replace it without changing card or action handlers.

### 5. Build the Card

Generate the Adaptive Card from persisted state. Every rendered component must:

- Set `"type": "AdaptiveCard"` and a supported schema version
- Set `metadata.webUrl` to the canonical HTTPS component URL
- Include `refresh.action` using `Action.Execute`
- Include a meaningful inline action using `Action.Execute`
- Include the component ID and current version in action data
- Avoid a duplicate app header, duplicate border, or generic "Open in browser"
  button
- Avoid putting secrets or authorization decisions in card payloads
- Render clear validation and conflict messages inside the card

Use a canonical route such as:

```text
https://<public-host>/components/<component-id>
```

The same URL must:

- Identify one logical component
- Be accepted by the link-unfurl handler
- Resolve to a useful browser fallback
- Remain stable when the component state changes

### 6. Implement Handlers

Implement separate paths for:

- **Link unfurl**: parse and validate the canonical URL, authorize the caller,
  load state, and return the Loop-capable Adaptive Card.
- **Refresh**: authorize the caller, load current state, and return a newly
  rendered card.
- **Mutation**: validate typed inputs, authorize the operation, perform a
  compare-and-set update, and return the updated card.
- **Browser fallback**: display the same component or a useful authenticated
  detail view at `metadata.webUrl`.

Never trust user identity, component IDs, versions, or permissions supplied in
card action data. Derive identity from the authenticated request context and
validate access server-side.

Return explicit error cards for not found, forbidden, invalid input, and version
conflict cases. Do not turn failures into success-shaped responses.

### 7. Configure the App Manifest

Wire the generated app manifest for:

- Bot/message-extension registration
- Search command
- Link-unfurl URL domains
- `validDomains`
- App icon and concise app name
- Manifest schema/version required by current guidance
- Microsoft 365 support and SSO, when requested

Use placeholders or environment substitution for generated app IDs and host
names. Never commit credentials.

### 8. Add Tests

At minimum, test:

- Card output contains the expected `metadata.webUrl`
- Refresh action uses `Action.Execute`
- Canonical URL parsing accepts valid URLs and rejects foreign hosts or malformed
  IDs
- Unauthorized viewers and editors are rejected
- Invalid input is rejected
- Stale updates produce a version conflict
- Successful mutation persists state and returns the new version
- Link unfurl and refresh render equivalent current state

Prefer pure unit tests around state, URL parsing, card rendering, and action
dispatch. Add an integration test for the repository implementation where
practical.

### 9. Validate End to End

Run the repository's formatter, linter, type checker, targeted tests, and build.
Then verify:

1. The app starts locally.
2. A component record can be created.
3. Pasting its canonical URL triggers link unfurling.
4. The component can be copied through the host's component affordance.
5. An inline action updates persisted state.
6. Opening another instance shows the latest state after refresh.
7. A stale update does not overwrite a newer update.

If tenant sideloading, Teams Developer Portal access, or Entra consent blocks
interactive verification, finish all local validation and report the exact
manual step and blocker.

### 10. Deliver

Provide:

- Project location
- Architecture and persistence choice
- Commands to install, run, test, and package
- Environment variables and tenant setup still required
- Exact sideload/debug steps
- Current platform limitations that affect the requested clients

Do not claim production readiness when using in-memory persistence, placeholder
authorization, localhost URLs, or unverified tenant configuration.

## Hard Rules

- Build an Adaptive Card-based Loop component, not a native Loop page generator.
- Use current official Microsoft documentation as the source of truth.
- Prefer official scaffolding and repository patterns over handcrafted boilerplate.
- Treat archived Microsoft samples as behavioral references only.
- Require HTTPS and a stable `metadata.webUrl` outside local development.
- Enforce server-side authorization and optimistic concurrency.
- Never store secrets in Adaptive Cards, source files, or app manifests.
- Never silently lose concurrent edits.
- Do not use browser automation when the supported Adaptive Card model satisfies
  the request.

## Official References

- Adaptive Card-based Loop component:
  `https://learn.microsoft.com/microsoftteams/platform/m365-apps/cards-loop-component`
- Loop component design:
  `https://learn.microsoft.com/microsoftteams/platform/m365-apps/design-loop-components`
- Link unfurling:
  `https://learn.microsoft.com/microsoftteams/platform/messaging-extensions/how-to/link-unfurling`
- Universal Actions:
  `https://learn.microsoft.com/microsoftteams/platform/task-modules-and-cards/cards/universal-actions-for-adaptive-cards/work-with-universal-actions-for-adaptive-cards`

