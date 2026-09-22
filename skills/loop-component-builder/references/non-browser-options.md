# Non-Browser Loop Creation Options

Check these in order and stop after finding a supported writable path.

## 1. Native Loop or Loop Web Service MCP

Look for connected operations equivalent to:

- `create-page-in-workspace`
- `modify-page`

Use them only when the tool schema is directly exposed. Discover and validate
the schema before invoking it. Do not guess arguments from documentation names.

## 2. WorkIQ

Search available entity paths for:

```text
loop|fluid|workspace|page
```

Use `create_entity` only when path discovery returns a writable Loop collection
and `get_schema` confirms the create request. WorkIQ search or chat knowledge
about an internal operation does not mean the operation is callable.

## 3. Teams

Teams tools may send an attachment with content type:

```text
application/vnd.microsoft.card.fluidEmbedCard
```

This embeds an **existing** `.loop` file URL. It does not create the file or
populate a new Loop page. Do not treat it as a creator.

## 4. Microsoft Graph and OneDrive

Graph and OneDrive can discover, copy, move, and share existing `.loop` files.
They do not expose a supported operation for generating arbitrary Loop page
content in the user's workspace. Do not upload guessed binary/text content with
a `.loop` extension.

## 5. SharePoint Embedded and Fluid Framework

These are valid for building a new collaborative application, but the result is
not a normal page in the user's Microsoft Loop workspace. Use only when the user
explicitly requests a custom application.

## Unsupported Approaches

- Undocumented Loop REST endpoints
- Reusing browser cookies or scraped access tokens
- Reverse-engineering restricted internal documentation
- Fabricating `.loop` file contents
- Claiming an Adaptive Card is a newly created Loop page

