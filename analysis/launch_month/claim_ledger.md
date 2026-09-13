# Launch month claim ledger

| Issue | Material claim | Calculation or test | Primary source | Main limitation |
| --- | --- | --- | --- | --- |
| 01 | Real adjusted household income per person rose 134% in Romania, 95% in Lithuania and 91% in Poland from 2004 to 2024; the EU aggregate rose 22%. | For each country: `(index_2024 / index_2004 - 1) × 100`; compare Eurostat's published aggregate. | Eurostat `nasa_10_ki`, item `B7G_R_HAB_2010`, households and NPISH | Bulgaria lacks a 2004 value; a national average does not show distribution; faster catch-up starts from a lower base. |
| 02 | EU GDP per hour was 24.6% below the US in 2024, while Denmark and Belgium exceeded the US level. | `(84.1147 - 63.3819) / 84.1147 = 24.65%`; rank all 38 rows in the OECD figure. | OECD Productivity Database and National Accounts | Ireland and Luxembourg GDP values are distorted by cross-border income; sector mix and capital intensity matter. |
| 03 | The EU-27 filed 152.9 European patent applications per million residents in 2025, compared with 135.4 from the US; several European countries ranked far higher. | Reproduce the EPO top-country table and EU-27 aggregate from the source workbook. | European Patent Office, Patent Index 2025 | The venue favours European applicants; applications are not grants, quality-adjusted patents or commercial outcomes. |
| 04 | NATO Europe and Canada raised defence expenditure from 1.40% of combined GDP in 2014 to an estimated 2.27% in 2025; NATO's current summary reports more than $571bn at 2021 prices and a greater-than-$90bn annual increase. | Reproduce the 12 annual ratios from NATO table 3 and match the current NATO summary. | NATO defence-expenditure tables and current commitment summary | The aggregate includes Canada, membership changes, and the final two years are estimates; spending is not capability. |

## Editorial checks

- Each edition makes one visual argument and includes one primary chart.
- Every chart value is recomputed by `analysis/launch_month/verify.rb` from a preserved first-party file.
- The body states the strongest counter-evidence: western stagnation, the EU–US aggregate gap, EPO home bias and the difference between budgets and capability.
- Causal explanations are described as plausible context unless the cited evidence supports a stronger claim.
- The final language pass removed stock AI transitions, false binaries, vague attribution and ornamental conclusions.

## Reporting disclosure

OpenAI Codex assisted with retrieval, calculations, chart implementation and draft prose. The preserved sources and verification script allow every numerical claim to be audited. A human editor remains responsible for the final publication decision.
