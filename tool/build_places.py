"""Builds assets/places/*.tsv for the place-of-birth search.

Source: GeoNames (CC BY 4.0) via https://github.com/lutangar/cities.json
(cities.json and admin1.json). Usage:
  pip install pycountry
  python3 tool/build_places.py <folder with cities.json, admin1.json> assets/places
"""
import json, unicodedata, os, sys
import pycountry
src = sys.argv[1]
out = sys.argv[2]
cities = json.load(open(f'{src}/cities.json'))
admin = json.load(open(f'{src}/admin1.json'))

def strip(s):
    s = unicodedata.normalize('NFKD', s)
    return ''.join(c for c in s if not unicodedata.combining(c))

# Letters NFKD can't split; must match normalizePlaceText in Dart.
EXTRA = str.maketrans({'ł': 'l', 'ø': 'o', 'đ': 'd', 'ı': 'i'})

def key(s):
    return ' '.join(strip(s).lower().translate(EXTRA).split())

# South Asian names read best without diacritics ("Thane", not "Thāne").
PLAIN = {'IN', 'NP', 'LK', 'PK', 'BD', 'BT'}

# Well-known alternate names in India -> GeoNames name (folded).
ALIASES = {
    'Sagar': 'saugor', 'Gurgaon': 'gurugram', 'Allahabad': 'prayagraj',
    'Banaras': 'varanasi', 'Benares': 'varanasi', 'Kashi': 'varanasi',
    'Bangalore': 'bengaluru', 'Bombay': 'mumbai', 'Madras': 'chennai',
    'Calcutta': 'kolkata', 'Poona': 'pune', 'Trivandrum': 'thiruvananthapuram',
    'Cochin': 'kochi', 'Mysore': 'mysuru', 'Mangalore': 'mangaluru',
    'Belgaum': 'belagavi', 'Gulbarga': 'kalaburagi', 'Hubli': 'hubballi',
    'Pondicherry': 'puducherry', 'Simla': 'shimla', 'Gauhati': 'guwahati',
    'Faizabad': 'ayodhya', 'Hoshangabad': 'narmadapuram', 'Bijapur': 'vijayapura',
    'Bellary': 'ballari', 'Shimoga': 'shivamogga', 'Vizag': 'visakhapatnam',
    'Calicut': 'kozhikode', 'Trichur': 'thrissur', 'Quilon': 'kollam',
    'Alleppey': 'alappuzha', 'Trichy': 'tiruchirappalli', 'Tanjore': 'thanjavur',
    'Nasik': 'nashik', 'Ahmednagar': 'ahilyanagar', 'Osmanabad': 'dharashiv',
    'Bhubaneshwar': 'bhubaneswar', 'Jullundur': 'jalandhar', 'Ferozepur': 'firozpur',
    'Mathura': 'mathura', 'Rajahmundry': 'rajamahendravaram', 'Darjeeling': 'darjiling',
    'Tumkur': 'tumkur', 'Chikmagalur': 'chikmagalur', 'Solapur': 'sholapur',
    'Mughalsarai': 'pandit deen dayal upadhyaya nagar', 'Mohali': 'sas nagar',
    'Mhow': 'dr. ambedkar nagar',
}

rows = []
by_key = {}
for c in cities:
    name = c['name'].strip()
    if not name or '\t' in name:
        continue
    if c['country'] in PLAIN:
        name = strip(name)
    k = key(name)
    row = [name, '' if k == name.lower() else k,
           f"{float(c['lat']):.4f}", f"{float(c['lng']):.4f}", c['country'], c['admin1'] or '-']
    rows.append(row)
    if c['country'] == 'IN':
        by_key.setdefault(k, []).append(row)

added = 0
for alias, target in ALIASES.items():
    hits = by_key.get(target)
    if not hits:
        continue
    hit = hits[0]
    # Skip if a place already has this name in the same state.
    if any(r[5] == hit[5] for r in by_key.get(key(alias), [])):
        continue
    k = key(alias)
    rows.append([alias, '' if k == alias.lower() else k] + hit[2:])
    added += 1

os.makedirs(out, exist_ok=True)
with open(f'{out}/cities.tsv', 'w', encoding='utf-8') as f:
    f.write('\n'.join('\t'.join(r) for r in rows) + '\n')

regions = sorted({f"{a['code']}\t{a['name']}" for a in admin if a['name'] and '\t' not in a['name']})
with open(f'{out}/regions.tsv', 'w', encoding='utf-8') as f:
    f.write('\n'.join(regions) + '\n')

OVERRIDE = {'US': 'USA', 'GB': 'United Kingdom', 'RU': 'Russia', 'IR': 'Iran',
            'KR': 'South Korea', 'KP': 'North Korea', 'VN': 'Vietnam', 'SY': 'Syria',
            'LA': 'Laos', 'BO': 'Bolivia', 'VE': 'Venezuela', 'TZ': 'Tanzania',
            'MD': 'Moldova', 'TW': 'Taiwan', 'CZ': 'Czechia', 'XK': 'Kosovo',
            'AE': 'United Arab Emirates'}
lines = []
for cc in sorted({c['country'] for c in cities}):
    p = pycountry.countries.get(alpha_2=cc)
    name = OVERRIDE.get(cc) or (p and (getattr(p, 'common_name', None) or p.name))
    if name:
        lines.append(f'{cc}\t{name}')
with open(f'{out}/countries.tsv', 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines) + '\n')
print(len(rows), 'places,', added, 'aliases,', len(regions), 'regions,', len(lines), 'countries')
