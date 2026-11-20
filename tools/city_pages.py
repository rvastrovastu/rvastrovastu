#!/usr/bin/env python3
"""Builds the city pages in cities/ for Indians living abroad.

Each page lists the coming year's Purnima and Amavasya tithis in the city's
own time zone next to India time, which is the usual reason festival days
abroad differ from the family calendar back home.

Run once a year (or when adding a city), from the repository root:
    pip install pyswisseph
    python3 tools/city_pages.py
"""
import datetime as dt
import html
import os
from zoneinfo import ZoneInfo

import swisseph as swe

SITE = "https://rvastrovastu.github.io/rvastrovastu"
PLAY = "https://play.google.com/store/apps/details?id=com.rvastrovastu.app"
IST = ZoneInfo("Asia/Kolkata")

CITIES = [
    ("new-york", "New York & New Jersey", "America/New_York", "US"),
    ("dallas", "Dallas–Fort Worth", "America/Chicago", "US"),
    ("houston", "Houston", "America/Chicago", "US"),
    ("chicago", "Chicago", "America/Chicago", "US"),
    ("bay-area", "the San Francisco Bay Area", "America/Los_Angeles", "US"),
    ("toronto", "Toronto", "America/Toronto", "CA"),
    ("london", "London", "Europe/London", "GB"),
    ("sydney", "Sydney", "Australia/Sydney", "AU"),
    ("dubai", "Dubai", "Asia/Dubai", "AE"),
    ("singapore", "Singapore", "Asia/Singapore", "SG"),
]

# Amanta month that begins at a new moon, by the Sun's sidereal sign then.
MONTHS = ["Chaitra", "Vaishakha", "Jyeshtha", "Ashadha", "Shravana",
          "Bhadrapada", "Ashwin", "Kartika", "Margashirsha", "Pausha",
          "Magha", "Phalguna"]
# Sun's sidereal sign index (Aries = 0) at the new moon -> month index.
SIGN_TO_MONTH = {11: 0, 0: 1, 1: 2, 2: 3, 3: 4, 4: 5, 5: 6, 6: 7, 7: 8,
                 8: 9, 9: 10, 10: 11}

PURNIMA_NOTES = {
    "Vaishakha": "Buddha Purnima", "Ashadha": "Guru Purnima",
    "Shravana": "Raksha Bandhan", "Ashwin": "Sharad Purnima",
    "Kartika": "Kartik Purnima, Dev Deepawali", "Phalguna": "Holika Dahan",
    "Margashirsha": "Dattatreya Jayanti", "Pausha": "Shakambhari Purnima",
    "Magha": "Magha Purnima", "Chaitra": "Hanuman Jayanti",
    "Jyeshtha": "Vat Purnima",
}
# Notes for the Amavasya that ends the named amanta month.
AMAVASYA_NOTES = {
    "Ashwin": "Diwali, Lakshmi Puja", "Bhadrapada": "Mahalaya Amavasya",
    "Pausha": "Mauni Amavasya", "Ashadha": "Hariyali / Deep Amavasya",
    "Shravana": "Pithori Amavasya", "Vaishakha": "Shani Jayanti",
}

swe.set_sid_mode(swe.SIDM_LAHIRI)


def elongation(jd):
    sun = swe.calc_ut(jd, swe.SUN)[0][0]
    moon = swe.calc_ut(jd, swe.MOON)[0][0]
    return (moon - sun) % 360


def crossing(jd, target):
    """First moment after jd when the Moon-Sun elongation reaches target."""
    step = 0.25
    a = jd
    while True:
        b = a + step
        da = (elongation(a) - target) % 360
        db = (elongation(b) - target) % 360
        if da > 300 and db < 60:  # stepped past the target
            break
        a = b
        if a - jd > 40:
            raise RuntimeError("no crossing")
    lo, hi = a, b
    for _ in range(50):
        mid = (lo + hi) / 2
        if (elongation(mid) - target) % 360 > 180:
            lo = mid
        else:
            hi = mid
    return hi


def to_dt(jd):
    y, m, d, h = swe.revjul(jd)
    base = dt.datetime(y, m, d, tzinfo=dt.timezone.utc)
    return base + dt.timedelta(hours=h)


