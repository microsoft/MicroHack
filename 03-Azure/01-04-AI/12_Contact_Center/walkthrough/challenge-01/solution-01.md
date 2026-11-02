# Challenge 1 solution: Pick your company and build its knowledge base

**[Home](../../README.md)** - [Challenge](../../challenges/challenge-01.md) - [Next Solution →](../challenge-02/solution-02.md)

**Duration:** 45 minutes

## Expected results

After `setup`, the tool prints the company and the files it loaded. `python3 -m contactcenter --account <StorageAccountName> status` shows the same pack for every industry:

| Container | Files |
|---|---|
| `knowledge` | 8 articles, `KB-<P>-001.md` to `KB-<P>-008.md` |
| `insights` | 1 file, `<P>-CONTACTS.md` (the supervisor's week of contacts) |
| `calls` | 3 recorded calls, `<P>-CALL-01.mp3` to `<P>-CALL-03.mp3` |
| `evaluation` | 1 file, `evaluation.jsonl` (10 test questions) |

`<P>` is the company prefix: `KC` Kestrel Connect, `LE` Lumora Energy, `HB` Harbourline Bank, `NI` Northmere Insurance, `PP` Parcelpine.

The CRM home page (`CrmUrl`) shows the company name and an empty activity table. `<CrmUrl>/health` returns `"status": "ok"` and the five available packs, and `<CrmUrl>/company` returns the company the participant chose.

Articles 001 to 004 have the same structure in every pack: **001** checking identity, **002** vulnerable customers, **003** complaints, **004** service levels. Articles 005 to 008 are industry specific. Every paragraph starts with a label such as `[KB-KC-005 p2]`, which is what the agents cite.

After Part D the knowledge source `contact-knowledge` is **Active** and the knowledge base `contact-knowledge-kb` lists it. Indexing 8 small files takes one to three minutes.

## Points to discuss

- **Why a tool, not a portal upload?** Switching company has to replace the files in four containers and tell the CRM which customers to serve. Doing that by hand is error-prone; the tool does it the same way every time.
- **Why two knowledge bases?** Customer-facing agents must never quote internal contact records. Keeping `insights` out of `contact-knowledge-kb` is a security boundary, not tidiness.
- **Switching company later:** run `setup` again with another `--industry`. The tool replaces the contents of all four containers and resets the CRM's active pack. Re-run the knowledge source's indexer (or wait for its schedule) so the knowledge base picks up the new articles.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `setup` fails with `AuthorizationPermissionMismatch` | The participant's role on the storage account has not propagated yet. Wait two minutes and run it again. |
| `setup` prints *CRM check: could not reach…* | The CRM is cold-starting on Flex Consumption. The pack is already selected (the tool writes it to storage); open `<CrmUrl>/company` in a browser and it answers within a minute. |
| The CRM returns **409** *No industry pack selected* | `setup` has not been run yet in this lab. Run it. |
| The knowledge source stays **Creating** | The search service identity needs **Storage Blob Data Reader**, which the lab automation assigns. Wait five minutes; if it fails, check the source's indexer status in the Azure portal. |
| Cloud Shell asks for storage | Choose **No storage account required**. |
