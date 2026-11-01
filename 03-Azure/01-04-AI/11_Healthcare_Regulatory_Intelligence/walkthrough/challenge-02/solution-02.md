# Challenge 2 solution: Document & Citation Agent

**[← Previous Solution](../challenge-01/solution-01.md)** - [Home](../../README.md) - [Challenge](../../challenges/challenge-02.md) - [Next Solution →](../challenge-03/solution-03.md)

**Duration:** 45 minutes

## Expected citation card for EU-SA-2027-004

The wording will vary, but the facts and citations must match:

| Section | Expected content |
|---|---|
| Document | EU-SA-2027-004 v1, *Caldivex: new warning on liver injury*, current |
| Source | EU medicines regulator (fictional), EU, health authority, safety alert; `portal://eu-medicines-regulator/safety/EU-SA-2027-004.html`, also at `…/news/2027-01-11-caldivex.html` |
| Dates | Published and effective 2027-01-11; DHPC to prescribers by **1 March 2027** [p4]; variation by **15 March 2027** [p3] |
| What it says | Reports of liver injury with tablets and pen [p1]; add warning to 4.4, add liver injury to 4.8, update leaflet, check liver function before treatment and after 3 months [p2]; submit variation [p3]; agree and send DHPC [p4]; add liver injury to RMP and next PSUR [p5] |
| Tags | labelling, vigilance; CDX-TAB, CDX-PEN |
| Version history | One version |

`EU-SA-2027-099` → "Not found in the regulatory lake".

## Expected answer after Tuesday's crawl

| Item | v1 (11 Jan, superseded) | v2 (12 Jan, current) |
|---|---|---|
| Tier change effective | 1 March 2027 [v1 p2] | **1 April 2027** [v2 p2] |
| Prior authorisation | Two failed preventive treatments [v1 p3] | **One** [v2 p3] |
| Evidence deadline | 15 February 2027 [v1 p4] | **1 March 2027** [v2 p4] |

The monitor output is `run 3`, `Updated documents: 1 US-CD-2027-015 v2`, `Duplicates ignored: 9` and `Change events written: 1`. The indexer run afterwards shows **22** documents succeeded: the monitor re-uploads every file, so all 21 earlier files count again, plus the new version.

## Teaching points

- The **monitor** decides what is new; the **agent** explains it. A model is never asked whether two pages are duplicates.
- Citations are anchored to `document + version + paragraph`. Because a version never changes after it is written, a citation stays valid even after the source page changes.
- Ask participants to compare one cited statement with the lake file. Fluent text is not evidence; the citation is.
- A correct citation does not guarantee a correct reading. In our test runs the agent cited `v2 p3` correctly but called the new prior-authorisation rule "tightened" or "stricter". It is the opposite: one failed treatment instead of two makes prior authorisation **easier** to get. What got worse for Caldova is the tier (patients pay more) and the date. Use this to show why a person reads the source, not only the citation.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| The agent answers without citations or from general knowledge | The knowledge base is not connected, or the default **Web search** tool is still under **Tools** | Remove Web search, connect `caldova-regulatory-kb` under **Knowledge**, save, start a new chat |
| Statements end only with numbered markers (①, ②…), no `[DOC vN pK]` labels | The model let Foundry IQ's markers stand in for the lake's labels | The instructions require the labels; check the instructions were saved and ask again in a new chat. The labels matter in Challenge 5, where sign-off rejects citations that are not real paragraph labels |
| Citations such as `p7` that don't exist | The model invented them | Check the trace for retrieval. Strengthen the "only use labels that appear" rule; never accept an unverified citation |
| After Tuesday, the agent still says v1 is current | The indexer has not re-run | Search service → Indexers → `caldova-lake-indexer` → Run, wait for success, then start a new chat |
| The agent says prior authorisation became "stricter" | The model guessed the direction of the change | Point to `v1 p3` (two failed treatments) and `v2 p3` (one): v2 is easier. The citation was right; the reading was not |
| `Crawl monday first` error | Tuesday was run before Monday | Run Monday, then Tuesday |