def sun_sign(jd):
    lon = swe.calc_ut(jd, swe.SUN, swe.FLG_SIDEREAL)[0][0]
    return int(lon // 30)


def lunar_year(start, months=13):
    """Purnima and Amavasya tithis (start and end) for about a year."""
    jd = swe.julday(start.year, start.month, start.day, 0)
    events = []
    # Begin from the new moon before start so the first month is named.
    nm = crossing(jd - 31, 0)
    while to_dt(nm) < start - dt.timedelta(days=30):
        nm = crossing(nm + 1, 0)
    for _ in range(months):
        next_nm = crossing(nm + 1, 0)
        month = MONTHS[SIGN_TO_MONTH[sun_sign(nm)]]
        adhik = sun_sign(nm) == sun_sign(next_nm)  # no sankranti: extra month
        name = ("Adhik " if adhik else "") + month
        # Purnima tithi: elongation 168 -> 180.
        p_start, p_end = crossing(nm + 10, 168), crossing(nm + 10, 180)
        # Amavasya tithi ending this month: 348 -> 360.
        a_start, a_end = crossing(next_nm - 3, 348), next_nm
        events.append(("Purnima", name, to_dt(p_start), to_dt(p_end),
                       None if adhik else PURNIMA_NOTES.get(month)))
        events.append(("Amavasya", name, to_dt(a_start), to_dt(a_end),
                       None if adhik else AMAVASYA_NOTES.get(month)))
        nm = next_nm
    end = start + dt.timedelta(days=366)
    return [e for e in events if start <= e[3] and e[2] <= end]


def fmt(t, zone):
    local = t.astimezone(zone)
    return local.strftime("%a %b %-d, %-I:%M %p")


def offset_text(zone, year):
    jan = dt.datetime(year, 1, 15, 12, tzinfo=zone)
    jul = dt.datetime(year, 7, 15, 12, tzinfo=zone)

    def gap(t):
        mins = (t.astimezone(IST).utcoffset() - t.utcoffset()).total_seconds() / 60
        h, m = divmod(abs(int(mins)), 60)
        ahead = "ahead of" if mins > 0 else "behind"
        return f"{h} h {m:02d} min" if m else f"{h} hours", ahead

    a, b = gap(jan), gap(jul)
    if a == b:
        return f"India is {a[0]} {a[1]} {{city}} all year"
    return (f"India is {a[0]} {a[1]} {{city}} in January and {b[0]} "
            f"{b[1].replace(' of', '')} in July, because of daylight "
            "saving time")


STYLE = open(os.path.join(os.path.dirname(__file__), "city_page.css")).read()


def page(slug, city, tzname, country, events, others, generated):
    zone = ZoneInfo(tzname)
    rows = []
    differs = None
    for kind, month, s, e, note in events:
        local_day = s.astimezone(zone).date()
        india_day = s.astimezone(IST).date()
        mark = local_day != india_day
        if mark and differs is None:
            differs = (kind, month, s)
        label = f"{month} {kind}"
        rows.append(
            "<tr{cls}><td><b>{label}</b>{note}</td><td>{ls} – {le}"
            '<span class="ist"><br><small>India: {is_} – {ie}</small></span>'
            '</td><td class="istcol">{is_} – {ie}</td></tr>'.format(
                cls=' class="diff"' if mark else "",
                label=html.escape(label),
                note=f"<br><small>{html.escape(note)}</small>" if note else "",
                ls=fmt(s, zone), le=fmt(e, zone),
                is_=fmt(s, IST), ie=fmt(e, IST)))
    offset = offset_text(zone, generated.year).replace("{city}", city)
    example = ""
    if differs:
        kind, month, s = differs
        example = (
            f"<p>For example, {html.escape(month)} {kind} begins on "
            f"<b>{s.astimezone(zone):%A, %B %-d}</b> in {html.escape(city)} "
            f"but on <b>{s.astimezone(IST):%A, %B %-d}</b> in India. Rows "
            "where the starting day is different are highlighted.</p>")
    links = " · ".join(
        f'<a href="{o[0]}.html">{html.escape(o[1].replace("the ", "", 1))}</a>'
        for o in others if o[0] != slug)
    title = f"Hindu calendar & Panchang in {city.replace('the ', '', 1)}"
    desc = (f"Purnima and Amavasya dates and times for {city} with India "
            "time alongside, why festival days differ abroad, and a Vedic "
            "astrology app that calculates for where you live.")
    url = f"{SITE}/cities/{slug}.html"
    ld = (
        '{"@context":"https://schema.org","@type":"WebPage","name":%s,'
        '"description":%s,"url":%s,"inLanguage":"en",'
        '"isPartOf":{"@type":"WebSite","name":"RV Astro Vastu","url":"%s/"}}'
        % (_j(title), _j(desc), _j(url), SITE))
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(title)} | RV Astro Vastu</title>
<meta name="description" content="{html.escape(desc)}">
<link rel="canonical" href="{url}">
<meta property="og:type" content="article">
<meta property="og:site_name" content="RV Astro Vastu">
<meta property="og:title" content="{html.escape(title)}">
<meta property="og:description" content="{html.escape(desc)}">
<meta property="og:url" content="{url}">
<meta property="og:image" content="{SITE}/assets/site/og-image.png">
<meta name="theme-color" content="#0d1033">
<script type="application/ld+json">{ld}</script>
<style>{STYLE}</style>
</head>
<body>
<main>
<p class="crumb"><a href="../">RV Astro Vastu</a> › Cities</p>
<h1>{html.escape(title)}</h1>
<p class="lead">If you live in {html.escape(city)}, your Ekadashi, Purnima or
Diwali can fall on a different day from the calendar your family uses in
India. Nothing is wrong: a tithi starts at the same moment everywhere, but
that moment lands on a different clock time, and sometimes a different date,
where you are. {offset}.</p>
{example}
<h2>Purnima and Amavasya, {generated:%B %Y} to {(generated + dt.timedelta(days=365)):%B %Y}</h2>
<p class="note">When each full-moon and new-moon tithi starts and ends, in
{html.escape(city)} time ({tzname}) and India time. Months are amanta (the
month ends at Amavasya). Festivals are usually kept on the day the tithi
covers at sunrise, or in the evening for Diwali, so your temple may choose
the day before or after the start date shown.</p>
<div class="table"><table>
<thead><tr><th>Tithi</th><th>{html.escape(city.replace("the ", "", 1))}</th><th class="istcol">India (IST)</th></tr></thead>
<tbody>
{chr(10).join(rows)}
</tbody></table></div>
<h2>Panchang for where you actually live</h2>
<p>RV Astro Vastu calculates sunrise, tithi, Rahu Kaal, Choghadiya, Hora and
muhurat for your own city, and keeps every family member's Kundli on their
real birth place and time zone, so a chart made in India stays correct in
{html.escape(city)}. It works in English and 10 Indian languages, and you can
book a one-to-one consultation at a fixed price, shown in your currency
before you pay, at a time listed in your time zone.</p>
<p class="center"><a class="cta" href="{PLAY}">Get it on Google Play</a></p>
<h2>Other cities</h2>
<p class="links">{links}</p>
<footer>
<a href="../legal/privacy.html">Privacy</a>
<a href="../legal/terms.html">Terms</a>
<p>Times calculated with the Swiss Ephemeris (Lahiri ayanamsa for month
names). Updated {generated:%B %-d, %Y}.</p>
</footer>
</main>
</body>
</html>
"""


def _j(s):
    import json
    return json.dumps(s, ensure_ascii=False)


def main():
    root = os.path.join(os.path.dirname(__file__), "..")
    out = os.path.join(root, "cities")
    os.makedirs(out, exist_ok=True)
    generated = dt.datetime.now(dt.timezone.utc).replace(
        hour=0, minute=0, second=0, microsecond=0)
    events = lunar_year(generated)
    for slug, city, tzname, country in CITIES:
        with open(os.path.join(out, f"{slug}.html"), "w") as f:
            f.write(page(slug, city, tzname, country, events, CITIES,
                         generated))
    print(f"{len(CITIES)} pages, {len(events)} tithis each")


if __name__ == "__main__":
    main()
