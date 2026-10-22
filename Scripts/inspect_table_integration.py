"""Offline deployment, data-lineage and target-reference inspection. No app execution."""
from pathlib import Path
import json
import plistlib
import re

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / 'Docs/BackendAPI'
def load(path):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            assert key not in result, 'Duplicate JSON key: ' + key
            result[key] = value
        return result
    return json.loads(path.read_text(), object_pairs_hook=unique)
def main():
    contract = load(DOCS / 'contract.json')
    assert contract['baseURL'] == 'https://api.afterhou.top'
    assert contract['sourceAppId'] == '48859669'
    source = load(DOCS / 'source-inventory.json')
    interfaces = load(DOCS / 'generated/接口模板-48859669.json')
    configuration = load(DOCS / 'generated/配置模板-48859669.json')
    assert interfaces['sourceAppId'] == configuration['sourceAppId'] == contract['sourceAppId']
    actual = {entry['url']: json.loads(entry['responseContent']) for entry in interfaces['interfaces']}
    routes = {contract['endpoints'][key]: path for key, path in contract['endpointResponses'].items()}
    routes.update({entry['path']: entry['file'] for entry in contract['contentRoutes']})
    assert set(actual) == set(routes)
    for path, file in routes.items():
        assert actual[path] == load(DOCS / file), 'Import drift: ' + path
        assert path.startswith('/tati/') and not re.search(r'/v\d+/', path)
    assert len(configuration['parameters']) == 14
    assert sorted(p['type'] for p in configuration['parameters']) == [2] * 7 + [3] * 3 + [4] * 4
    catalog = load(DOCS / 'responses/table-catalog.json')['data']
    notebook = load(DOCS / 'responses/cooking-notebook.json')['data']
    offers = load(DOCS / 'responses/kitchen-offers.json')['data']
    editorial = catalog['editorial']
    films = editorial['clips'] + list(editorial['roomClips'].values())
    counts = dict(members=len(catalog['members']), rooms=len(catalog['rooms']), feedFilms=len(editorial['clips']), roomFilms=len(editorial['roomClips']), photographs=len(editorial['imageSources']), movies=len(editorial['movieSources']), gifts=len(catalog['celebrations']), recipes=len(notebook['recipes']), chapters=len(notebook['chapters']), coinPacks=len(offers['coinPacks']), cookingAnswers=len(offers['answers']))
    assert counts == source['counts']
    assert [p['id'] for p in catalog['members']] == source['memberIDs']
    assert [p['id'] for p in films] == source['filmIDs']
    assert len({p['id'] for p in films}) == len(films)
    assert len({p['id'] for p in catalog['members']}) == len(catalog['members'])
    manifest = load(ROOT / 'ProjectMaterials/content-slots.json')
    assert editorial['imageSources'] == {p['asset']: p['remoteURL'] for p in manifest['portraits']}
    assert editorial['movieSources'] == {p['resource']: p['remoteURL'] for p in manifest['videos']}
    assert not (ROOT / 'Tati/Resources/table-editorial-content.json').exists()
    pbx = (ROOT / 'Tati.xcodeproj/project.pbxproj').read_text()
    assert 'table-editorial-content.json' not in pbx and '接口模板' not in pbx and 'responses/' not in pbx
    swift = list((ROOT / 'Tati').rglob('*.swift'))
    text = '\n'.join(p.read_text() for p in swift)
    assert text.count('for await result in Transaction.updates') == 1
    assert text.count('for await result in Transaction.unfinished') == 1
    assert 'tokenResult' not in text and 'table_entry' not in text
    assert 'WelcomeCoinsView()' not in (ROOT / 'Tati/App/TatiApp.swift').read_text()
    assert 'static let apiMethod: String = "POST"' in text
    for path in swift: assert f'/* {path.name} in Sources */' in pbx
    for generated in ['IntegrationContract.generated.swift', 'ConfiguredThemeContract.generated.swift']:
        normalize = lambda s: '\n'.join(line for line in s.splitlines() if line.strip() and not line.lstrip().startswith('//'))
        assert normalize((DOCS / 'generated' / generated).read_text()) == normalize((ROOT / 'Tati/Integration' / generated).read_text())
    info = plistlib.loads((ROOT / 'Tati/Info.plist').read_bytes())
    assert all(info.get(k) for k in ['NSCameraUsageDescription', 'NSPhotoLibraryUsageDescription', 'NSMicrophoneUsageDescription'])
    assert any('com.tatifood.kitchennotes' in t.get('CFBundleURLSchemes', []) for t in info['CFBundleURLTypes'])
    assert 'TABLE_PUSH_ENVIRONMENT = production;' in pbx
    assert 'Alamofire in Frameworks' in pbx
    report = {'scope':'Offline source, DTO fields, import payloads and project references; not Swift type-checking or service validation', 'baseURL':contract['baseURL'], 'sourceAppId':contract['sourceAppId'], 'interfaces':len(routes), 'configurationEntries':14, 'sourceCounts':counts, 'swiftTargetMembers':len(swift), 'buildTestsAppOrBusinessRequestsPerformed':False}
    (DOCS / 'static-inspection.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(report,ensure_ascii=False,indent=2))
if __name__ == '__main__': main()
