"""Restore the original Monte Carlo inputs and verify their SHA-256 checksums."""
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import json
from pathlib import Path
import time
from urllib.parse import quote
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent
MANIFEST = json.loads((ROOT / 'file_manifest.json').read_text(encoding='utf-8'))


def checksum(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def download(record):
    destination = ROOT / record['path']
    if destination.is_file() and destination.stat().st_size == record['bytes'] and checksum(destination) == record['sha256']:
        return record['asset_name'] + ' (already verified)'
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_name(destination.name + '.partial')
    url = ('https://github.com/' + MANIFEST['repository'] + '/releases/download/'
           + quote(MANIFEST['release_tag'], safe='') + '/' + quote(record['asset_name'], safe=''))
    for attempt in range(1, 5):
        try:
            request = Request(url, headers={'User-Agent': 'EV-ICIO-data-downloader'})
            digest = hashlib.sha256()
            size = 0
            with urlopen(request, timeout=120) as response, temporary.open('wb') as output:
                while block := response.read(1024 * 1024):
                    digest.update(block)
                    size += len(block)
                    output.write(block)
            if size != record['bytes'] or digest.hexdigest() != record['sha256']:
                raise RuntimeError('Downloaded file does not match the checksum manifest')
            temporary.replace(destination)
            return record['asset_name']
        except Exception:
            if attempt == 4:
                raise
            time.sleep(min(2 ** attempt, 15))


if __name__ == '__main__':
    records = [record for record in MANIFEST['files'] if record['storage'] == 'release']
    print(f'Downloading/verifying {len(records)} Monte Carlo input files.', flush=True)
    with ThreadPoolExecutor(max_workers=3) as executor:
        futures = [executor.submit(download, record) for record in records]
        for count, future in enumerate(as_completed(futures), 1):
            print(f'{count}/{len(records)}: {future.result()}', flush=True)
    print('All Monte Carlo input files are present and verified.', flush=True)
