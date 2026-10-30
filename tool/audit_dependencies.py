"""Query OSV for the Pub lockfile and a resolved Gradle production classpath.

Usage: python3 tool/audit_dependencies.py /path/to/runtime-dependencies.txt
Generate that report with :app:dependencies --configuration releaseRuntimeClasspath.
Registry matches are evidence about published advisories, not exploitability.
"""
import json
import pathlib
import re
import sys
import urllib.request

root = pathlib.Path(__file__).resolve().parents[1]
lock = (root / 'pubspec.lock').read_text()
pub = re.findall(
    r'^  ([a-zA-Z0-9_]+):\n(?:(?!^  [a-zA-Z0-9_]+:).)*?^    source: hosted\n    version: "([^"]+)"',
    lock, re.M | re.S,
)
maven = set()
for line in pathlib.Path(sys.argv[1]).read_text().splitlines():
    match = re.search(r'(?:\+|\\)--- ([\w.-]+):([\w.-]+):([^\s]+)(?: -> ([^\s]+))?', line)
    if match:
        group, name, declared, selected = match.groups()
        version = selected or declared
        if ':' in version:
            group, name, version = version.split(':')[-3:]
        maven.add((group + ':' + name, version))
queries = [
    {'package': {'name': name, 'ecosystem': ecosystem}, 'version': version}
    for ecosystem, packages in [('Pub', pub), ('Maven', sorted(maven))]
    for name, version in packages
]
request = urllib.request.Request(
    'https://api.osv.dev/v1/querybatch', json.dumps({'queries': queries}).encode(),
    {'Content-Type': 'application/json'},
)
with urllib.request.urlopen(request, timeout=40) as response:
    results = json.load(response)['results']
assert len(results) == len(queries)
findings = [{'query': query, 'result': result} for query, result in zip(queries, results) if result.get('vulns')]
print(json.dumps({'pub': len(pub), 'maven_runtime': len(maven), 'queries': len(queries), 'findings': findings}, indent=2))
sys.exit(1 if findings else 0)
