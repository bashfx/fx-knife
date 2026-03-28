# Part VII: General Principles for AI-Assisted Development



1.  **Principle of Verifiable Output:** The user can provide a mechanism for the AI to see the **raw, unfiltered result** of its own work (e.g., a stack trace, a `set -x` log, a screenshot). This is the only verifiable way to bridge the gap between the AI's "intended" output and the real-world outcome.

2.  **Principle of Iterative Refinement:** Assume the first attempt will be flawed. The optimal workflow is not to strive for a perfect "one-shot" generation, but to create a rapid feedback loop of **propose -> test -> refute -> correct**. The goal is velocity, not immediate perfection.

3.  **Principle of Explicit Scoping:** The user must strictly define the **boundaries of the current task**. "Generate Part I only," "Propose the outline first," "Fix only this function." This prevents the AI from propagating a flawed assumption across the entire codebase.

4.  **Principle of User Override:** The user's manual correction is always the **definitive source of truth**. It is not a suggestion; it is a direct update to the project's implicit specification. The AI's immediate job is to understand the *pattern* behind the correction and decide whether to implment it globally (vs isolated change).

5.  **Principle of Shared Understanding:** The process of co-creating a living document (like `ARCHITECTURE.md`) is as important as the code itself. This document becomes the **shared mental model** and the ultimate arbiter when a design decision is questioned.

6.  **Principle of Abstraction Discovery:** When a bug is fixed repeatedly with a similar solution, it's a signal that a new **abstraction is needed**. The AI should be prompted to recognize this pattern and propose a new, reusable helper function or principle to solve that entire class of problem.

7.  **Principle of Directness:** Ambiguity is the enemy of efficiency. Direct, concise, and even blunt feedback from the user is the fastest way to correct the AI's course. Politeness is less important than clarity.

8.  **Principle of Environmental Assumption:** The AI must **explicitly state its assumptions** about the environment in which its code will run (e.g., "Assuming this will be piped to a tool that handles newlines," "Assuming this test will run non-interactively"). This allows the user to immediately correct any flawed environmental assumptions.

9.  **Principle of the "Why":** The most valuable user feedback often goes beyond *what* is wrong and explains *why* it is wrong from a higher-level, architectural perspective. This allows the AI to update its core reasoning model, not just the last line of code it wrote.

10. **Principle of the Cool-Down:** Recognizing points of success and taking a moment to reflect (like our `sleep 7000`) is a crucial part of the process. It allows for the consolidation of lessons learned and prevents burnout/corruption in long, complex sessions.


--- END OF FILE ARCHITECTURE.md --
