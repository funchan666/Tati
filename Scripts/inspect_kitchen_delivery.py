"""Read-only source/configuration/resource inspection. Does not compile or run Tati."""
from pathlib import Path
import ast
import hashlib
import json
import re
import subprocess
import plistlib
import yaml
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'Tati'
RESOURCES = APP / 'Resources'

def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('Duplicate JSON key: ' + key)
        result[key] = value
    return result

def read_json(path):
    return json.loads(path.read_text(), object_pairs_hook=unique_object)

def require(condition, detail):
    if not condition:
        raise ValueError(detail)

def main():
    for script in (ROOT / 'Scripts').glob('*.py'):
        ast.parse(script.read_text())
    library = read_json(RESOURCES / 'table-editorial-content.json')
    manifest = read_json(ROOT / 'ProjectMaterials/content-slots.json')
    project = yaml.safe_load((ROOT / 'project.yml').read_text())
    info = plistlib.loads((APP / 'Info.plist').read_bytes())
    assets = {p.stem for p in RESOURCES.rglob('*.imageset')}
    for entry in RESOURCES.rglob('Contents.json'):
        value = read_json(entry)
        for image in value.get('images', []):
            if 'filename' in image:
                require((entry.parent / image['filename']).is_file(), 'Missing image: ' + str(entry))
    all_media = manifest['portraits'] + manifest['videos']
    for item in all_media:
        require(hashlib.sha256((ROOT / item['source']).read_bytes()).hexdigest() == item['sha256'], 'Original changed: ' + item['source'])
    films = library['clips'] + list(library['roomClips'].values())
    expected = {v['id'] for v in manifest['videos'] if not v.get('excludedFromApp')}
    require(expected == {v['id'] for v in films}, 'Active film assignment mismatch')
    holds = {v['id'] for v in manifest['videos'] if v.get('excludedFromApp')}
    require(not holds.intersection(expected), 'Review hold re-entered active content')
    for film in films:
        require((RESOURCES / 'FoodFilms' / film['bundledFile']).is_file(), 'Missing film: ' + film['id'])
        require(film['posterArtwork'] in assets, 'Missing poster: ' + film['id'])
    require(len(list((RESOURCES / 'FoodFilms').glob('*.mp4'))) == len(films), 'Unexpected packaged film')
    for name in list(library['portraits'].values()) + list(library['roomCovers'].values()):
        require(name in assets, 'Missing editorial image: ' + name)
    require(library['roomCovers'] == manifest['roomCovers'], 'Room cover import drift')
    require(library['portraits'] == {p['personID']: p['asset'] for p in manifest['portraits']}, 'Portrait import drift')
    require(library['additionalPeople'] == [p['person'] for p in manifest['portraits'] if 'person' in p], 'Profile import drift')
    require(library['curatedRoomActivity'] == manifest['curatedRoomActivity'], 'Room copy import drift')
    for entry in manifest['videos']:
        if entry['id'] not in expected:
            continue
        actual = next(v for v in films if v['id'] == entry['id'])
        require(actual['caption'] == entry['caption'], 'Caption import drift')
        if not entry.get('roomID'):
            require(library['curatedEngagement'][entry['id']] == entry['curatedEngagement'], 'Comment import drift')
    languages = ['en', 'zh-Hans', 'es', 'fr', 'de', 'ja']
    counts = {}
    for filename in ['Localizable.xcstrings', 'InfoPlist.xcstrings']:
        catalog = read_json(RESOURCES / filename)
        counts[filename] = len(catalog['strings'])
        for key, entry in catalog['strings'].items():
            for language in languages:
                value = entry.get('localizations', {}).get(language, {}).get('stringUnit', {}).get('value')
                require(isinstance(value, str) and bool(value), 'Missing translation: ' + key + ' / ' + language)
        if filename == 'InfoPlist.xcstrings':
            for key, entry in catalog['strings'].items():
                require(entry['localizations']['en']['stringUnit']['value'] == info[key], 'Purpose copy drift: ' + key)
    require('NSPhotoLibraryUsageDescription' not in info, 'Unnecessary broad photo access declaration')
    expected_faces = {'DMSans-Regular.ttf': 'DMSans-9pt', 'DMSans-SemiBold.ttf': 'DMSans-9ptSemiBold', 'Fraunces-SemiBold.ttf': 'Fraunces-9ptSemiBold'}
    require(set(info['UIAppFonts']) == set(expected_faces), 'Font registration drift')
    for filename, face in expected_faces.items():
        font = TTFont(RESOURCES / 'Typography' / filename)
        names = {item.toUnicode() for item in font['name'].names if item.nameID == 6}
        require(face in names, 'Wrong font face: ' + filename)
        require('fvar' not in font, 'Unexpected uninstantiated font')
    for key, value in project['targets']['Tati']['info']['properties'].items():
        if key.endswith('UsageDescription') or key == 'UIAppFonts':
            require(info[key] == value, 'Project plist drift: ' + key)
    pbx = (ROOT / 'Tati.xcodeproj/project.pbxproj').read_text()
    for resource in set(re.findall(r'/\* ([^*]+) in Resources \*/', pbx)):
        require(any(p.name == resource for p in RESOURCES.rglob('*')), 'Resource missing from target path: ' + resource)
    swift_files = list(APP.rglob('*.swift'))
    for path in swift_files:
        require(('/* ' + path.name + ' in Sources */') in pbx, 'Source missing from target: ' + path.name)
    for filename in expected_faces:
        require(('/* ' + filename + ' in Resources */') in pbx, 'Font missing from target: ' + filename)
    source = '\n'.join(p.read_text() for p in swift_files)
    require('Image(systemName:' not in source and 'systemImage:' not in source, 'Unexpected system artwork')
    require('UIScreen.main' not in source, 'Global screen geometry introduced')
    # Verify the purchase contract was not changed by the semantic source rename.
    old_purchase = subprocess.check_output(['git', 'show', 'HEAD:Tati/Services/TatiPurchases.swift'], cwd=ROOT, text=True)
    new_purchase = (APP / 'Services/KitchenCoinPurchases.swift').read_text()
    offers = lambda text: re.findall(r'\.init\(id: "([^"]+)", coins: (\d+), usdPrice: "([^"]+)"\)', text)
    require(offers(old_purchase) == offers(new_purchase), 'StoreKit offer contract changed')
    community = (APP / 'Domain/TableCommunity.swift').read_text()
    for model, body in re.findall(r'struct (\w+):[^\n]+\{(.*?)\n\}', community, re.S):
        if 'private enum CodingKeys' not in body:
            continue
        fields = set(re.findall(r'^    (?:var|let) (\w+)(?:\s*[:=])', body, re.M)) - {'isHouseCollection'}
        keys = set(re.findall(r'^        case (\w+)', body, re.M))
        require(fields == keys, 'Stored field/CodingKeys mismatch: ' + model)
    for legacy in ['isEditorial = "isSample"', 'rewardCoins = "demoCoins"', 'dishCaption = "caption"', 'recordedMovieFile = "fileName"']:
        require(legacy in community, 'Missing migration key: ' + legacy)
    result = {
        'scope': 'Static source, project, resource and import-contract inspection only',
        'swiftSourceFiles': len(swift_files), 'editorialProfiles': len(library['portraits']),
        'activeFeedFilms': len(library['clips']), 'activeRoomFilms': len(library['roomClips']),
        'reviewHoldIDs': sorted(holds), 'originalInputHashesChecked': len(all_media),
        'fontFamilies': 2, 'fontCuts': len(expected_faces), 'fontBytes': sum((RESOURCES / 'Typography' / f).stat().st_size for f in expected_faces),
        'catalogEntries': counts, 'supportEmail': 'hudden.serudiv22@gmail.com',
        'recipeCount': len(re.findall(r'\.init\(id:', (APP / 'Domain/KitchenNotebook.swift').read_text())),
        'recipeChapters': len(re.findall(r'RecipeChapter\(id:', (APP / 'Domain/KitchenNotebook.swift').read_text())),
        'chapterCoins': sorted(set(int(c) for c in re.findall(r'coinCost: (\d+)', (APP / 'Domain/KitchenNotebook.swift').read_text()))),
        'currentAppResourceBytes': sum(p.stat().st_size for p in RESOURCES.rglob('*') if p.is_file()),
        'storeKitOffersUnchanged': True, 'legacyStoredKeysRetained': True,
        'buildTestsOrAppRunPerformed': False
    }
    (ROOT / 'Documentation/Kitchen-delivery-inspection.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(result, ensure_ascii=False, indent=2))

if __name__ == '__main__':
    main()
