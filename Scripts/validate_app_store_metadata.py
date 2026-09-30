#!/usr/bin/env python3
from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / 'AppStore' / 'app_store_metadata.json'
data = json.loads(path.read_text(encoding='utf-8'))
errors = []

release = data.get('release', {})
if release.get('marketing_version') != '1.0.0':
    errors.append('release marketing version must be 1.0.0')
if str(release.get('build_number')) != '182':
    errors.append('release build number must be 182')
if release.get('release_mode') != 'manual':
    errors.append('release mode must be manual')
if release.get('minimum_macos') != '13.0':
    errors.append('minimum macOS must be 13.0')
if release.get('minimum_ios') != '17.0':
    errors.append('minimum iOS must be 17.0')
if set(release.get('platforms', [])) != {'macOS', 'iPhone'}:
    errors.append('platforms must be macOS and iPhone')
if release.get('iap_family_sharing') is not False:
    errors.append('IAP Family Sharing must be disabled for 1.0.0')

name = data['app']['name']
if not (2 <= len(name) <= 30):
    errors.append(f'App name length {len(name)} outside 2...30')

for locale, item in data['localizations'].items():
    subtitle = item['subtitle']
    promo = item['promotional_text']
    description = item['description']
    keywords = item['keywords']
    keyword_bytes = len(keywords.encode('utf-8'))
    if len(subtitle) > 30:
        errors.append(f'{locale} subtitle has {len(subtitle)} characters')
    if len(promo) > 170:
        errors.append(f'{locale} promotional text has {len(promo)} characters')
    if len(description) > 4000:
        errors.append(f'{locale} description has {len(description)} characters')
    if keyword_bytes > 100:
        errors.append(f'{locale} keywords use {keyword_bytes} UTF-8 bytes')
    if '\n' in keywords:
        errors.append(f'{locale} keywords must be a one-line comma-separated value')

for key, url in data['urls'].items():
    if not url.startswith('https://'):
        errors.append(f'{key} must use HTTPS')
    if 'REPLACE-' in url:
        print(f'WARNING: placeholder URL remains: {key}')

print(f'Name: {len(name)} chars')
for locale, item in data['localizations'].items():
    print(
        f"{locale}: subtitle={len(item['subtitle'])}, "
        f"promo={len(item['promotional_text'])}, "
        f"description={len(item['description'])}, "
        f"keyword_bytes={len(item['keywords'].encode('utf-8'))}"
    )

if errors:
    for error in errors:
        print('ERROR:', error)
    sys.exit(1)
print('PASS: App Store metadata length and URL-scheme checks')
