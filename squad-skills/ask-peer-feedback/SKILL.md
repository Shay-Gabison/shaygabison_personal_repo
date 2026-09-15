---
name: ask-peer-feedback
description: "Create a focused Outlook draft asking a peer for professional performance and growth feedback—not a code, document, PR, or artifact review. Grounds the request in the shared work, why this peer was selected, what the peer directly observed, and what the requester wants to learn. Use when the user says 'ask a peer for feedback', 'request feedback from a colleague', 'draft a feedback email', 'get feedback before Connect', or 'ask for feedback on my work'. After drafting, asks whether to notify the peer in Teams."
domain: productivity
confidence: high
---

# Ask a Peer for Focused Feedback

Create a concise, professional feedback request that makes it easy for a peer to
respond with specific, reliable observations. The request must be grounded in the
peer's actual experience with the user, not a generic request for praise.

## When to Use

- The user wants to ask a colleague or cross-team partner for feedback
- The user wants feedback after a project, milestone, incident, launch, or collaboration
- The user wants broader perspective before a Connect or career conversation
- A formal feedback tool is unavailable and the user wants to request feedback by email

Do not use this skill for reviewing a PR, design document, code change, or other
artifact. Those are review tasks, not professional peer-feedback requests.

## Principles

- **Ground the request in shared work.** Ask only about areas the peer directly observed.
- **Explain why this peer was selected.** Their vantage point should be clear.
- **Be specific and timely.** Name the project, interaction, milestone, or period while it is fresh.
- **Ask for balanced feedback.** Invite strengths, impact, and one or two growth suggestions.
- **Keep it easy to answer.** Use at most three focused prompts, not a long questionnaire.
- **Seek evidence, not endorsement.** Ask for examples and observed outcomes without leading the peer.
- **Respect the relationship.** Use a warm, direct tone and avoid performance-review pressure.
- **Act on feedback.** When appropriate, mention that the input will support reflection and growth.

## Workflow

### 1. Gather the Required Context

Use the `ask_user` tool. Do not draft the email until the user provides enough
context to make the request specific.

This skill is for **professional peer feedback**, not artifact review. Unless the
user explicitly mentions a document, PR, design, or code review, do not ask what
artifact should be reviewed. Ask about the shared work and the peer's observations.

Ask for these fields in one focused form:

| Field | Required | Guidance |
|---|---|---|
| **Peer alias** | Yes | Microsoft alias, email, or full name |
| **Shared-work background** | Yes | Project, milestone, incident, feature, recurring collaboration, or time period |
| **Why this peer** | Yes | What this person directly observed or which perspective they can provide |
| **Areas worked on together** | Yes | Concrete technical, execution, collaboration, leadership, customer, or business areas |
| **Feedback goal** | Yes | What the user wants to learn or improve |
| **Career level or growth direction** | No | Level, next-level goal, or scope the user is growing toward |
| **Tone** | No | Warm and concise by default; alternatives: formal, direct, appreciative |

Recommended `ask_user` form:

```json
{
  "message": "To make the feedback request focused and easy to answer, tell me what this peer directly observed.",
  "requestedSchema": {
    "properties": {
      "peerAlias": {
        "type": "string",
        "title": "Peer alias or email",
        "description": "The colleague who should receive the feedback request."
      },
      "sharedWork": {
        "type": "string",
        "title": "Shared-work background",
        "description": "What project, milestone, incident, feature, or period did you work on together?"
      },
      "whyThisPeer": {
        "type": "string",
        "title": "Why ask this peer?",
        "description": "What did this person directly observe, and what useful perspective can they provide?"
      },
      "areasWorkedTogether": {
        "type": "string",
        "title": "Areas you worked on together",
        "description": "List the specific technical, execution, collaboration, leadership, customer, or business areas they saw."
      },
      "feedbackGoal": {
        "type": "string",
        "title": "What do you want to learn?",
        "description": "For example: impact, technical leadership, collaboration, execution, communication, or growth opportunities."
      },
      "careerDirection": {
        "type": "string",
        "title": "Career level or growth direction (optional)",
        "description": "Include your level or the broader scope you are growing toward if you want career-aligned prompts."
      },
      "tone": {
        "type": "string",
        "title": "Email tone",
        "enum": ["Warm and concise", "Formal", "Direct", "Appreciative"],
        "default": "Warm and concise"
      }
    }
  }
}
```

If the user gives only a peer alias, stop and ask for the missing background.
Do not fill the email with invented context.

### 2. Select Focus Areas

Choose two or three prompts that match what the peer directly observed. Prefer:

- **Impact and outcomes** — what changed, improved, accelerated, or became clearer
- **Technical execution** — design, implementation, quality, reliability, troubleshooting
- **Ownership and delivery** — planning, ambiguity, end-to-end responsibility, follow-through
- **Collaboration and influence** — cross-team work, alignment, communication, unblocking others
- **Leadership and growth** — creating clarity, generating energy, mentoring, driving success
- **Engineering excellence** — maintainability, reviews, operational health, efficiency, cost

