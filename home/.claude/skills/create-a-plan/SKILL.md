---
name: create-a-plan
description: Create a plan for a specific request with me, with back-and-forth.
---

<what-to-do>

Interview me relentlessly about a feature I want to add or any other task that I'm asking for. Do
this until we reach a shared understanding. Walk down each branch of the design tree, resolving
dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time, waiting for feedback on each question before continuing.

If a question can be answered by exploring the codebase, explore the codebase instead.

## Finishing the plan

Once we reach a shared understanding, ask for approval with a structured prompt that contains the
whole agreed plan. Never ask in prose ("say the word", "want me to go ahead?").

The plan must be in the tool call's arguments. Text in your thinking is never shown to me, and a
message before the call is easy to skip, so don't rely on either. Never refer to "the plan above".

- In Plan mode, call `exit_plan_mode` with a concise summary of the plan.
- In any other mode, call `ask_user_question` with a single question, header "Implement", and
  exactly these two options in this order:
  1. "Go ahead": implement the plan as agreed.
  2. "Not yet": keep refining the plan.

  The question's first line is "Implement this plan?". After a blank line, write the full agreed
  plan as Markdown: what changes and where, the decisions we made, and how it will be verified. Use
  headings and bullet lists. The first line is the question's title, and the rest is shown as the
  plan. Don't repeat the plan in a separate message.

  The tool adds an "Other" free-text option automatically for feedback. On "Go ahead", start
  implementing. On "Not yet" or "Other", address the feedback, continue the interview, and ask
  again with the same prompt once the plan is agreed.

</what-to-do>

<supporting-info>

## During the session

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical term. "You're saying
'account' — do you mean the Customer or the User? Those are different things."

### Discuss concrete scenarios

When domain relationships are being discussed, stress-test them with specific scenarios. Invent
scenarios that probe edge cases and force the user to be precise about the boundaries between
concepts.

### Cross-reference with code

When the user states how something works, check whether the code agrees. If you find a
contradiction, surface it: "Your code cancels entire Orders, but you just said partial cancellation
is possible — which is right?"

</supporting-info>
