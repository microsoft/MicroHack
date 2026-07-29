#!/usr/bin/env python
"""Build-time generator for the Challenge 1 CLM corpus PDFs.

Produces the **entire document corpus** as real, text-extractable PDFs under
`src/data/`:

  * contract_templates/  - approved authoring templates (NDA, MSA, SOW)
  * clause_library/       - the enterprise Standard Clause Library
  * policies/             - contracting policy + delegation-of-authority matrix
  * contracts/            - the executed contract portfolio (one per row in
                            contracts_seed.json)
  * counterparty_drafts/  - inbound drafts for the Clause & Risk agent to analyze
  * playbooks/            - the negotiation playbook (fallback positions)

This is authoring tooling (like `src/scripts/make_banner.py`); it is NOT a runtime
dependency of the hack. The full document text lives here so it is reviewable in
source control; the generated PDFs are what you upload to the SharePoint corpus
library, which the Azure AI Search SharePoint indexer crawls into the clm-corpus
index (Challenge 1) and the Clause & Risk agent analyzes.

Requires:  pip install reportlab
Run:       python src/scripts/make_corpus_pdfs.py
"""
from __future__ import annotations

from pathlib import Path

from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY
from reportlab.lib.pagesizes import LETTER
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)
from reportlab.lib import colors

REPO_ROOT = Path(__file__).resolve().parents[2]
DATA_ROOT = REPO_ROOT / "src" / "data"
CONTRACTS_DIR = DATA_ROOT / "contracts"
DRAFTS_DIR = DATA_ROOT / "counterparty_drafts"
TEMPLATES_DIR = DATA_ROOT / "contract_templates"
CLAUSE_DIR = DATA_ROOT / "clause_library"
POLICY_DIR = DATA_ROOT / "policies"
PLAYBOOK_DIR = DATA_ROOT / "playbooks"

# --------------------------------------------------------------------------- styles
_ss = getSampleStyleSheet()
TITLE = ParagraphStyle("title", parent=_ss["Title"], fontSize=15, spaceAfter=4, alignment=TA_CENTER)
SUBTITLE = ParagraphStyle("subtitle", parent=_ss["Normal"], fontSize=9, alignment=TA_CENTER,
                          textColor=colors.HexColor("#555555"), spaceAfter=10)
H = ParagraphStyle("h", parent=_ss["Heading2"], fontSize=10.5, spaceBefore=8, spaceAfter=2,
                   textColor=colors.HexColor("#1F3864"))
BODY = ParagraphStyle("body", parent=_ss["Normal"], fontSize=9.5, leading=13, alignment=TA_JUSTIFY)
META = ParagraphStyle("meta", parent=_ss["Normal"], fontSize=9, leading=13)
NOTE = ParagraphStyle("note", parent=_ss["Normal"], fontSize=9, leading=13,
                      textColor=colors.HexColor("#B00020"))
SIGN = ParagraphStyle("sign", parent=_ss["Normal"], fontSize=9, leading=16)
FOOT = ParagraphStyle("foot", parent=BODY, fontSize=7.5,
                      textColor=colors.HexColor("#888888"), alignment=TA_CENTER)


def _doc(path: Path, title: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    return SimpleDocTemplate(
        str(path), pagesize=LETTER,
        leftMargin=0.9 * inch, rightMargin=0.9 * inch,
        topMargin=0.8 * inch, bottomMargin=0.8 * inch,
        title=title, author="Contoso Global, Inc.",
    )


def _meta_table(rows):
    t = Table([[Paragraph(f"<b>{k}</b>", META), Paragraph(v, META)] for k, v in rows],
              colWidths=[1.4 * inch, 4.9 * inch])
    t.setStyle(TableStyle([
        ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#BBBBBB")),
        ("INNERGRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#DDDDDD")),
        ("BACKGROUND", (0, 0), (0, -1), colors.HexColor("#F3F2F1")),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING", (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
    ]))
    return t


def _data_table(rows):
    """A simple bordered table; first row is treated as the header."""
    body = [[Paragraph(f"<b>{c}</b>" if r == 0 else c, META) for c in row]
            for r, row in enumerate(rows)]
    t = Table(body, hAlign="LEFT")
    t.setStyle(TableStyle([
        ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#BBBBBB")),
        ("INNERGRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#DDDDDD")),
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1F3864")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING", (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
    ]))
    return t


