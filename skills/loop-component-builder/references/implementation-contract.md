# Adaptive Card Loop Component Implementation Contract

Use this contract when creating or reviewing a generated project.

## Required Project Surfaces

```text
src/
  cards/
    buildComponentCard.ts
  components/
    componentModels.ts
    componentRepository.ts
    componentService.ts
  handlers/
    linkUnfurlHandler.ts
    refreshHandler.ts
    actionHandler.ts
  routes/
    componentPage.ts
  security/
    componentAuthorization.ts
  urls/
    componentUrl.ts
tests/
  buildComponentCard.test.ts
  componentUrl.test.ts
  componentService.test.ts
appPackage/
  manifest.json
```

Adapt names to the generated framework and repository conventions. Preserve the
separation between rendering, domain logic, persistence, authentication, and
transport handlers.

## Domain Types

```ts
export interface ComponentState<TData> {
  id: string;
  version: number;
  updatedAt: string;
  updatedBy: string;
  data: TData;
}

export interface UpdateComponentRequest<TData> {
  id: string;
  expectedVersion: number;
  data: TData;
}

export interface ComponentRepository<TData> {
  get(id: string): Promise<ComponentState<TData> | null>;
  create(state: ComponentState<TData>): Promise<void>;
  update(
    request: UpdateComponentRequest<TData>,
    actorId: string,
  ): Promise<ComponentState<TData>>;
}
```

Use a typed conflict error when `expectedVersion` does not match stored state.

## Canonical URL

```ts
export function componentUrl(baseUrl: URL, id: string): URL {
  if (!/^[A-Za-z0-9_-]{8,128}$/.test(id)) {
    throw new Error("Invalid component ID");
  }

  const url = new URL(baseUrl);
  url.pathname = `/components/${encodeURIComponent(id)}`;
  url.search = "";
  url.hash = "";
  return url;
}
```

Parsing must additionally validate the expected scheme and host. Do not accept an
arbitrary URL from action data.

## Card Shape

```json
{
  "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
  "type": "AdaptiveCard",
  "version": "1.6",
  "metadata": {
    "webUrl": "https://example.invalid/components/component-id"
  },
  "refresh": {
    "action": {
      "type": "Action.Execute",
      "verb": "component.refresh",
      "data": {
        "componentId": "component-id"
      }
    },
    "userIds": []
  },
  "body": [
    {
      "type": "TextBlock",
      "text": "Component title",
      "weight": "Bolder",
      "wrap": true
    },
    {
      "type": "Input.Text",
      "id": "value",
      "label": "Value"
    }
  ],
  "actions": [
    {
      "type": "Action.Execute",
      "title": "Save",
      "verb": "component.update",
      "data": {
        "componentId": "component-id",
        "expectedVersion": 1
      }
    }
  ]
}
```

Replace the body with the requested scenario. Keep the metadata, refresh, stable
identity, and concurrency fields.

## Handler Invariants

Every handler must:

1. Derive the caller identity from the authenticated activity/request.
2. Validate the verb and payload using a typed schema.
3. Validate the component ID and canonical host.
4. Authorize the caller for that component and action.
5. Load or update state through the service/repository.
6. Render a fresh card from authoritative state.
7. Map known failures to explicit user-facing error cards.
8. Log failures using repository-standard structured logging without exposing
   secrets or sensitive payloads.

## Production Readiness Checklist

- Durable store selected and migrations/provisioning documented
- Compare-and-set update implemented
- Authentication and per-component authorization implemented
- Public HTTPS endpoint configured
- Stable canonical URL configured
- Manifest IDs and domains populated through environment tooling
- SSO permissions use least privilege
- Inputs validated server-side
- Logs redact tokens and personal data
- Unit tests, type check, lint, and build pass
- Teams sideload and link-unfurl flow tested
- Refresh and cross-instance synchronization tested
- Platform/client limitations documented

