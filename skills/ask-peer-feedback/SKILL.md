---
name: ask-peer-feedback
description: "Create a focused Outlook draft asking a peer for professional performance and growth feedback—not a code, document, PR, or artifact review. Grounds the request in shared work and direct observations, and calibrates prompts to the requester's required career level. Use when the user says 'ask a peer for feedback', 'request feedback from a colleague', 'draft a feedback email', 'get feedback before Connect', or 'ask for feedback on my work'. After drafting, asks whether to notify the peer in Teams."
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

Minimize user questions. First extract all usable context from the request,
pasted conversations, attachments, and prior turns. Do not ask the user to
repeat, summarize, or confirm information that is already available.

This skill is for **professional peer feedback**, not artifact review. Unless the
user explicitly mentions a document, PR, design, or code review, do not ask what
artifact should be reviewed. Ask about the shared work and the peer's observations.

The minimum context needed to draft is:

- **Peer identity**
- **Current career level or role scope**
- **Shared work**
- **At least one credible observation area**

Infer the observation area from supplied evidence whenever reasonable. For
example, a conversation about rollout decisions, troubleshooting, and dependency
coordination supports prompts about technical clarity, execution, and cross-team
collaboration. This is not inventing context; it is summarizing what the user
provided.

Use these defaults unless the user says otherwise:

- **Feedback goal:** understand impact, strengths, and where to improve or grow
- **Tone:** warm and concise
- **Growth prompt:** "Are there any areas where I could improve or grow further?"

Do not ask separately for "why this peer," "areas worked together," feedback
goal, or tone when they can be inferred or safely defaulted. Career level is the
exception: it must be explicitly provided and must not be inferred. Do not ask
the user to confirm your inferred perspective before drafting.

If required context is still missing, use `ask_user` exactly once with only the
missing fields. Prefer one compact free-text context field over a questionnaire:

```json
{
  "message": "I only need the missing context below to make the feedback request specific.",
  "requestedSchema": {
    "properties": {
      "peerAlias": {
        "type": "string",
        "title": "Peer alias or email",
        "description": "Include only if it was not already provided."
      },
      "careerLevel": {
        "type": "string",
        "title": "Current career level or role scope",
        "description": "For example: Software Engineer II, Senior, Principal, level number, or the scope you currently own. Include only if it was not already provided."
      },
      "context": {
        "type": "string",
        "title": "Shared work and what they observed",
        "description": "Briefly name the project or interaction and what this peer directly saw."
      }
    }
  }
}
```

Omit any field already answered. If several peers share the same work, ask once
for shared context and allow peer-specific differences in the same field. Never
split missing context into multiple follow-up forms unless the user's answer is
genuinely unusable.

If the user gives only a peer alias and no usable prior context, ask once for the
shared work and what the peer observed. Do not draft a generic email or invent
context.

### 2. Select Focus Areas

Choose two or three prompts that match what the peer directly observed. Prefer:

- **Impact and outcomes** — what changed, improved, accelerated, or became clearer
- **Technical execution** — design, implementation, quality, reliability, troubleshooting
- **Ownership and delivery** — planning, ambiguity, end-to-end responsibility, follow-through
- **Collaboration and influence** — cross-team work, alignment, communication, unblocking others
- **Leadership and growth** — creating clarity, generating energy, mentoring, driving success
- **Engineering excellence** — maintainability, reviews, operational health, efficiency, cost

Use the required career level to align the prompts to the appropriate scope
without mentioning the level or confidential rubric language in the email:

- **Early-career scope:** independence, quality, learning, reliable delivery, collaboration
- **Feature/component leadership:** end-to-end ownership, design, ambiguity, operational health
- **Team/cross-team leadership:** technical clarity, influence, mentoring, measurable impact
- **Product/organization leadership:** strategy, broad alignment, durable systems, business outcomes

Never ask a peer to assess areas they could not reasonably have observed.
Career level calibrates the scope of the questions; it is not itself disclosed
or presented as something the peer should evaluate.

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
- Are there any areas where I could improve or grow further?

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
- Default to two evidence-based strength/impact prompts and one simple growth
  prompt. If the user explicitly requests positive-only feedback, honor that by
  replacing the growth prompt with a question about strengths to continue.
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

1. **Insufficient context:** Ask only when peer identity, current career level,
   shared work, or any credible observation area is missing. Ask once for only
   what is missing. Career level must be supplied explicitly; feedback goal and
   tone have defaults.
2. **Email boundary:** Create an Outlook draft only. Never send the feedback request.
3. **Teams boundary:** After creating the draft, ask a yes/no opt-in question. Do
   not replace the opt-in with a proposed Teams message. The question must be
   "Would you like me to notify `<peer>` in Teams after you send the email?"
4. **Sent-status boundary:** If the user opts in to Teams, confirm the email was
   sent before saying "I sent you an email."
5. **Question limit:** The final email must contain no more than three feedback
   questions, even if the user lists many focus areas.
6. **No redundant confirmation:** Do not ask the user to approve an inferred
   peer perspective, email wording, or default feedback goal before creating the
   draft. The user can revise the draft afterward.

## Quality Check Before Creating the Draft

Confirm all of the following:

- The email identifies the shared work
- The reason this peer is a credible feedback source is clear
- Every question maps to something the peer directly observed
- The question scope is calibrated to the user's stated career level
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

**Required response:** Ask for the user's current career level, the project or
interaction, why Alex is the right person, what Alex observed, and what the user
wants to learn. Do not draft a generic email yet.

## Source Basis

This workflow is distilled from Microsoft guidance that feedback should be regular,
timely, specific, simple, rooted in the flow of work, and used for growth. Its focus
areas are generalized from software-engineering expectations across increasing
levels of technical scope, ownership, impact, collaboration, and leadership.