# =========================================================================== builders
def build_contract_pdf(path: Path, title: str, subtitle: str, meta_rows, sections,
                       parties, note: str | None = None):
    """Executed agreement / counterparty draft with a signature block."""
    doc = _doc(path, title)
    flow = [Paragraph(title, TITLE), Paragraph(subtitle, SUBTITLE)]
    if note:
        flow += [Paragraph(note, NOTE), Spacer(1, 6)]
    flow += [_meta_table(meta_rows), Spacer(1, 10)]
    for i, (heading, body) in enumerate(sections, 1):
        flow.append(Paragraph(f"{i}. {heading}", H))
        flow.append(Paragraph(body, BODY))
    flow.append(Spacer(1, 16))
    flow.append(Paragraph("IN WITNESS WHEREOF, the parties have executed this Agreement as of the "
                          "Effective Date.", BODY))
    flow.append(Spacer(1, 10))
    sig = Table(
        [[Paragraph(f"<b>{parties[0]}</b><br/>By: ____________________<br/>"
                    "Name: A. Rivera<br/>Title: General Counsel<br/>Date: ______________", SIGN),
          Paragraph(f"<b>{parties[1]}</b><br/>By: ____________________<br/>"
                    "Name: Authorized Signatory<br/>Title: ______________<br/>Date: ______________", SIGN)]],
        colWidths=[3.15 * inch, 3.15 * inch])
    sig.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP")]))
    flow.append(sig)
    flow.append(Spacer(1, 14))
    flow.append(Paragraph(f"Contoso Global, Inc. - CONFIDENTIAL - {meta_rows[0][1]} - "
                          "Fictitious document for the CLM microhack.", FOOT))
    doc.build(flow)
    print(f"  [ok] {path.relative_to(REPO_ROOT)}")


def build_reference_pdf(path: Path, title: str, subtitle: str, blocks, note: str | None = None):
    """Reference material (templates, clause library, policy, playbook).

    `blocks` is a flat list of tuples:
      ("h", "Heading")            -> section heading
      ("p", "body html")          -> justified paragraph (supports <b>)
      ("table", [[...], [...]])   -> bordered table, first row = header
    """
    doc = _doc(path, title)
    flow = [Paragraph(title, TITLE), Paragraph(subtitle, SUBTITLE)]
    if note:
        flow += [Paragraph(note, NOTE), Spacer(1, 6)]
    for kind, payload in blocks:
        if kind == "h":
            flow.append(Paragraph(payload, H))
        elif kind == "p":
            flow.append(Paragraph(payload, BODY))
        elif kind == "table":
            flow.append(Spacer(1, 2))
            flow.append(_data_table(payload))
            flow.append(Spacer(1, 4))
    flow.append(Spacer(1, 14))
    flow.append(Paragraph("Contoso Global, Inc. - INTERNAL - Fictitious reference document for the "
                          "CLM microhack.", FOOT))
    doc.build(flow)
    print(f"  [ok] {path.relative_to(REPO_ROOT)}")


# =========================================================================== contracts
def contract_ct4821():
    build_contract_pdf(
        CONTRACTS_DIR / "CT-4821_Acme_MSA.pdf",
        "MASTER SERVICES AGREEMENT",
        "between Contoso Global, Inc. and Acme Corp",
        [("Contract ID", "CT-4821"), ("Counterparty", "Acme Corp"), ("Type", "MSA - Master Services Agreement"),
         ("Status", "Active"), ("Effective date", "2024-09-01"), ("Renewal date", "2026-09-01"),
         ("Auto-renew", "Yes"), ("Non-renewal notice", "90 days"),
         ("Internal risk rating", "High"), ("Contract owner", "legal@contoso.com")],
        [
            ("Payment Terms", "Contoso Global (\u201cClient\u201d) shall pay undisputed invoices "
             "<b>Net 30</b> from receipt. Late amounts accrue interest at 1.0% per month."),
            ("Limitation of Liability", "Each party\u2019s aggregate liability is capped at the fees "
             "paid in the <b>trailing six (6) months</b>. No carve-outs are stated for confidentiality "
             "or IP infringement."),
            ("Indemnification", "The parties provide <b>mutual</b> indemnification for third-party "
             "claims arising from negligence. Intellectual-property infringement is <b>not</b> covered."),
            ("Term &amp; Auto-Renewal", "Initial term of <b>two (2) years</b> from the Effective Date, "
             "renewing automatically for successive one-year terms unless either party gives 90 days\u2019 "
             "written notice of non-renewal."),
            ("Governing Law", "This Agreement is governed by the laws of the State of New York, USA."),
            ("Intellectual Property", "Deliverables created for Client are works made for hire; ownership "
             "vests in Client upon payment."),
            ("Data Protection", "Provider processes Client data per Client instructions under the attached "
             "Data Processing Addendum; GDPR terms apply where relevant."),
            ("Confidentiality", "Confidentiality obligations survive <b>five (5) years</b> after disclosure."),
            ("Termination", "Either party may terminate for material breach with a 30-day cure period, or "
             "for convenience on 60 days\u2019 notice."),
            ("Insurance", "Provider maintains commercial general liability insurance of not less than "
             "USD 2,000,000."),
        ],
        ("Contoso Global, Inc.", "Acme Corp"),
        note="High-risk executed agreement: Net 30 payment, 6-month liability cap, and mutual "
             "indemnity without IP coverage deviate from the Standard Clause Library.",
    )


