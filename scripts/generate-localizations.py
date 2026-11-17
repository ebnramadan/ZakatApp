"""Generate the app's Arabic catalog from the shared UI/email translations."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
catalog = json.loads((root / 'assets/translations/ar.json').read_text())
encoded = json.dumps(catalog, ensure_ascii=False, indent=2).replace('$', r'\$')
(root / 'lib/core/localization/arabic.dart').write_text(
    '// Generated from assets/translations/ar.json.\n'
    'const Map<String,String> arabic = ' + encoded + ';\n'
)
