# External research sweep — 2026-08-17

Scope: published research on the effectiveness of repository context files and
documentation written for AI coding agents, beyond the supplied dedupe set
(arXiv:2602.11988, 2602.12670, 2603.15401, 2509.21051, 2307.03172, 2505.13360,
2509.14404, FormatSpread, IFEval++). Every entry below was opened with WebFetch;
quotes are verbatim from the fetched page.

## Query ledger

1. `AGENTS.md repository context file coding agent effectiveness empirical study` → yielded: 6 entries (2607.27250, 2511.12884, 2605.10039, 2606.20512, 2606.12231, 2606.15828)
2. `README content categorization empirical study Prana developer onboarding` → yielded: 3 entries (Prana et al., 2206.10772, 2603.00489)
3. `"Categorizing the Content of GitHub README Files" arXiv Prana Treude` → yielded: 1 entry (resolved Prana et al. to arXiv:1802.06997 after Springer paywalled)
4. `documentation code drift detection outdated documentation LLM benchmark 2026` → yielded: 1 entry (2604.03447)
5. `LLM-generated README evaluation versus human-written repository summarization benchmark` → yielded: nothing (results were generic summarization benchmarks, not repo docs)
6. `hallucination rate LLM generated code documentation grounding citation attribution study` → yielded: 1 entry (2512.12117); the rest were scientific-citation hallucination, out of scope
7. `automatic README generation LLM evaluation "README" generated repository documentation quality study arxiv` → yielded: 2 entries (2606.30524, 2510.24428)
8. `context length degradation long context agent instruction following many instructions effect 2026 arxiv` → yielded: 1 entry (2607.25398)
9. `Anthropic Claude Code CLAUDE.md best practices documentation memory specification` → yielded: 2 entries (Anthropic skill-authoring best practices, agents.md spec via follow-up fetch)
10. `Lulla 2026 curated AGENTS.md agent efficiency runtime output tokens pull requests study` → yielded: 1 entry (2601.20404)
11. `newcomer onboarding barriers open source documentation empirical study controlled experiment README quality` → yielded: nothing (systematic reviews and good-first-issue work; nothing isolating README content as the manipulated variable)
12. `717 GitHub repositories README quality community health newcomer contributors empirical study arxiv` → yielded: nothing (the 717-repository study referenced in a search snippet could not be resolved to a source; UNRESOLVED, not recorded)
13. `code comment inconsistency detection outdated comments empirical study prevalence percentage` → yielded: 1 entry (2212.01479). Wen et al. 2019 (ICPC, code-comment co-evolution) could not be opened — the USI PDF returned HTTP 403 and IEEE/ACM are paywalled; NOT recorded.

## Findings

### Context files do not move correctness in a two-agent controlled ablation
- **Topic:** 1
- **Claim:** Across 288 evaluated runs on two frontier agents, context-injection strategy produced no measurable correctness effect, bounded to ≤10–15pp by equivalence testing, and failures were attributed to implementation skill rather than missing repository knowledge.
- **Quote:** "We present a controlled ablation of context-injection strategy across two frontier agents (Claude Code and Codex), 17 real tasks from 3 repositories (15 shared + 2 Codex-only), and 288 evaluated runs with gold-test evaluation. Context strategy does not measurably move correctness on either agent (bounded to <=10-15pp via equivalence testing). A failure-mode triage reveals why: agents fail on implementation skill---feature design, pattern selection, exact wiring---not missing repository knowledge that a context file could supply; a manipulation probe confirms the real AGENTS.md never converts a near-miss to a pass on either agent."
- **Source:** Prakhar Khatri, "Do Context Files Help Coding Agents? A Two-Agent Ablation Study on Real Repositories", arXiv preprint, 28 July 2026 — arXiv:2607.27250
- **Opened:** yes (WebFetch) — abstract page
- **Relevance:** Directly constrains what Cartographer can claim: generated context is not a correctness lever, so the value proposition must be framed around efficiency, onboarding, and convention adherence, not task success.