def contract_ct3390():
    build_contract_pdf(
        CONTRACTS_DIR / "CT-3390_Globex_NDA.pdf",
        "MUTUAL NON-DISCLOSURE AGREEMENT",
        "between Contoso Global, Inc. and Globex Ltd",
        [("Contract ID", "CT-3390"), ("Counterparty", "Globex Ltd"), ("Type", "NDA - Mutual Non-Disclosure"),
         ("Status", "Active"), ("Effective date", "2025-02-15"), ("Renewal date", "2027-02-15"),
         ("Auto-renew", "No"), ("Non-renewal notice", "30 days"),
         ("Internal risk rating", "Low"), ("Contract owner", "procurement@contoso.com")],
        [
            ("Purpose", "The parties wish to exchange Confidential Information to evaluate a potential "
             "business relationship."),
            ("Definition of Confidential Information", "Non-public business, technical, and financial "
             "information disclosed in any form and marked or reasonably understood as confidential."),
            ("Obligations", "Each party protects the other\u2019s Confidential Information with the same "
             "care it uses for its own (no less than reasonable care) and uses it solely for the Purpose."),
            ("Term &amp; Renewal", "Two (2) year term; <b>no automatic renewal</b>. Either party may "
             "decline renewal on 30 days\u2019 notice."),
            ("Confidentiality Survival", "Confidentiality obligations survive <b>three (3) years</b> after "
             "disclosure \u2014 consistent with the enterprise standard."),
            ("Governing Law", "This Agreement is governed by the laws of the State of Washington, USA."),
            ("No License", "No license or IP rights are granted except the limited right to use "
             "Confidential Information for the Purpose."),
            ("Return or Destruction", "Upon request, each party returns or destroys the other\u2019s "
             "Confidential Information."),
        ],
        ("Contoso Global, Inc.", "Globex Ltd"),
    )


def contract_ct5102():
    build_contract_pdf(
        CONTRACTS_DIR / "CT-5102_Initech_SOW.pdf",
        "STATEMENT OF WORK",
        "under the Master Services Agreement between Contoso Global, Inc. and Initech LLC",
        [("Contract ID", "CT-5102"), ("Counterparty", "Initech LLC"), ("Type", "SOW - Statement of Work"),
         ("Status", "Active"), ("Effective date", "2025-06-01"), ("Renewal date", "2026-06-01"),
         ("Auto-renew", "Yes"), ("Non-renewal notice", "60 days"),
         ("Internal risk rating", "Medium"), ("Contract owner", "legal@contoso.com")],
        [
            ("Scope of Services", "Initech LLC (\u201cSupplier\u201d) will design and implement a data "
             "integration platform, delivered across three milestones over twelve months."),
            ("Deliverables &amp; Milestones", "M1 \u2014 solution design (month 2); M2 \u2014 build and "
             "integration (month 7); M3 \u2014 acceptance and handover (month 12). Each milestone requires "
             "written Client acceptance."),
            ("Fees &amp; Payment", "Fixed fee of USD 240,000, invoiced per milestone. Undisputed invoices "
             "are payable <b>Net 45</b>."),
            ("Limitation of Liability", "Supplier\u2019s aggregate liability is capped at the fees paid in "
             "the trailing twelve (12) months, with carve-outs for confidentiality and IP infringement."),
            ("Intellectual Property", "Custom deliverables are works made for hire owned by Client on "
             "payment; however, <b>Supplier retains ownership of its pre-existing tools and libraries</b> "
             "and grants Client a perpetual, non-exclusive license-back to use them within the deliverables."),
            ("Term &amp; Renewal", "One (1) year term aligned to the delivery window; auto-renews for "
             "one-year support terms unless either party gives 60 days\u2019 notice."),
            ("Governing Law", "Governed by the laws of the State of Washington, USA."),
            ("Data Protection", "Supplier processes Client data under the MSA\u2019s Data Processing "
             "Addendum; sub-processors require prior written notice."),
            ("Termination", "Either party may terminate for material breach with a 30-day cure period, or "
             "for convenience on 60 days\u2019 notice."),
            ("Insurance", "Supplier maintains commercial general liability insurance of USD 2,000,000 and "
             "cyber liability coverage appropriate to a data processor."),
        ],
        ("Contoso Global, Inc.", "Initech LLC"),
        note="Medium-risk executed agreement: the IP license-back for Supplier pre-existing tools "
             "deviates from the standard works-made-for-hire position.",
    )


def contract_ct2765():
    build_contract_pdf(
        CONTRACTS_DIR / "CT-2765_Umbrella_MSA.pdf",
        "MASTER SERVICES AGREEMENT",
        "between Contoso Global, Inc. and Umbrella Inc",
        [("Contract ID", "CT-2765"), ("Counterparty", "Umbrella Inc"), ("Type", "MSA - Master Services Agreement"),
         ("Status", "Expired"), ("Effective date", "2022-01-10"), ("Renewal date", "2024-01-10"),
         ("Auto-renew", "No"), ("Non-renewal notice", "90 days"),
         ("Internal risk rating", "Medium"), ("Contract owner", "legal@contoso.com")],
        [
            ("Payment Terms", "Client pays undisputed invoices <b>Net 60</b> from receipt \u2014 the "
             "enterprise standard."),
            ("Limitation of Liability", "Aggregate liability capped at fees paid in the trailing twelve "
             "(12) months, with carve-outs for confidentiality, IP infringement, and indemnity."),
            ("Indemnification", "Supplier indemnifies Client for third-party claims from negligence, "
             "willful misconduct, and IP infringement."),
            ("Term &amp; Renewal", "Two (2) year initial term expiring on the Renewal date; <b>no "
             "automatic renewal</b>. The parties did not renew; the Agreement lapsed on 2024-01-10."),
            ("Governing Law", "Governed by the laws of the State of Washington, USA."),
            ("Intellectual Property", "Deliverables are works made for hire owned by Client on payment."),
            ("Confidentiality", "Confidentiality obligations survive three (3) years after disclosure."),
            ("Termination", "For material breach with a 30-day cure period, or for convenience on 60 "
             "days\u2019 notice."),
            ("Insurance", "Supplier maintained commercial general liability insurance of USD 2,000,000 "
             "during the term."),
        ],
        ("Contoso Global, Inc.", "Umbrella Inc"),
        note="STATUS: EXPIRED \u2014 this Agreement lapsed on 2024-01-10 and was not renewed. Retained "
             "for records and lifecycle reporting.",
    )


