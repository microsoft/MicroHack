"""Coach DAX interface shared by model enrichment and report generation."""

CHF = '#,0.00 "CHF";-#,0.00 "CHF";0.00 "CHF"'
PERCENT = "0.00%;-0.00%;0.00%"
SNAPSHOT = """VAR SelectedDates = VALUES('DimDate'[Date])
RETURN MAXX(
    FILTER(ALL('DimDate'), 'DimDate'[IsMonthEnd] = TRUE()
        && 'DimDate'[Date] IN SelectedDates),
    'DimDate'[Date])"""


def measures(scenario):
    """Return {name: (DAX, format, description)} on existing fact tables."""
    result = {
        "As-of Date": (SNAPSHOT, "yyyy-MM-dd",
                       "Latest selected declared month-end; not last nonempty fact date.")
    }

    def add(name, dax, fmt, description):
        result[name] = (dax, fmt, description)

    if scenario == "banking":
        fact = "'FactLoanMonthlySnapshot'"
        add("Portfolio Scope Valid", "NOT ISCROSSFILTERED('DimChannel')",
            "0", "Channel does not describe loan snapshots; grouping is also guarded.")
        add("Activity Scope Valid", "NOT ISCROSSFILTERED('DimRiskBand')",
            "0", "Risk band does not describe transaction activity.")
        for name, expr, fmt in (
            ("Transaction Count", "COUNTROWS('FactTransactions')", "#,0"),
            ("Transaction Amount", "DIVIDE(SUM('FactTransactions'[AmountCents]), 100)", CHF),
            ("Fee Income", "DIVIDE(SUM('FactTransactions'[FeeCents]), 100)", CHF),
        ):
            add(name, f"IF([Activity Scope Valid], COALESCE({expr}, 0))", fmt,
                "Posted gross activity in selected dates; risk scope unsupported. Not loan revenue.")

        def at_snapshot(expr):
            return (f"VAR T = [As-of Date]\n"
                    f"RETURN IF([Portfolio Scope Valid] && NOT ISBLANK(T),\n"
                    f"CALCULATE({expr}, REMOVEFILTERS('DimDate'), 'DimDate'[Date] = T))")

        add("Outstanding Loan Balance", at_snapshot(f"DIVIDE(SUM({fact}[OutstandingCents]), 100)"),
            CHF, "Outstanding at the selected month-end, never summed across months.")
        add("Active Loans", at_snapshot(f"COALESCE(CALCULATE(DISTINCTCOUNT({fact}[LoanId]), "
                                       f"{fact}[OutstandingCents] > 0), 0)"),
            "#,0", "Loans at the same declared snapshot; zero for an empty valid slice.")
        add("Nonperforming Balance", at_snapshot(
            f"DIVIDE(COALESCE(CALCULATE(SUM({fact}[OutstandingCents]), "
            f"{fact}[IsNonperforming] = TRUE()), 0), 100)"),
            CHF, "Nonperforming outstanding at the same snapshot as the denominator.")
        add("Nonperforming Balance Ratio",
            "DIVIDE([Nonperforming Balance], [Outstanding Loan Balance])",
            PERCENT, "Amount-weighted nonperforming balance ratio, not a default-count rate.")
        add("Weighted Average Loan Rate", at_snapshot(
            f"DIVIDE(DIVIDE(SUMX({fact}, {fact}[OutstandingCents] * "
            f"{fact}[RateUnits]), SUM({fact}[OutstandingCents])), 1000000)"),
            PERCENT, "Outstanding-weighted annual fractional rate at the same snapshot.")
        add("Prior-Year Loan Balance", """VAR T = [As-of Date]
VAR PY = IF(NOT ISBLANK(T), EOMONTH(T, -12))
VAR Available = COUNTROWS(FILTER(ALL('DimDate'), 'DimDate'[Date] = PY))
RETURN IF([Portfolio Scope Valid] && NOT ISBLANK(T) && Available = 1,
    CALCULATE([Outstanding Loan Balance], REMOVEFILTERS('DimDate'), 'DimDate'[Date] = PY))""",
            CHF, "Same calendar month-end in prior year; February maps to leap day correctly.")
        add("Loan Balance YoY %",
            "IF(NOT ISBLANK([Outstanding Loan Balance]) && NOT ISBLANK([Prior-Year Loan Balance]), "
            "DIVIDE([Outstanding Loan Balance] - [Prior-Year Loan Balance], [Prior-Year Loan Balance]))",
            PERCENT, "Blank when the prior-year snapshot is absent or zero.")
        add("Scope Status", """SWITCH(TRUE(),
NOT [Portfolio Scope Valid], "Channel not defined for loan snapshots",
NOT [Activity Scope Valid], "Risk not defined for transactions",
ISBLANK([As-of Date]), "No selected month-end",
"Valid scope; portfolio uses displayed as-of date")""", "",
            "Explains unsupported dimensions and missing snapshot; not a security control.")
    elif scenario == "insurance":
        add("Complete Months Valid", """VAR SelectedDays = COUNTROWS(VALUES('DimDate'[Date]))
VAR RequiredDays = SUMX(VALUES('DimDate'[MonthKey]),
    VAR M = 'DimDate'[MonthKey]
    RETURN DAY(EOMONTH(DATE(INT(M / 100), MOD(M, 100), 1), 0)))
RETURN SelectedDays > 0 && SelectedDays = RequiredDays""",
            "0", "True only for a nonempty union of whole calendar months.")
        add("Premium Scope Valid", "NOT ISCROSSFILTERED('DimClaimType')",
            "0", "Claim type has no premium allocation; guards filters and grouping.")
        for name, table, column, premium in (
            ("Written Premium", "FactPremiumMonthly", "WrittenPremiumCents", True),
            ("Earned Premium", "FactPremiumMonthly", "EarnedPremiumCents", True),
            ("Paid Claims", "FactClaimTransactions", "PaidCents", False),
            ("Recoveries", "FactClaimTransactions", "RecoveryCents", False),
            ("Change in Claim Reserves", "FactClaimTransactions", "ReserveMovementCents", False),
        ):
            guard = "[Complete Months Valid]" + (" && [Premium Scope Valid]" if premium else "")
            add(name, f"IF({guard}, DIVIDE(COALESCE(SUM('{table}'[{column}]), 0), 100))",
                CHF, "Complete selected months; integer rappen aggregated before scaling to CHF.")
        add("Incurred Claims",
            "IF([Complete Months Valid], [Paid Claims] - [Recoveries] + [Change in Claim Reserves])",
            CHF, "Paid minus positive recoveries plus signed reserve movement, not reserve balance.")
        add("Loss Ratio",
            "IF([Complete Months Valid] && [Premium Scope Valid], DIVIDE([Incurred Claims], [Earned Premium]))",
            PERCENT, "Aligned complete-month incurred/earned; blank for zero/invalid denominator.")
        add("Claims with Activity", """IF([Complete Months Valid],
COALESCE(DISTINCTCOUNT('FactClaimTransactions'[ClaimId]), 0))""",
            "#,0", "Distinct claims with a financial movement; not newly reported claims.")
        add("Active Policies at Month-End", """VAR T = [As-of Date]
RETURN IF([Premium Scope Valid] && NOT ISBLANK(T),
CALCULATE(COALESCE(DISTINCTCOUNT('FactPremiumMonthly'[PolicyId]), 0),
REMOVEFILTERS('DimDate'), 'DimDate'[Date] = T, 'FactPremiumMonthly'[IsActive] = TRUE()))""",
            "#,0", "Active policies at latest selected declared month-end, not sum of months.")
        add("Earned Premium Prior Year", """VAR Months = VALUES('DimDate'[MonthKey])
VAR PYMonths = SELECTCOLUMNS(Months, "MonthKey", 'DimDate'[MonthKey] - 100)
VAR Available = CALCULATE(DISTINCTCOUNT('DimDate'[MonthKey]),
    REMOVEFILTERS('DimDate'), TREATAS(PYMonths, 'DimDate'[MonthKey]))
RETURN IF([Complete Months Valid] && [Premium Scope Valid] && Available = COUNTROWS(Months),
    CALCULATE([Earned Premium], REMOVEFILTERS('DimDate'), TREATAS(PYMonths, 'DimDate'[MonthKey])))""",
            CHF, "Entire comparable prior-year month set must exist, otherwise blank.")
        add("Earned Premium YoY %",
            "IF(NOT ISBLANK([Earned Premium]) && NOT ISBLANK([Earned Premium Prior Year]), "
            "DIVIDE([Earned Premium] - [Earned Premium Prior Year], [Earned Premium Prior Year]))",
            PERCENT, "Blank for missing/zero prior-year earned premium.")
        add("Scope Status", """SWITCH(TRUE(),
NOT [Complete Months Valid], "Complete months required",
NOT [Premium Scope Valid], "Claim-type premium allocation unavailable",
ISBLANK([As-of Date]), "No selected month-end",
"Valid complete-month scope")""", "", "Explains period and premium-allocation validity.")
    else:
        raise ValueError(f"Unknown scenario: {scenario}")
    return result


def measure_table(scenario, name):
    if scenario == "banking":
        return "FactTransactions" if name in {
            "Transaction Count", "Transaction Amount", "Fee Income", "Activity Scope Valid"
        } else "FactLoanMonthlySnapshot"
    return "FactClaimTransactions" if name in {
        "Paid Claims", "Recoveries", "Change in Claim Reserves",
        "Incurred Claims", "Claims with Activity"
    } else "FactPremiumMonthly"
