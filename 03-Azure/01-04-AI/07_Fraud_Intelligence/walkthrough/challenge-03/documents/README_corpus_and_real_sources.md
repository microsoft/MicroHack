# Synthetic AML / CFT / KYC corpus for the Fraud Intelligence multi-agent hackathon

15 PDFs + `index_manifest.json`. All content is **synthetic** — written for this hackathon, modelled on the structure and themes of public regulatory material, with no verbatim reproduction. Thresholds and country ratings are illustrative, not legal advice.

## 1. Corpus layout

### Global / supranational (always retrievable)
| File | ID | Jurisdiction | What the risk agent gets from it |
|---|---|---|---|
| 01_Global_AML_CFT_Standards_Summary | GLB-STD-001 | GLOBAL | Risk-based approach, CDD, wire-transfer transparency, core red flags |
| 03_Correspondent_Banking_Financial_Crime_Principles | GLB-CBK-003 | GLOBAL | Respondent/nested due diligence, correspondent monitoring, exit rules |
| 15_Typology_Casebook_and_Detection_Scenarios | GLB-TYP-015 | GLOBAL | Typologies as pseudo-rules with observable features + policy cross-references |

### Bank-internal policy
| File | ID | Use |
|---|---|---|
| 04_KYC_CDD_Standard_Operating_Procedure | OPS-KYC-004 | Customer risk scoring model, UBO rules, SoF/SoW evidence table, alert workflow |
| 05_Jurisdiction_Risk_Matrix_and_Corridor_Rules | OPS-GEO-005 | **The routing document** — country ratings, corridor modifiers, controls per corridor, worked origin→destination examples |

### Regional / local regulation — selected by transaction origin and destination
| File | ID | Jurisdiction |
|---|---|---|
| 02_EU_ML_TF_Risk_Factors_Guidelines | EU-GL-002 | EU |
| 06_Spain_AML_Local_Regulation | ES-REG-006 | ES |
| 07_Germany_AML_Local_Regulation | DE-REG-007 | DE |
| 08_UK_AML_Local_Regulation | GB-REG-008 | GB |
| 09_United_States_BSA_Local_Regulation | US-REG-009 | US |
| 10_Singapore_AML_Local_Regulation | SG-REG-010 | SG |
| 11_UAE_AML_Local_Regulation | AE-REG-011 | AE |
| 12_Mexico_AML_Local_Regulation | MX-REG-012 | MX |
| 13_Nigeria_AML_Local_Regulation | NG-REG-013 | NG |
| 14_Panama_AML_Local_Regulation | PA-REG-014 | PA |

Each local document carries: scope, thresholds table, reporting duties, and a **local red flags** section — so the same transaction pattern produces different findings depending on the corridor.

## 2. How the agents are meant to use it

1. Fabric data agent returns candidate origin + destination accounts with their country codes.
2. Risk analyzer resolves the corridor rating from **OPS-GEO-005** (rating = max of both legs, plus modifiers).
3. It retrieves the local document for the **origin** jurisdiction and for the **destination** jurisdiction.
4. It matches observed behaviour against **GLB-TYP-015** scenarios.
5. It must cite `document_id` + section in the finding — the casebook makes an uncited assessment invalid, which is a clean guardrail to demo.

## 3. Indexing in Azure AI Search / Foundry IQ

Every PDF has a cover metadata table (Document ID, type, jurisdiction code, corridors, issuer, version) and matching PDF metadata (title/subject/keywords), so both text extraction and field mapping work.

Suggested index fields:

```
id (key)            doc_id (filterable)      jurisdiction (filterable, facetable)
doctype (filterable) title (searchable)      section (searchable)
content (searchable, vectorized)             version
```

Filter pattern for the risk agent:

```
$filter=jurisdiction eq 'GLOBAL' or jurisdiction eq '{origin}' or jurisdiction eq '{destination}'
```

Chunking: split on the numbered headings (`1.`, `2.1`, …), 500–800 tokens with ~15% overlap; keep the section heading in each chunk so citations stay precise. `index_manifest.json` can drive an indexer's metadata or a custom skillset lookup.

## 4. Real public sources worth adding alongside these

These are genuine, freely downloadable and safe to index for a hackathon:

- **FATF** — The FATF Recommendations (Feb 2025 consolidated), Methodology, and the typology/guidance library at fatf-gafi.org.
- **EBA** — Guidelines on ML/TF Risk Factors (EBA/GL/2021/02, consolidated with EBA/GL/2023/03) at eba.europa.eu.
- **ECB** — supervisory statements on AML/CFT interaction with prudential supervision (ecb.europa.eu, Banking Supervision section).
- **EUR-Lex** — Regulation (EU) 2015/847 / 2023/1113 on information accompanying transfers of funds and crypto-assets; AMLD5/6 and the 2024 AML package.
- **Wolfsberg Group** — Financial Crime Principles for Correspondent Banking, CBDDQ, Payment Transparency Standards.
- **Basel Committee (BIS)** — Sound management of risks related to money laundering and financing of terrorism.
- **Egmont Group / national FIUs** — typology and case reports (SEPBLAC in Spain, FinCEN advisories in the US, NCA SARs annual report in the UK).
- **UNODC / IMF** — money laundering and illicit financial flows studies.

Mixing 3–5 real ones with these 15 synthetic ones gives you a realistic hybrid index without licensing worries on the generated content.