def contract_ct6033():
    build_contract_pdf(
        CONTRACTS_DIR / "CT-6033_Soylent_MSA.pdf",
        "MASTER SERVICES AGREEMENT",
        "between Contoso Global, Inc. and Soylent Co",
        [("Contract ID", "CT-6033"), ("Counterparty", "Soylent Co"), ("Type", "MSA - Master Services Agreement"),
         ("Status", "Active"), ("Effective date", "2025-08-20"), ("Renewal date", "2026-08-20"),
         ("Auto-renew", "Yes"), ("Non-renewal notice", "90 days"),
         ("Internal risk rating", "High"), ("Contract owner", "procurement@contoso.com")],
        [
            ("Payment Terms", "Client shall pay undisputed invoices <b>Net 30</b> from the invoice date, "
             "with 1.5% monthly interest on late amounts."),
            ("Limitation of Liability", "Each party\u2019s aggregate liability is capped at the fees paid "
             "in the <b>trailing three (3) months</b> \u2014 well below the enterprise standard."),
            ("Indemnification", "Supplier indemnifies Client for third-party negligence claims; IP "
             "infringement indemnity is limited to direct damages only."),
            ("Term &amp; Auto-Renewal", "Initial term of one (1) year, renewing automatically for "
             "successive one-year terms unless either party gives 90 days\u2019 written notice."),
            ("Governing Law", "This Agreement is governed by the laws of the <b>Republic of Ireland</b>."),
            ("Intellectual Property", "Deliverables are works made for hire owned by Client on payment."),
            ("Data Protection", "Supplier may engage sub-processors with prior notice; an EU Standard "
             "Contractual Clauses addendum applies."),
            ("Confidentiality", "Confidentiality obligations are <b>perpetual</b> and survive termination "
             "indefinitely."),
            ("Termination", "For material breach with a 30-day cure period, or for convenience on 90 "
             "days\u2019 notice."),
            ("Insurance", "Supplier maintains commercial general liability insurance of USD 1,000,000."),
        ],
        ("Contoso Global, Inc.", "Soylent Co"),
        note="High-risk executed agreement: non-US/UK governing law (Ireland), perpetual "
             "confidentiality, and a 3-month liability cap are non-standard and require GC sign-off.",
    )


# =========================================================================== inbound drafts
def draft_acme():
    build_contract_pdf(
        DRAFTS_DIR / "acme_msa_draft.pdf",
        "MASTER SERVICES AGREEMENT - COUNTERPARTY DRAFT",
        "Inbound draft received from Acme Corp - for clause &amp; risk analysis",
        [("Document", "INBOUND counterparty draft"), ("From", "Acme Corp (\u201cProvider\u201d)"),
         ("To", "Contoso Global, Inc. (\u201cClient\u201d)"), ("Type", "MSA - proposed"),
         ("Reviewed by", "Clause &amp; Risk agent (Challenge 4)"),
         ("Benchmark", "Contoso Standard Clause Library CL-01\u2026CL-12")],
        [
            ("Payment Terms", "Client shall pay all invoices within <b>thirty (30) days</b> of the "
             "invoice date. Payments not received within 30 days accrue interest at 1.5% per month."),
            ("Limitation of Liability", "<b>Provider\u2019s liability under this Agreement is unlimited "
             "for all claims.</b> Client\u2019s liability is capped at fees paid in the trailing six (6) "
             "months."),
            ("Indemnification", "Each party shall indemnify the other for third-party claims arising from "
             "its own negligence. <b>No indemnification is provided for intellectual property "
             "infringement.</b>"),
            ("Term and Renewal", "Initial term of <b>three (3) years</b>, renewing automatically for "
             "successive three-year terms unless Client provides <b>one hundred eighty (180) days\u2019</b> "
             "written notice."),
            ("Intellectual Property", "<b>Provider retains all ownership of deliverables</b> and grants "
             "Client a non-exclusive, revocable license to use them during the term."),
            ("Governing Law", "This Agreement is governed by the laws of <b>Ireland</b>."),
            ("Data Protection", "Provider may engage sub-processors at its discretion. A Data Processing "
             "Addendum is <b>not attached</b>."),
            ("Confidentiality", "Confidentiality obligations are <b>perpetual</b> and survive termination "
             "indefinitely."),
            ("Insurance", "Provider maintains commercial general liability insurance of <b>USD "
             "500,000</b>."),
        ],
        ("Acme Corp (Provider)", "Contoso Global, Inc. (Client)"),
        note="This is an unsigned counterparty proposal, deliberately full of deviations from the "
             "Standard Clause Library for the Clause &amp; Risk agent to flag.",
    )


