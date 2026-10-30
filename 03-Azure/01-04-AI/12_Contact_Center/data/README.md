# Industry packs

[Home](../README.md)

Each folder under `packs/` is one fictional company. The setup tool (`python3 -m contactcenter`) copies the selected pack into the lab's storage containers, and the mock CRM serves its customers.

| File | Used in | What it holds |
|---|---|---|
| `pack.json` | Setup tool, CRM | Company name, prefix, products, appointment type, greeting and a suggested voice style |
| `crm.json` | CRM | 10 customers (some with support needs), 32 appointment slots, one open case and the week's service notice |
| `knowledge/KB-<P>-001.md` to `008.md` | Challenges 1 to 5 | Knowledge articles. 001 identity checks, 002 vulnerable customers, 003 complaints, 004 service levels, 005 to 008 industry topics. Every paragraph starts with a label such as `[KB-KC-005 p2]` |
| `calls/<P>-CALL-01..03.txt` and `.mp3` | Challenges 4 and 6 | Three recorded calls: a routine request, a frustrated customer affected by the week's trend, and a vulnerable customer |
| `contacts.jsonl` and `insights/<P>-CONTACTS.md` | Challenge 6 | 30 contacts from one week, with intent, area, sentiment and QA scores. The markdown digest is what the supervisor's knowledge base indexes |
| `evaluation.jsonl` | Challenge 7 | Ten test questions with the expected answer (`query`, `ground_truth`) |

Every week hides one trend and two contacts where the identity check was missed:

| Pack | Company | Trend |
|---|---|---|
| `telco` | Kestrel Connect (`KC`) | Broadband outages in ZZ4 |
| `energy` | Lumora Energy (`LE`) | Estimated-bill queries in ZZ2 |
| `bank` | Harbourline Bank (`HB`) | Parcel-fee text scam, all areas |
| `insurance` | Northmere Insurance (`NI`) | Storm damage in ZZ3 |
| `retail` | Parcelpine (`PP`) | Late deliveries in ZZ5 |

All companies, people, addresses, account numbers and calls are fictional. Postcodes use the unused `ZZ` area. The recordings were made with Azure AI Speech text to speech from the `.txt` scripts, with one voice for the adviser and another for the customer.