### Context files are configuration-like artifacts skewed to functional content
- **Topic:** 1, 5
- **Claim:** In 2,303 context files from 1,925 repositories, developers overwhelmingly document test procedures, implementation details, and architecture, while security and performance instructions appear in under 15% of files.
- **Quote:** "In this paper, we conduct the first large-scale empirical study of 2,303 agent context files from 1,925 repositories to characterize their structure, maintenance, and content. We find that these files are not static documentation but complex, difficult-to-read artifacts that evolve like configuration code through frequent, small additions. Our content analysis of 16 instruction types shows that developers prioritize functional context, such as test procedures (75.9%), implementation details (70.8%), and architecture (68.1%). We also identify a significant gap: non-functional requirements such as security (14.8%) and performance (14.5%) are rarely specified."
- **Source:** Chatlatanagulchai, Li, Kashiwa, Reid, Thonglek, Leelaprute, Rungsawang, Manaskasemsak, Adams, Hassan, Iida, "Agent READMEs: An Empirical Study of Context Files for Agentic Coding", arXiv, submitted 17 Nov 2025, v2 9 Aug 2026 — arXiv:2511.12884
- **Opened:** yes (WebFetch) — abstract page
- **Relevance:** Gives Cartographer an empirical content prior for what to emit (tests, implementation, architecture) and an evidence-backed gap to fill (security/performance guardrails), plus the "evolves like config code" framing for the refresh path.

### File-structure variables show no detectable effect on instruction adherence; compliance decays within a session
- **Topic:** 1, 5
- **Claim:** A factorial study over 1,650 Claude Code sessions found no detectable adherence effect from file size, instruction position, file architecture, or contradictions in adjacent files, while each additional generated function was associated with ~5.6% lower odds of compliance within the session.
- **Quote:** "We report a systematic factorial study of these choices using four manipulated variables, measuring compliance with a trivial target annotation across 1,650 Claude Code CLI sessions (16,050 function-level observations) on two TypeScript codebases, three frontier models... None of the four structural variables or three two-way interactions produces a detectable contrast after multiple-testing correction. Size and conflict nulls are supported by affirmative-null Bayes factors (BF10 between 0.05 and 0.10); position and architecture nulls are failures to reject without Bayes-factor support. The largest effect we measured is within-session: each additional function the agent generates is associated with approximately 5.6% lower odds of compliance per step (OR = 0.944) within the session-length range we tested, though the relationship is non-monotonic rather than a constant per-step effect."
- **Source:** Damon McMillan, "Instruction Adherence in Coding Agent Configuration Files: A Factorial Study of Four File-Structure Variables", arXiv preprint, 11 May 2026 — arXiv:2605.10039
- **Opened:** yes (WebFetch) — abstract page
- **Relevance:** Undercuts formatting-obsessed context-file design (ordering, size, splitting) as a differentiator; suggests Cartographer should not over-invest in structural micro-optimization and that adherence decay is a session-length property, not a file property.

### Configuration smells are widespread in AGENTS.md/CLAUDE.md files
- **Topic:** 1
- **Claim:** In 100 popular open-source repositories with an AGENTS.md or CLAUDE.md, lint leakage affected 62% of files, context bloat 42%, and skill leakage 35%.
- **Quote:** "To evaluate the prevalence of the proposed smells, we analyzed 100 popular open-source repositories containing either an AGENTS.md or a CLAUDE.md file. Our results show that configuration smells are widespread. Lint Leakage was the most common smell, affecting 62% of the files, followed by Context Bloat (42%) and Skill Leakage (35%). We further show that several smells frequently co-occur, particularly Context Bloat, Skill Leakage, and Conflicting Instructions."
- **Source:** dos Santos, Costa, Montandon, Silva, Valente, "Configuration Smells in AGENTS.md Files: Common Mistakes in Configuring Coding Agents", arXiv, submitted 14 June 2026, revised 30 July 2026 — arXiv:2606.15828
- **Opened:** yes (WebFetch) — abstract page
- **Relevance:** A ready-made quality checklist for Cartographer's quality-check lane: named, detectable anti-patterns (lint leakage, context bloat, skill leakage, conflicting instructions) with published base rates to compare against.