def draft_globex():
    build_contract_pdf(
        DRAFTS_DIR / "globex_nda_redline.pdf",
        "MUTUAL NON-DISCLOSURE AGREEMENT - COUNTERPARTY REDLINE",
        "Inbound redline received from Globex Ltd - for clause &amp; risk analysis",
        [("Document", "INBOUND counterparty redline"), ("From", "Globex Ltd (\u201cDiscloser\u201d)"),
         ("To", "Contoso Global, Inc."), ("Type", "NDA - proposed changes"),
         ("Reviewed by", "Clause &amp; Risk agent (Challenge 4)"),
         ("Benchmark", "Contoso Standard Clause Library CL-05, CL-08, CL-11")],
        [
            ("Purpose", "The parties will exchange Confidential Information to evaluate a supply "
             "arrangement. Scope of \u201cPurpose\u201d is defined narrowly and may not be broadened "
             "without Discloser consent."),
            ("Definition of Confidential Information", "Expanded to include <b>residual knowledge retained "
             "in unaided memory</b>, which Discloser asserts remains confidential indefinitely."),
            ("Confidentiality Survival", "Confidentiality obligations are <b>perpetual</b> for all "
             "information designated \u201ctrade secret,\u201d and survive <b>seven (7) years</b> for all "
             "other Confidential Information."),
            ("Governing Law", "This Agreement is governed by the laws of <b>Singapore</b>, with exclusive "
             "jurisdiction in the courts of Singapore."),
            ("Assignment", "Discloser may <b>assign this Agreement freely, including on a change of "
             "control</b>; Contoso may not assign without Discloser\u2019s prior written consent."),
            ("Injunctive Relief", "Discloser is entitled to injunctive relief <b>without posting bond</b> "
             "and to recover its legal fees for any breach."),
            ("Term", "Two (2) year term; either party may terminate on 30 days\u2019 notice, but the "
             "confidentiality obligations above survive termination."),
        ],
        ("Globex Ltd (Discloser)", "Contoso Global, Inc."),
        note="Inbound redline with non-standard deviations (Singapore governing law, perpetual / "
             "7-year confidentiality, one-sided assignment) for the Clause &amp; Risk agent to flag.",
    )


# =========================================================================== templates
def template_nda():
    build_reference_pdf(
        TEMPLATES_DIR / "NDA_template.pdf",
        "MUTUAL NON-DISCLOSURE AGREEMENT (APPROVED TEMPLATE)",
        "Approved template v3.2 - Owner: Legal Operations - Governing law: State of Washington, USA",
        [
            ("p", "Use for pre-contract discussions. Do not modify <b>bold</b> standard clauses without "
                  "Legal approval. Placeholders in {{double braces}} are filled at drafting time."),
            ("p", "This Mutual Non-Disclosure Agreement (\u201cAgreement\u201d) is entered into as of "
                  "{{effective_date}} by and between <b>Contoso Global, Inc.</b> (\u201cContoso\u201d) and "
                  "{{counterparty_name}} (\u201cCounterparty\u201d)."),
            ("h", "1. Definition of Confidential Information"),
            ("p", "\u201cConfidential Information\u201d means any non-public information disclosed by one "
                  "party to the other, whether orally, in writing, or by inspection of tangible objects, "
                  "that is designated as confidential or that reasonably should be understood to be "
                  "confidential."),
            ("h", "2. Obligations"),
            ("p", "Each party shall (a) protect the other\u2019s Confidential Information using the same "
                  "degree of care it uses for its own, and no less than reasonable care; and (b) not "
                  "disclose it to any third party without prior written consent."),
            ("h", "3. Term"),
            ("p", "<b>This Agreement remains in effect for two (2) years from the Effective Date. "
                  "Confidentiality obligations survive for three (3) years after disclosure.</b>"),
            ("h", "4. Governing Law"),
            ("p", "<b>This Agreement is governed by the laws of the State of Washington, USA, without "
                  "regard to its conflict-of-laws principles.</b>"),
            ("h", "5. Limitation of Liability"),
            ("p", "<b>Neither party\u2019s aggregate liability under this Agreement shall exceed USD "
                  "100,000.</b>"),
            ("h", "6. Return of Materials"),
            ("p", "Upon request, each party shall return or destroy the other\u2019s Confidential "
                  "Information and, on request, certify such destruction in writing."),
            ("h", "7. No License"),
            ("p", "No license or intellectual-property right is granted except the limited right to use "
                  "Confidential Information for the Purpose."),
            ("h", "Signatures"),
            ("p", "Contoso Global, Inc.  ____________________     {{counterparty_name}}  "
                  "____________________"),
        ],
    )