If the user provides a career level or growth direction, align the prompts to the
appropriate scope without mentioning confidential rubric language in the email:

- **Early-career scope:** independence, quality, learning, reliable delivery, collaboration
- **Feature/component leadership:** end-to-end ownership, design, ambiguity, operational health
- **Team/cross-team leadership:** technical clarity, influence, mentoring, measurable impact
- **Product/organization leadership:** strategy, broad alignment, durable systems, business outcomes

Never ask a peer to assess areas they could not reasonably have observed.

### 3. Draft the Email

Use the mail tool to create an Outlook draft. Never send it automatically.

Resolve the recipient from the supplied alias or email. If only a Microsoft alias
is supplied, use `<alias>@microsoft.com` when supported; if identity resolution is
ambiguous, ask the user rather than guessing.

Use this structure:

```text
Subject: Feedback on our work on <shared work>

Hi <peer first name>,

I appreciated working with you on <shared work>. Since you directly observed
<peer vantage point>, I would value your perspective.

When you have a moment, could you share:
- <focused prompt about an observed strength or contribution>
- <focused prompt about impact or outcome>
- <focused prompt about what to improve or do differently>

Specific examples would be especially helpful. I’m using the feedback to
understand my impact and identify where I can continue to grow.

Thanks,
<requester name>
```

Adapt the wording naturally:

- Do not repeat the same context in multiple paragraphs.
- Keep the body around 100-170 words unless the user requests otherwise.
- Use exactly two or three focused questions. Consolidate overlapping areas rather
  than turning every requested topic into a separate question.
- Do not ask for only positive feedback.
- Do not mention promotion, rewards, or calibration unless the user explicitly asks.
- Do not claim the peer observed something that the user did not provide.
- If the formal feedback tool is unavailable, one short sentence may explain that;
  do not make tool retirement the main reason for the request.

Create the draft using plain text or simple Outlook-safe HTML. Report that it is
saved as a draft and has not been sent.

### 4. Offer a Teams Notification

Only after the email draft is created, use `ask_user`. At this stage, ask only
whether the user wants a Teams notification; do not compose or send the Teams
message before the user opts in.

The user-facing question must mean:

> Would you like me to notify `<peer>` in Teams after you send the email?

Do not ask to send the feedback request itself in Teams. Do not ask to create a
"Teams version" of the email. Teams is only a brief notification that the email
request was sent.

```json
{
  "message": "The feedback email is saved as a draft. Would you like me to notify the peer in Teams after you send it?",
  "requestedSchema": {
    "properties": {
      "notifyInTeams": {
        "type": "boolean",
        "title": "Notify the peer in Teams",
        "description": "Send a short note that you requested feedback by email.",
        "default": false
      }
    }
  }
}
```

If the user says yes:

1. Confirm that the email has actually been sent. If not, tell the user to send it
   first or ask whether they want the Teams note to say that an email draft is coming.
2. Check the peer's presence with the Teams presence tool.
3. Send a short, low-pressure message:

```text
Hi <first name>, I’ve sent you a short email asking for feedback on our work on
<shared work>. I’d really value your perspective when you have a chance. Thanks!
```

Do not send an urgent or high-importance Teams message.

## Hard Interaction Gates

These gates override any pressure to complete the workflow in one step:

1. **Insufficient context:** If shared work, why this peer, observed areas, or the
   feedback goal is missing, gather it before drafting.
2. **Email boundary:** Create an Outlook draft only. Never send the feedback request.
3. **Teams boundary:** After creating the draft, ask a yes/no opt-in question. Do
   not replace the opt-in with a proposed Teams message. The question must be
   "Would you like me to notify `<peer>` in Teams after you send the email?"
4. **Sent-status boundary:** If the user opts in to Teams, confirm the email was
   sent before saying "I sent you an email."
5. **Question limit:** The final email must contain no more than three feedback
   questions, even if the user lists many focus areas.

## Quality Check Before Creating the Draft

Confirm all of the following:

- The email identifies the shared work
- The reason this peer is a credible feedback source is clear
- Every question maps to something the peer directly observed
- The request asks for specific examples
- The wording invites both strengths and growth feedback
- The email is concise and does not feel like a performance-review form
- No facts, outcomes, or relationship details were invented

## Examples

### Strong Context

**Input:** Peer worked with the user during an NSP readiness rollout, observed the
user creating an AI skill and coordinating multiple teams, and can comment on
cross-team clarity, usefulness, and improvement opportunities.

**Good prompts:**

- Which parts of the approach were most useful to your team, and why?
- How effectively did I create clarity and coordinate across teams?
- What could I change to make similar contributions more useful or easier to adopt?

### Weak Context

**Input:** "Ask Alex for feedback."

**Required response:** Ask for the project or interaction, why Alex is the right
person, what Alex observed, and what the user wants to learn. Do not draft a
generic email yet.

## Source Basis

This workflow is distilled from Microsoft guidance that feedback should be regular,
timely, specific, simple, rooted in the flow of work, and used for growth. Its focus
areas are generalized from software-engineering expectations across increasing
levels of technical scope, ownership, impact, collaboration, and leadership.