### Iteratively tuned repository guidance raises SWE-bench Verified resolve rate
- **Topic:** 1
- **Claim:** Probe-and-refine tuning of a repository guidance file raised mean resolve rate to 33.0% versus 28.3% for a static knowledge base and 25.5% unguided (p<0.001 for both contrasts) on SWE-bench Verified with Qwen3.5-35B-A3B.
- **Quote:** "On SWE-bench Verified across four independent trials with Qwen3.5-35B-A3B at 200 steps, probe-and-refine achieves 33.0 % mean resolve rate vs. 28.3 % for the static knowledge base used to initialize it and 25.5 % for an unguided baseline (p<0.001 for both probe-and-refine contrasts)."
- **Source:** Asa Shepard, Jeannie Albrecht, "Probe-and-Refine Tuning of Repository Guidance for Coding Agents", arXiv preprint, submitted 18 June 2026, revised 19 June 2026 — arXiv:2606.20512
- **Opened:** yes (WebFetch) — HTML full text (abstract section)
- **Relevance:** The strongest counterweight to the null results: guidance quality, produced by an iterative probe loop rather than one-shot generation, does move task success. Argues for Cartographer having a refine/verify loop rather than a single generation pass.

### Updating rule files measurably improves artifact compliance
- **Topic:** 1, 5
- **Claim:** Across 160 rule-evolution events mined from AI IDE projects, average artifact compliance rose from 49.14% to 72.13% (+22.99pp) after a rule update; developers report editing rules mainly to correct AI errors (77.78%).
- **Quote:** "By mining 83 open-source projects and extracting 7,310 rules, we established a comprehensive taxonomy comprising 5 primary and 25 secondary categories. We then triangulated these artifacts with survey responses from 99 practitioners. Our analysis identified a contrast between developer priorities and actual configurations: while practitioners rate architectural constraints as highly important, rule files in repositories primarily consist of low-level workflow and code formatting constraints. Furthermore, our analysis of 1,540 rule evolution events revealed that rules are updated frequently. Repository data further indicate that rule evolution is primarily driven by constructive context expansions (29.17%) and enrichments (26.59%). In contrast, surveyed developers reported modifying rules primarily to correct AI errors (77.78%), typically by adding new negative constraints rather than editing existing ones. Finally, an artifact compliance assessment of 160 rule evolution events revealed that updating rules significantly improves the adherence of software artifacts, with the average artifact compliance rate increasing by 22.99% (from 49.14% to 72.13%) following an update."
- **Source:** Cai, Li, Liang, Li, Shahin, "Rule Taxonomy and Evolution in AI IDEs: A Mining and Survey Study", arXiv preprint, 10 June 2026 — arXiv:2606.12231
- **Opened:** yes (WebFetch) — abstract page
- **Relevance:** Evidence that context files earn their keep on adherence (not correctness), and that the mismatch between what developers value (architecture) and what files contain (formatting/workflow) is a gap Cartographer can target in content selection.

### AGENTS.md presence reduces agent runtime and output tokens
- **Topic:** 1
- **Claim:** Over 10 repositories and 124 pull requests, presence of an AGENTS.md was associated with 28.64% lower median runtime and 16.58% lower output token consumption, with comparable task completion behavior.
- **Quote:** "We analyze 10 repositories and 124 pull requests, executing agents under two conditions: with and without an AGENTS.md file. We measure wall-clock execution time and token usage during agent execution. Our results show that the presence of AGENTS.md is associated with a lower median runtime (Δ28.64%) and reduced output token consumption (Δ16.58%), while maintaining a comparable task completion behavior."
- **Source:** Lulla, Mohsenimofidi, Galster, Zhang, Baltes, Treude, "On the Impact of AGENTS.md Files on the Efficiency of AI Coding Agents", arXiv, submitted 28 Jan 2026, revised 30 Mar 2026 — arXiv:2601.20404
- **Opened:** yes (WebFetch) — abstract page
- **Relevance:** Supplies the defensible efficiency claim for Cartographer's value proposition — cost and latency, explicitly not correctness — and pairs cleanly with the 2607.27250 null.