def template_msa():
    build_reference_pdf(
        TEMPLATES_DIR / "MSA_template.pdf",
        "MASTER SERVICES AGREEMENT (APPROVED TEMPLATE)",
        "Approved template v5.1 - Owner: Legal Operations - Governing law: State of Washington, USA",
        [
            ("p", "This Master Services Agreement (\u201cAgreement\u201d) is entered into as of "
                  "{{effective_date}} between <b>Contoso Global, Inc.</b> (\u201cContoso\u201d) and "
                  "{{counterparty_name}} (\u201cSupplier\u201d)."),
            ("h", "1. Services"),
            ("p", "Supplier will perform the services described in one or more Statements of Work "
                  "(\u201cSOW\u201d) executed under this Agreement."),
            ("h", "2. Payment Terms"),
            ("p", "<b>Contoso shall pay undisputed invoices within sixty (60) days of receipt (Net 60).</b> "
                  "Late payments accrue interest at 1% per month."),
            ("h", "3. Term and Termination"),
            ("p", "<b>This Agreement has an initial term of one (1) year and renews automatically for "
                  "successive one-year terms unless either party gives ninety (90) days\u2019 written "
                  "notice of non-renewal.</b> Either party may terminate for material breach not cured "
                  "within thirty (30) days of notice."),
            ("h", "4. Intellectual Property"),
            ("p", "<b>All deliverables created for Contoso under a SOW are works made for hire; ownership "
                  "vests in Contoso upon payment.</b>"),
            ("h", "5. Indemnification"),
            ("p", "<b>Supplier shall indemnify Contoso against third-party claims arising from Supplier\u2019s "
                  "negligence, willful misconduct, or IP infringement.</b>"),
            ("h", "6. Limitation of Liability"),
            ("p", "<b>Except for indemnification and breaches of confidentiality, each party\u2019s "
                  "aggregate liability shall not exceed the fees paid under the applicable SOW in the "
                  "twelve (12) months preceding the claim.</b>"),
            ("h", "7. Insurance"),
            ("p", "Supplier shall maintain commercial general liability insurance of at least USD "
                  "2,000,000."),
            ("h", "8. Data Protection"),
            ("p", "<b>Supplier shall process Contoso personal data only per Contoso\u2019s written "
                  "instructions and the Data Processing Addendum, and shall comply with GDPR where "
                  "applicable.</b>"),
            ("h", "9. Governing Law"),
            ("p", "<b>This Agreement is governed by the laws of the State of Washington, USA.</b>"),
        ],
    )


def template_sow():
    build_reference_pdf(
        TEMPLATES_DIR / "SOW_template.pdf",
        "STATEMENT OF WORK (APPROVED TEMPLATE)",
        "Approved template v2.4 - Executed under the Master Services Agreement",
        [
            ("p", "SOW No. {{sow_number}}, effective {{effective_date}}, under the MSA between "
                  "<b>Contoso Global, Inc.</b> and {{counterparty_name}}."),
            ("h", "1. Scope of Work"),
            ("p", "{{scope_description}}"),
            ("h", "2. Deliverables &amp; Milestones"),
            ("table", [
                ["Milestone", "Description", "Due date", "Acceptance criteria"],
                ["M1", "{{m1}}", "{{m1_date}}", "Written acceptance by Contoso project lead"],
                ["M2", "{{m2}}", "{{m2_date}}", "Written acceptance by Contoso project lead"],
            ]),
            ("h", "3. Fees"),
            ("p", "<b>Fixed fee of {{fee}}, invoiced on milestone acceptance. Net 60 payment terms per "
                  "the MSA.</b>"),
            ("h", "4. Acceptance"),
            ("p", "<b>Contoso has ten (10) business days to accept or reject each deliverable in writing. "
                  "Silence is not acceptance.</b>"),
            ("h", "5. Term"),
            ("p", "This SOW begins on the Effective Date and ends on acceptance of the final milestone."),
            ("h", "6. Precedence"),
            ("p", "In case of conflict, the MSA governs except where this SOW expressly states otherwise."),
        ],
    )


# =========================================================================== clause library
def _clause(no, name, standard, acceptable, redflag):
    parts = [("h", f"CL-{no} - {name}"),
             ("p", f"<b>Standard:</b> {standard}")]
    if acceptable:
        parts.append(("p", f"<b>Acceptable range:</b> {acceptable}"))
    parts.append(("p", f"<b>Red flag:</b> {redflag}"))
    return parts


