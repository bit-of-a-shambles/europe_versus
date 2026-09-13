# Common Values launch calendar

The September launch is built around four American misconceptions about Europe. October continues with four claims about the European economic model. Each edition corrects the lazy version of the claim, concedes the part the evidence supports, and ends with a practical European reform question. Every post contains one chart, 300–600 words, phone-safe labels, methodology, alt text, exact CSV data and distinct Substack preview copy.

## September launch

| Issue | Date | Post | Chart | The correction | Status |
| ---: | --- | --- | --- | --- | --- |
| 01 | 4 Sep 2026 | Europe's income growth moved east | Ranked bars, 26 EU countries | Europe did grow, but the strongest household gains happened outside the western capitals | Website lead |
| 02 | 11 Sep 2026 | The productivity gap is real. The lazy-European story is not. | Ranked bars, full OECD figure | The EU average trails the US; several European economies already work at the frontier | Unpublished draft |
| 03 | 18 Sep 2026 | Europe's innovation problem begins after the patent | Ranked bars, EPO applications | Europe produces inventions; its larger failure is financing and scaling firms | Unpublished draft |
| 04 | 25 Sep 2026 | Europe met the 2% defence target. Spending isn't strategy. | Annual line, 2014–2025 | Burden-sharing improved sharply; procurement and industrial capacity are the next test | Unpublished draft |

## October editions

| Issue | Date | Post | Chart | The correction | Status |
| ---: | --- | --- | --- | --- | --- |
| 05 | 2 Oct 2026 | Europe did not shrink its way to lower emissions | Indexed lines: EU output and net greenhouse-gas emissions, 1990=100 | Europe cut emissions while its economy grew; the remaining sectors are the harder part | Reporting queue |
| 06 | 9 Oct 2026 | The European welfare state did not empty the workplace | Ranked dots: comparable working-age employment rates across Europe and the US | High social spending and high employment can coexist; Europe’s aggregate still hides national failures | Reporting queue |
| 07 | 16 Oct 2026 | Europe has a single market for goods, not services | Paired lines: intra-EU goods and services trade as a share of GDP | Europe removed many borders for goods while services still face twenty-seven national markets | Reporting queue |
| 08 | 23 Oct 2026 | The best labour markets protect movement, not particular jobs | Scatter: job-changing and re-employment across 25 EU countries and Switzerland, with a separate US benchmark | Worker security and economic adaptation are complements when institutions protect people through job changes | Reporting queue |

30 October is held open for a topical edition, a launch retrospective or a reporting delay.

### Issue 08 reporting brief: flexicurity across Europe

**Question:** Do labour markets deliver better outcomes when they make it easier to move between jobs while protecting workers through the transition?

**Chart:** Put the probability that an employed worker changes jobs between quarters in 2025 on the horizontal axis. Put the share of people unemployed in 2024 who were employed in 2025 on the vertical axis. Plot the 25 EU countries with both measures and Switzerland. Add the European trend line, but exclude the United States from it.

**United States treatment:** Show the US as a visibly distinct reference point using Census Job-to-Job Flows and, if needed, BLS Current Population Survey flows. Its monthly or quarterly methodology is not directly comparable with Eurostat, so label it as a benchmark rather than another observation in the European series.

**Working finding:** Across the comparable European observations, job mobility and re-employment have a positive association (preliminary Pearson correlation: about 0.71). Switzerland combines a 3% job-change probability with a 47.4% re-employment rate. Denmark and the Netherlands sit toward the high-mobility, high-re-employment corner. Italy, Romania and Slovakia show the opposite pattern.

**Interpretation:** The chart is descriptive, not causal. Flexibility without unemployment protection, training, placement services or worker voice can simply become precarity. The edition should explain how several European systems combine these institutions differently, with Switzerland and the US as useful contrasting models—not present Denmark as the sole template.

**Sources:** [Eurostat labour-market flows](https://ec.europa.eu/eurostat/statistics-explained/SEPDF/cache/44746.pdf?v=9380166952661952), Eurostat datasets `lfsi_long_a` and `lfsi_long_e07`, [US Census Job-to-Job Flows](https://lehd.ces.census.gov/data/), [BLS CPS labour-force flows](https://www.bls.gov/cps/cps_flows.htm) and the [OECD cross-country transitions paper](https://www.oecd.org/en/publications/labour-market-transitions-across-oecd-countries-stylised-facts_62c85872-en.html).

## Preview text

1. The stagnation story misses the largest income gains in the European Union.
2. Europe works fewer hours. That does not mean every European hour produces less.
3. Europe does not lack invention. It loses too much ground between invention and scale.
4. The old spending argument is ending. The harder argument is about what Europe buys.
5. Europe cut emissions while its economy grew. The remaining sectors are the harder part.
6. Europe’s employment rate is at a record. The continental average still hides serious failures.
7. Europe removed borders for goods. Services still meet twenty-seven markets.
8. Europe does not have to choose between protecting workers and allowing its economy to change.

## Draft workflow

The task below creates a reviewable Substack draft and does not publish it:

```bash
PUBLIC_BASE_URL=https://commonvalues.eu \
SUBSTACK_API_URL=https://interessant3.substack.com/api/v1 \
bin/rails "editions:substack_draft[2026-09-04-europes-income-growth-moved-east]"
```

Repeat with the other three slugs in `content/editions`. The task creates the title, subtitle, opening paragraph, phone-first chart image, remaining reporting, source section and subscribe widget. It prints the preview text for manual placement because the current Substack library does not expose that field.

## Publication gate

- Run `bin/rails runner analysis/launch_month/verify.rb`.
- Review the web chart and exported image at 320px, 360px and 390px.
- Check each source and methodology link.
- Paste the preview text into Substack.
- Send a test email and inspect it on a physical phone.
- Publish only after editorial approval; all four Substack posts remain drafts until then.