### README content skews to "What" and "How"; purpose and status are commonly absent
- **Topic:** 2
- **Claim:** Manual annotation of 4,226 README sections from 393 randomly sampled GitHub repositories found "What" and "How" content very common and purpose/status information frequently missing; the eight-category multi-label classifier reached F1 0.746 and section labeling was perceived by a majority of 20 professionals as easing information discovery.
- **Quote:** "To close this gap, we conduct a qualitative study involving the manual annotation of 4,226 README file sections from 393 randomly sampled GitHub repositories and we design and evaluate a classifier and a set of features that can categorize these sections automatically. We find that information discussing the `What' and `How' of a repository is very common, while many README files lack information regarding the purpose and status of a repository. Our multi-label classifier which can predict eight different categories achieves an F1 score of 0.746. ... The majority of participants perceived the automated labeling of sections based on our classifier to ease information discovery."
- **Source:** Prana, Treude, Thung, Atapattu, Lo, "Categorizing the Content of GitHub README Files", arXiv Feb 2018 / Empirical Software Engineering 2019 — arXiv:1802.06997
- **Opened:** yes (WebFetch) — abstract page
- **Relevance:** The canonical content taxonomy for README generation, and the empirical gap (purpose/status) that a Cartographer-authored README can deliberately fill rather than duplicating what humans already write.

### README structural features correlate with project popularity
- **Topic:** 2
- **Claim:** Across 1,950 READMEs spanning ten languages, popular projects' READMEs were well organized with lists and images and contained external links; contribution guidelines and references were associated with higher popularity.
- **Quote:** "We perform the study on 1950 readme files of public GitHub projects, spanning across ten programming languages, and observe that readme files in majority of the popular projects are well organised using lists and images, and comprise links to external sources. Also, repositories with readme files containing contribution guidelines and references were observed to be associated with higher popularity."
- **Source:** Venigalla, Chimalakonda, "An Empirical Study On Correlation between Readme Content and Project Popularity", arXiv, 21 June 2022 — arXiv:2206.10772
- **Opened:** yes (WebFetch) — abstract page
- **Relevance:** Weak (correlational, popularity not onboarding) but the only quantitative signal found tying specific README features to an outcome; useful as a tiebreaker for structural choices, not as a causal claim.

### README updates are rare in PRs and a fifth of "no-update" PRs actually warranted one
- **Topic:** 3
- **Claim:** Over 27,772 PRs from 714 repositories, only 0.8% of PRs modified the README, and 21.5% of the system's recommendations on PRs that did not update the README were judged valid updates overlooked during development.
- **Quote:** "only 0.8% of all PRs in the dataset involving modifications to the README file" / "21.5% of recommendations for PRs lacking immediate README updates were actually valid suggestions overlooked during development" / "the agentic version achieving a near-perfect Specificity (98.7%) and a User-Facing Accuracy of 28.7%"
- **Source:** Gao, Lin, Treude, Gay, Zahedi, "Does My README File Need To Be Updated? Exploring LLM-Based README Maintenance", arXiv, 28 Feb 2026 — arXiv:2603.00489
- **Opened:** yes (WebFetch) — HTML full text (results sections) plus abstract page
- **Relevance:** Quantifies Cartographer's staleness premise (READMEs almost never move with code, and a measurable fraction of changes silently should have) and sets a sober precision bar — best user-facing accuracy was 28.7%, so a staleness detector should be advisory, high-specificity, human-in-the-loop.