def clause_library():
    blocks = [
        ("p", "Enterprise-standard positions used to benchmark counterparty drafts. The <b>Clause &amp; "
              "Risk agent</b> compares incoming clauses to these standards and flags deviations with a "
              "risk score. Fallback (negotiation) positions are in the Negotiation Playbook."),
    ]
    blocks += _clause("01", "Payment Terms",
                      "Net 60 from receipt of undisputed invoice.",
                      "Net 45 - Net 75.",
                      "Net 30 or shorter (cash-flow impact); payment on signature.")
    blocks += _clause("02", "Limitation of Liability",
                      "Cap equal to fees paid in the trailing 12 months; carve-outs for confidentiality, "
                      "IP infringement, and indemnification.",
                      "Cap of 12-24 months\u2019 fees.",
                      "Uncapped liability; caps below 12 months\u2019 fees; no carve-outs.")
    blocks += _clause("03", "Indemnification",
                      "Supplier indemnifies Contoso for third-party claims from negligence, willful "
                      "misconduct, and IP infringement.",
                      "Mutual indemnity that preserves IP-infringement coverage.",
                      "Contoso-only indemnity; no IP infringement coverage.")
    blocks += _clause("04", "Term &amp; Auto-Renewal",
                      "1-year initial term; auto-renews for 1-year terms; 90 days\u2019 non-renewal notice.",
                      "Notice period of 30-90 days.",
                      "Auto-renewal notice period &gt; 90 days; multi-year lock-in without termination "
                      "for convenience.")
    blocks += _clause("05", "Governing Law",
                      "State of Washington, USA.",
                      "Delaware, New York (US); England &amp; Wales (EMEA deals).",
                      "Non-US/UK jurisdiction without Legal approval.")
    blocks += _clause("06", "Intellectual Property",
                      "Deliverables are works made for hire; ownership vests in Contoso on payment.",
                      "License-back of Supplier pre-existing tools, provided Contoso owns custom "
                      "deliverables.",
                      "Supplier retains ownership of deliverables; revocable license only.")
    blocks += _clause("07", "Data Protection",
                      "Processing per Contoso instructions + DPA; GDPR compliance where applicable.",
                      "Sub-processing permitted with prior written notice.",
                      "No DPA; sub-processing without notice; data stored outside approved regions.")
    blocks += _clause("08", "Confidentiality Term",
                      "Obligations survive 3 years after disclosure.",
                      "Survival of 2-5 years.",
                      "Perpetual confidentiality; survival &lt; 2 years.")
    blocks += _clause("09", "Termination",
                      "Termination for material breach with 30-day cure; termination for convenience with "
                      "60 days\u2019 notice.",
                      "Cure period of up to 45 days.",
                      "No termination for convenience; cure period &gt; 60 days.")
    blocks += _clause("10", "Insurance",
                      "Commercial general liability &ge; USD 2,000,000.",
                      "USD 1,000,000 - 2,000,000 with cyber coverage for data processors.",
                      "Coverage below USD 1,000,000; no cyber coverage for data processors.")
    blocks += _clause("11", "Assignment &amp; Change of Control",
                      "Neither party assigns without the other\u2019s consent; Contoso may assign to an "
                      "affiliate or successor.",
                      "Consent not to be unreasonably withheld.",
                      "One-sided assignment rights; free assignment on the counterparty\u2019s change of "
                      "control.")
    blocks += _clause("12", "Publicity &amp; Use of Marks",
                      "Neither party uses the other\u2019s name or marks without prior written consent.",
                      "Logo use limited to an approved customer list.",
                      "Unrestricted publicity rights; press releases without approval.")
    build_reference_pdf(
        CLAUSE_DIR / "standard_clauses.pdf",
        "CONTOSO GLOBAL - STANDARD CLAUSE LIBRARY",
        "Enterprise-standard positions (CL-01 ... CL-12) - Owner: Office of the General Counsel",
        blocks,
    )


# =========================================================================== policies
def contracting_policy():
    build_reference_pdf(
        POLICY_DIR / "contracting_policy.pdf",
        "CONTOSO GLOBAL - CONTRACTING POLICY (EXCERPT)",
        "Owner: Office of the General Counsel - Audience: Legal, Procurement, Sales - Classification: Internal",
        [
            ("p", "These policies govern how Contoso agents and employees draft, review, and approve "
                  "contracts. The <b>agents must follow these rules and must refuse to give legal "
                  "advice</b> \u2014 they assist Legal, they do not replace counsel."),
            ("h", "P-1 - Approved templates only"),
            ("p", "New agreements must start from an <b>approved template</b> (NDA v3.2, MSA v5.1, SOW "
                  "v2.4). Non-standard structures require Legal review before sending to a counterparty."),
            ("h", "P-2 - Approval thresholds"),
            ("table", [
                ["Deal value (TCV)", "Approver"],
                ["&lt; USD 50,000", "Procurement manager"],
                ["USD 50,000 - 250,000", "Legal counsel"],
                ["&gt; USD 250,000", "General Counsel + Finance VP"],
            ]),
            ("h", "P-3 - Non-negotiable terms"),
            ("p", "Governing law outside US/UK, uncapped liability, and perpetual confidentiality are "
                  "<b>non-negotiable</b> and require General Counsel sign-off."),
            ("h", "P-4 - Risk scoring"),
            ("p", "Every counterparty draft is scored <b>Low / Medium / High</b> against the Standard "
                  "Clause Library. Any <b>High</b> clause blocks auto-approval and routes to Legal."),
            ("h", "P-5 - Renewals"),
            ("p", "Contracts with auto-renewal are reviewed <b>90 days before</b> the renewal date. A "
                  "missed review that results in an unwanted auto-renewal is a reportable process "
                  "failure."),
            ("h", "P-6 - Human sign-off"),
            ("p", "No contract is executed by an agent. Agents draft, analyze, and recommend; <b>a human "
                  "approves and signs.</b> All agent actions are traced and auditable."),
            ("h", "P-7 - No legal advice"),
            ("p", "Agents provide contract <b>information and analysis grounded in Contoso\u2019s "
                  "corpus</b>. They must not provide legal opinions, interpret law for the counterparty, "
                  "or advise on litigation. When asked for legal advice, the agent refuses and refers the "
                  "user to Legal."),
        ],
    )


