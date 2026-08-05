# IcM On-Call Configuration

This file defines the project-specific IcM teams the `icm-oncall` skill scrapes. Fill in every
`{{PLACEHOLDER}}` and add one row per team you want in the on-call list. Keep this file next to
the skill's `SKILL.md` (in the installed `templates/` directory) so the skill loads it
automatically.

## Default service

```
Default serviceId: {{DEFAULT_SERVICE_ID}}   # The IcM serviceId used for every team unless the team overrides it below. Find it in the IcM portal URL when viewing your service's on-call.
```

## Team registry

Add one row per team you want on the list. `Team ID` is the IcM team id (one per request — see
SKILL.md). `serviceId override` is optional; leave blank to use the default above.

| Team ID | Team Name | IcM Queue | serviceId override |
|---------|-----------|-----------|--------------------|
| `{{TEAM_ID_1}}` | `{{TEAM_NAME_1}}` | `{{TEAM_QUEUE_1}}` | `{{TEAM_SERVICE_ID_OVERRIDE_1}}` |
| `{{TEAM_ID_2}}` | `{{TEAM_NAME_2}}` | `{{TEAM_QUEUE_2}}` | |

<!-- Add one row per team the project tracks. The `serviceId override` column is only needed for
     teams that live under a different service than the default (e.g. a Gov/Fairfax service id).
     Leave it blank to inherit the default serviceId. -->

## Notes

- Replace all `{{TEMPLATE_VARIABLES}}` with your actual values.
- Use one `Team ID` per row; comma-separated IDs are not supported (the portal returns
  `teamIds=NaN`).
- `skills-config` writes back to this same path, so re-running configuration updates this file
  in place.