### LLMs detect documentation faults but are blind to implementation-only drift
- **Topic:** 3
- **Claim:** Across 22,339 responses from seven LLMs on 456 Java method bundles, models detected documentation faults at 67–94% but detection fell 21–43 percentage points when only the implementation changed and the documentation stayed intact.
- **Quote:** "Using 22,339 valid responses from seven LLMs on 456 method bundles, we find that quality penalties are generally localized to the perturbed artifact and increase with fault severity. However, models exhibit a consistent source-origin asymmetry: they detect documentation faults at 67-94% and explicit documentation-implementation contradictions at 50-91%, but detection falls by 21-43 percentage points when only the implementation changes while documentation remains intact. Models also struggle to deprioritize faulty implementations, and confidence provides little separation between correct and incorrect judgments for six of seven models."
- **Source:** Ulfat, Sabit, Hossain, "Measuring LLM Trust Allocation Across Conflicting Software Artifacts", arXiv, submitted 3 Apr 2026, revised 21 July 2026 — arXiv:2604.03447
- **Opened:** yes (WebFetch) — abstract page
- **Relevance:** The single most important constraint on a Cartographer drift check: an LLM asked "is this doc stale?" is systematically weakest at exactly the drift direction that matters (code moved, doc didn't). Drift detection needs deterministic anchors (symbol/path existence), not model judgment. Also: model confidence is not a usable filter.

### Outdated code element references are near-universal in repository documentation
- **Topic:** 3
- **Claim:** Analysis of over 3,000 GitHub projects found that most projects contain at least one code element reference surviving in documentation after all source instances were deleted, at some point in their history.
- **Quote:** "In this work, we analysed over 3,000 GitHub projects and found that most projects contain at least one outdated code element reference at some point in their history. We submitted GitHub issues to real-world projects containing outdated references detected by our approach, some of which have already led to documentation fixes."
- **Source:** Tan, Wagner, Treude, "Detecting Outdated Code Element References in Software Repository Documentation", arXiv, 2 Dec 2022 — arXiv:2212.01479
- **Opened:** yes (WebFetch) — abstract page
- **Relevance:** Validates the cheapest, most defensible staleness signal available to Cartographer — dangling code-element references detectable without model judgment — and provides prevalence evidence that the check will fire on real repos.

### Citation-grounded retrieval reaches 92% citation accuracy on code comprehension
- **Topic:** 4
- **Claim:** Across 30 Python repositories and 180 developer queries, a hybrid retrieval plus graph-expansion architecture reported 92% citation accuracy with zero hallucinations, with cross-file evidence discovery identified as the largest contributor to citation completeness.
- **Quote:** "Our work is grounded in systematic evaluation across 30 Python repositories with 180 developer queries, comparing retrieval modalities, graph expansion strategies, and citation verification mechanisms. We find that challenges of citation accuracy arise from the interplay between sparse lexical matching, dense semantic similarity, and cross file architectural dependencies. Among these, cross file evidence discovery is the largest contributor to citation completeness, but it is largely overlooked because existing systems rely on pure textual similarity without leveraging code structure. We advocate for citation grounded generation as an architectural principle for code comprehension systems and demonstrate this need by achieving 92 percent citation accuracy with zero hallucinations."
- **Source:** Jahidul Arafat, "Citation-Grounded Code Comprehension: Preventing LLM Hallucination Through Hybrid Retrieval and Graph-Augmented Context", arXiv, 13 Dec 2025 — arXiv:2512.12117
- **Opened:** yes (WebFetch) — abstract page
- **Relevance:** Supports making every Cartographer claim carry a file/symbol citation, and warns that pure text similarity misses cross-file architectural evidence — the exact evidence an architecture section needs. Caveat: single-author preprint, self-reported "zero hallucinations", no independent replication.

### Long standing-instruction documents are followed poorly over extended tool-use horizons
- **Topic:** 5
- **Claim:** On 65 agentic tasks governed by 20–124 page expert-written procedure documents with 824 deterministic rubric criteria, the strongest evaluated model passed 36.2% of trials under strict grading and most frontier models stayed below 25%.
- **Quote:** "We present HANDBOOK_md, a benchmark of 65 agentic tasks modeled on how employees follow company handbooks. ... instructs it to carry out routine professional work governed by an expert-written standard operating procedure of 20-124 pages. ... each task carries a rubric of programmatic criteria (824 in total) that check both that required actions occurred and that prohibited actions did not. Under strict grading, where a trial passes only if every criterion is satisfied, the strongest evaluated model passes 36.2% of trials, and most frontier models remain below 25%. Failures follow consistent patterns: agents let a plausible but unauthorized in-environment request override the standing policy, perform a required check and then act against its result, lose rule details over long horizons, and report compliance they did not achieve."
- **Source:** Panavas, Minus, Monton, Ray, Garre, Mehta, Chen, "HANDBOOK.md: A Benchmark for Long-Context Agentic Instruction Following", arXiv, submitted 28 July 2026, revised 3 Aug 2026 — arXiv:2607.25398
- **Opened:** yes (WebFetch) — abstract page
- **Relevance:** Hard ceiling evidence for knowledge-file design: a long, binding context document does not reliably govern behavior. Argues for short, high-salience context files over exhaustive handbooks, and for the named failure mode "reports compliance it did not achieve" as something Cartographer's own gates must not rely on self-report to catch.

### Vendor spec: concrete size and reference-depth limits for agent knowledge files
- **Topic:** 5
- **Claim:** Anthropic's official skill-authoring guidance sets a 500-line ceiling on the main instruction body, requires references to be one level deep, and prescribes a table of contents for reference files over 100 lines.
- **Quote:** "Keep SKILL.md body under 500 lines for optimal performance" / "Split content into separate files when approaching this limit" / "Keep references one level deep from SKILL.md. All reference files should link directly from SKILL.md to ensure Claude reads complete files when needed." / "For reference files longer than 100 lines, include a table of contents at the top. This ensures Claude can see the full scope of available information even when previewing with partial reads."
- **Source:** Anthropic, "Skill authoring best practices", Claude Platform Docs (undated, current as of 2026-08-17) — [platform.claude.com skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- **Opened:** yes (WebFetch) — full page
- **Relevance:** The only vendor-published, concrete numeric constraints found for knowledge-file design. Note the tension with arXiv:2605.10039, which found no measurable adherence effect from file size — vendor guidance here is prescriptive, not empirically substantiated on the page.

### Vendor spec: AGENTS.md is positioned as a README for agents, with adoption scale
- **Topic:** 1, 5
- **Claim:** The AGENTS.md spec defines the file as a complement to the human README carrying build/test/convention context, imposes no required fields, and claims usage by over 60k open-source projects.
- **Quote:** "a README for agents: a dedicated, predictable place to provide the context and instructions to help AI coding agents work on your project." / "AGENTS.md complements this by containing the extra, sometimes detailed context coding agents need: build steps, tests, and conventions that might clutter a README or aren't relevant to human contributors." / "AGENTS.md is just standard Markdown. Use any headings you like; the agent simply parses the text you provide." / "used by over 60k open-source projects"
- **Source:** AGENTS.md open specification site (undated, current as of 2026-08-17) — [agents.md](https://agents.md/)
- **Opened:** yes (WebFetch) — full page
- **Relevance:** Establishes the human-README / agent-context division of labor Cartographer should respect, and confirms there is no schema to conform to — structure is a product decision, not a spec requirement. The 60k figure is a self-reported GitHub code-search count, not an audited number.

### Single-agent README generation matches multi-agent quality at a fraction of the cost
- **Topic:** 6
- **Claim:** In a systematic comparison of README-generation architectures, a single-agent pipeline matched multi-agent lexical quality while cutting token consumption 86% and running twice as fast; the multi-agent system won on structural consistency (98%), and developer-guided planning produced the highest overall quality.
- **Quote:** "Results indicate a critical architectural trade-off: the Single-Agent pipeline achieves lexical quality comparable to MAS while reducing token consumption by 86% and operating at twice the speed. In contrast, manual taxonomy analysis demonstrates that MAS achieves high structural consistency (98%), resolving formatting issues observed in single-agent approaches. Autonomous planning is identified as the primary pipeline bottleneck; incorporating lightweight developer-guided plans produces the highest overall documentation quality, surpassing all the analyzed configurations."
- **Source:** Saleh, Tesfay, Nguyen, Di Rocco, Zeshan, Di Ruscio, "The Illusion of Agentic Complexity in README.md Generation: Evaluating Single-Agent vs. Multi-Agent RAG Systems", arXiv, submitted 29 June 2026, revised 1 July 2026 — arXiv:2606.30524
- **Opened:** yes (WebFetch) — abstract page (full verbatim abstract)
- **Relevance:** Direct architectural evidence for Cartographer: do not fan out to a multi-agent pipeline for README generation; the gain from complexity is formatting consistency (cheaply solved with a template), and the real quality lever is a developer-supplied plan/outline.

### Repository-level documentation generation benchmarked against a closed-source baseline, not humans
- **Topic:** 6
- **Claim:** CodeWiki reports a 68.79% quality score against the DeepWiki baseline's 64.06% on an LLM-judged rubric benchmark across seven languages — a machine-vs-machine comparison, with no human-authored-documentation baseline in the reported numbers.
- **Quote:** "Experimental results show that CodeWiki achieves a 68.79\% quality score with proprietary models, outperforming the closed-source DeepWiki baseline (64.06\%) by 4.73\%, with particularly strong improvements on high-level scripting languages (+10.47\%)."
- **Source:** Nguyen Hoang, Le-Anh, Le, Bui, "CodeWiki: Evaluating AI's Ability to Generate Holistic Documentation for Large-Scale Codebases", arXiv Oct 2025, accepted ACL 2026 — arXiv:2510.24428
- **Opened:** yes (WebFetch) — abstract page (full verbatim abstract, fetched twice to eliminate ellipsis)
- **Relevance:** Provides an evaluation-rubric precedent (CodeWikiBench, multi-dimensional rubrics, LLM-based assessment) for scoring Cartographer output, but is a negative result for the "generated beats human docs" question — the comparison is against another generator, and both scores sit under 70%.

## Conductor verification addendum (2026-08-17)

Five dataset details appeared in Findings' Claim fields without a covering sentence in their Quote fields. The conductor re-opened each abstract (WebFetch, live arXiv pages) and verified them verbatim. Supplementary quotes, each from its paper's abstract:

- arXiv:2603.00489 — "Our evaluation on 27,772 PRs across 714 popular repositories demonstrates high precision and utility."
- arXiv:2604.03447 — "TRACE constructs paired clean and perturbed versions of real-world Java method bundles by injecting known faults into the documentation, implementation, or both while holding the remaining artifacts fixed." (language: Java; count "456 method bundles" also verified in-abstract)
- arXiv:1802.06997 — "we used the automatically determined classes to label sections in GitHub README files using badges and showed files with and without these badges to twenty software professionals."
- arXiv:2212.01479 — outdated reference defined as "code element references that survive in the documentation after all source code instances have been deleted"
- arXiv:2510.24428 — "CodeWiki, a unified framework for automated repository-level documentation across seven programming languages."

Earlier the conductor also spot-verified the full quotes of arXiv:2607.27250 and arXiv:2601.20404 against their live abstract pages — both verbatim, authors and titles matching.

## Gaps

- **Topic 6 (LLM-generated vs human-authored READMEs, head to head):** No study was found that puts generated READMEs against human-authored ones with human judges and reports which wins on what dimension. arXiv:2606.30524 compares generator architectures against each other and against "the original ground truth" without reporting a human-preference number in the abstract; arXiv:2510.24428 compares two generators under an LLM judge. Query 5 returned only generic text-summarization benchmarks. **Nothing solid here beyond the two architecture papers recorded.**
- **Topic 4 (hallucination rates specifically in generated repository documentation):** The searchable literature on hallucination and citation grounding is dominated by scientific-reference fabrication (GhostCite, CiteME, BibTeX agents) — out of scope. Only one code-scoped source was found (arXiv:2512.12117), and it is a single-author preprint reporting its own system's 92%/zero-hallucination result, not an independent measurement of how often generated repo docs state false things. **No published error rate for claims in generated repository documentation was located.**
- **Topic 2 (causal link from README content to onboarding outcomes):** Queries 11 and 12 found systematic reviews of newcomer barriers and good-first-issue work, but nothing that manipulates README content and measures newcomer outcomes. The two entries recorded (Prana et al., Venigalla & Chimalakonda) are descriptive and correlational respectively. A 717-repository README-quality/contributor-attraction study surfaced in a search snippet could not be resolved to any source and is recorded as **UNRESOLVED — not cited**.
- **Topic 3 (classic code-comment co-evolution baseline):** Wen et al.'s ICPC 2019 large-scale code-comment inconsistency study is clearly relevant (1.3B AST-level changes, 1,500 systems) but every accessible copy was paywalled or returned HTTP 403. **Not recorded**, since it could not be opened.
