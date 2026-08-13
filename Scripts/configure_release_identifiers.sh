#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 6 ]]; then
  echo "Usage: $0 <app-bundle-id> <development-team-id> <lifetime-product-id> <privacy-https-url> <support-https-url> <marketing-https-url>" >&2
  exit 64
fi
APP_ID="$1"; TEAM_ID="$2"; PRODUCT_ID="$3"; PRIVACY_URL="$4"; SUPPORT_URL="$5"; MARKETING_URL="$6"
[[ "$APP_ID" =~ ^[A-Za-z0-9.-]+$ ]] || { echo "Invalid bundle identifier." >&2; exit 64; }
[[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || { echo "Development Team ID must be 10 uppercase letters/digits." >&2; exit 64; }
[[ "$PRODUCT_ID" != *yourcompany* && "$PRODUCT_ID" != *REPLACE* ]] || { echo "Real lifetime product ID is required." >&2; exit 64; }
for url in "$PRIVACY_URL" "$SUPPORT_URL" "$MARKETING_URL"; do
  [[ "$url" == https://* ]] || { echo "All public URLs must use HTTPS." >&2; exit 64; }
done
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" "$APP_ID" "$TEAM_ID" "$PRODUCT_ID" "$PRIVACY_URL" "$SUPPORT_URL" "$MARKETING_URL" <<'PY2'
from pathlib import Path
import json, re, sys
root=Path(sys.argv[1]); app,team,product,privacy,support,marketing=sys.argv[2:]
project=root/'Cullora.xcodeproj/project.pbxproj'
s=project.read_text()
s=re.sub(r'PRODUCT_BUNDLE_IDENTIFIER = "com\.yourcompany\.cullora\.tests"', f'PRODUCT_BUNDLE_IDENTIFIER = "{app}.tests"', s)
s=re.sub(r'PRODUCT_BUNDLE_IDENTIFIER = "com\.yourcompany\.cullora"', f'PRODUCT_BUNDLE_IDENTIFIER = "{app}"', s)
s=s.replace('DEVELOPMENT_TEAM = "";', f'DEVELOPMENT_TEAM = "{team}";')
project.write_text(s)
store=root/'Cullora/Resources/Cullora.storekit'
data=json.loads(store.read_text()); data['products'][0]['productID']=product; data['products'][0]['familyShareable']=False
store.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n')
purchase=root/'Cullora/Core/Purchases/StoreEntitlementController.swift'
s=purchase.read_text().replace('com.yourcompany.cullora.pro.lifetime', product)
purchase.write_text(s)
info=root/'Cullora/Resources/Info.plist'
s=info.read_text()
s=s.replace('com.yourcompany.cullora.pro.lifetime', product)
s=s.replace('https://YOUR-DOMAIN/cullora/privacy', privacy)
s=s.replace('https://YOUR-DOMAIN/cullora/support', support)
s=s.replace('https://YOUR-DOMAIN/cullora', marketing)
info.write_text(s)
meta=root/'AppStore/app_store_metadata.json'
m=json.loads(meta.read_text()); target=m.get('urls',m)
target['privacy_policy']=privacy; target['support']=support; target['marketing']=marketing
m.setdefault('release', {})['marketing_version']='1.0.0'; m['release']['build_number']='181'; m['release']['iap_family_sharing']=False
meta.write_text(json.dumps(m, ensure_ascii=False, indent=2)+'\n')
print('Configured:', app, team, product, privacy, support, marketing)
PY2
python3 "$ROOT/Scripts/validate_phase5s_static.py" --release
