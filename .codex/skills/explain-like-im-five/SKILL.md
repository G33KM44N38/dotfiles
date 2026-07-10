---
name: explain-like-im-five
description: Create a friendly, self-contained webpage that teaches a difficult idea in very simple language using concrete analogies, small visual steps, and playful interaction. Use when the user asks for an ELI5 explanation, says "explain it like I'm five," wants a topic taught visually in a webpage, or needs a beginner-friendly interactive explainer for technical, scientific, financial, or abstract material.
---

# Explain Like I'm Five

Turn the user's topic into a polished webpage that a curious beginner can understand and retell.

## Build the explanation

1. Identify the one central idea the learner should remember.
2. Start with a familiar real-world analogy. State where the analogy stops being exact when that matters.
3. Break the mechanism into three to five short steps. Introduce necessary vocabulary only after explaining the underlying idea in ordinary words.
4. Add one small interactive demonstration that changes something visible: a slider, toggle, draggable object, stepper, or simple simulation. Make the interaction teach the concept rather than merely decorate the page.
5. Finish with a compact recap: "The tiny version," followed by two or three sentences the learner could repeat to someone else.

Keep the explanation simple without making it false. Prefer short sentences, concrete nouns, examples, and cause-and-effect language. Avoid baby talk, condescension, unexplained jargon, and walls of text.

## Build the webpage

- Create a single self-contained HTML file with inline CSS and JavaScript unless the existing project clearly calls for its own stack.
- If the user does not specify a destination and no project is in scope, write the artifact to `/tmp/eli5-<topic>.html`.
- Give the page a strong visual hierarchy: one clear title, a brief promise, the analogy, the interactive demonstration, the steps, and the recap.
- Use warm, playful art direction, generous spacing, large readable type, and restrained animation. Do not make every section a floating card.
- Prefer diagrams made with HTML and CSS. Use SVG only when it materially clarifies the idea. Do not depend on external packages or network resources for a standalone page.
- Make the layout responsive and keyboard-friendly. Honor `prefers-reduced-motion`, preserve visible focus styles, use semantic HTML, and provide sufficient color contrast.
- Ensure the page still communicates its main lesson if JavaScript is unavailable.

## Verify and deliver

Open the page in an available browser, exercise every interaction, and check both a desktop and narrow viewport. Fix overflow, illegible text, broken controls, console errors, and misleading behavior before delivery.

Return a clickable link to the HTML file and one sentence describing what the learner can do on the page. Do not repeat the full lesson in chat; the webpage is the explanation.