def delegation_of_authority():
    build_reference_pdf(
        POLICY_DIR / "delegation_of_authority.pdf",
        "CONTOSO GLOBAL - DELEGATION OF AUTHORITY (SIGNATURE MATRIX)",
        "Owner: Office of the General Counsel + Finance - Classification: Internal",
        [
            ("p", "This matrix defines who may approve and sign contractual commitments on behalf of "
                  "Contoso Global. It complements the Contracting Policy approval thresholds and is used "
                  "by the agents to route approvals; agents never sign."),
            ("h", "DOA-1 - Signature authority by total contract value (TCV)"),
            ("table", [
                ["TCV band", "Business approver", "Legal approver", "Signatory"],
                ["&lt; USD 50,000", "Procurement manager", "Not required (standard template)", "Procurement director"],
                ["USD 50,000 - 250,000", "Department VP", "Legal counsel", "VP, Procurement"],
                ["USD 250,000 - 1,000,000", "Business unit SVP", "General Counsel", "CFO or delegate"],
                ["&gt; USD 1,000,000", "CEO staff", "General Counsel", "CEO or CFO"],
            ]),
            ("h", "DOA-2 - Clause-triggered escalation"),
            ("p", "Regardless of value, any contract containing a <b>non-negotiable</b> deviation "
                  "(governing law outside US/UK, uncapped liability, or perpetual confidentiality) "
                  "escalates to the <b>General Counsel</b> for sign-off."),
            ("h", "DOA-3 - Renewals and amendments"),
            ("p", "Amendments and renewals follow the same bands based on the <b>incremental</b> value. "
                  "An auto-renewal that increases annual value by more than 15% requires re-approval at "
                  "the appropriate band."),
            ("h", "DOA-4 - Segregation of duties"),
            ("p", "The business approver, legal approver, and signatory must be <b>three different "
                  "people</b>. All approvals are recorded in the CLM system and are auditable."),
        ],
    )


# =========================================================================== playbook
def negotiation_playbook():
    build_reference_pdf(
        PLAYBOOK_DIR / "negotiation_playbook.pdf",
        "CONTOSO GLOBAL - CONTRACT NEGOTIATION PLAYBOOK",
        "Fallback positions and escalation guidance - Owner: Legal Operations - Classification: Internal",
        [
            ("p", "When a counterparty rejects a Standard Clause Library position, negotiators (and the "
                  "drafting agent, as guidance only) may offer the <b>fallback</b> below before "
                  "escalating. Anything beyond the fallback requires the approver named in the "
                  "Delegation of Authority."),
            ("h", "Payment Terms (CL-01)"),
            ("p", "<b>Fallback:</b> accept Net 45 in exchange for a 1% early-payment discount. "
                  "<b>Escalate</b> below Net 45."),
            ("h", "Limitation of Liability (CL-02)"),
            ("p", "<b>Fallback:</b> accept a cap of up to 24 months\u2019 fees provided carve-outs for "
                  "confidentiality and IP infringement remain. <b>Escalate</b> any uncapped liability or "
                  "removal of carve-outs to the General Counsel."),
            ("h", "Indemnification (CL-03)"),
            ("p", "<b>Fallback:</b> mutual indemnity is acceptable if IP-infringement coverage is "
                  "preserved. <b>Escalate</b> any removal of IP-infringement indemnity."),
            ("h", "Governing Law (CL-05)"),
            ("p", "<b>Fallback:</b> England &amp; Wales for EMEA counterparties. <b>Escalate</b> any "
                  "other non-US jurisdiction to Legal before agreeing."),
            ("h", "Confidentiality Term (CL-08)"),
            ("p", "<b>Fallback:</b> up to 5 years for sensitive technical information. <b>Escalate</b> "
                  "perpetual confidentiality; it is non-negotiable."),
            ("h", "Assignment &amp; Change of Control (CL-11)"),
            ("p", "<b>Fallback:</b> consent not to be unreasonably withheld, with Contoso free to assign "
                  "to affiliates. <b>Escalate</b> one-sided assignment rights."),
            ("h", "Escalation contacts"),
            ("p", "Standard clauses: Legal counsel (legal@contoso.com). Non-negotiable terms and "
                  "deals &gt; USD 250,000: General Counsel."),
        ],
    )


def main():
    print("Generating CLM corpus PDFs into src/data ...")
    print("- executed contracts")
    contract_ct4821()
    contract_ct3390()
    contract_ct5102()
    contract_ct2765()
    contract_ct6033()
    print("- inbound counterparty drafts")
    draft_acme()
    draft_globex()
    print("- approved templates")
    template_nda()
    template_msa()
    template_sow()
    print("- clause library")
    clause_library()
    print("- policies")
    contracting_policy()
    delegation_of_authority()
    print("- playbook")
    negotiation_playbook()
    print("Done.")


if __name__ == "__main__":
    main()
