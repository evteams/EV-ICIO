"""Download and restore the original MC files, verifying every SHA-256 checksum."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import tarfile
import time
from urllib.parse import quote
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent
MANIFEST = json.loads((ROOT / 'file_manifest.json').read_text(encoding='utf-8'))


def checksum(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def download_archive():
    record = MANIFEST['archives'][0]
    destination = ROOT / record['asset_name']
    if destination.is_file() and destination.stat().st_size == record['bytes'] and checksum(destination) == record['sha256']:
        return destination
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
                    if size % (64 * 1024 * 1024) == 0:
                        print(f'Downloaded {size / 1024**2:.0f}/{record["bytes"] / 1024**2:.0f} MiB.', flush=True)
            if size != record['bytes'] or digest.hexdigest() != record['sha256']:
                raise RuntimeError('Archive does not match the checksum manifest')
            temporary.replace(destination)
            return destination
        except Exception:
            if attempt == 4:
                raise
            time.sleep(min(2 ** attempt, 15))


def restore_archive(archive_path, verify_only=False):
    expected = {r['path']: r for r in MANIFEST['files'] if r['storage'] == 'release_archive'}
    seen = set()
    with tarfile.open(archive_path, mode='r|xz') as archive:
        for member in archive:
            name = PurePosixPath(member.name)
            if (not member.isfile() or member.name not in expected or member.name in seen
                    or name.is_absolute() or '..' in name.parts):
                raise RuntimeError('Unexpected archive member: ' + member.name)
            record = expected[member.name]
            if member.size != record['bytes']:
                raise RuntimeError('Incorrect file size: ' + member.name)
            destination = ROOT.joinpath(*name.parts)
            if not destination.resolve().is_relative_to(ROOT.resolve()):
                raise RuntimeError('Archive path leaves the repository')
            already_verified = (not verify_only and destination.is_file()
                and destination.stat().st_size == record['bytes'] and checksum(destination) == record['sha256'])
            temporary = destination.with_name(destination.name + '.partial')
            output = None
            try:
                if not verify_only and not already_verified:
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    output = temporary.open('wb')
                digest = hashlib.sha256()
                with archive.extractfile(member) as stream:
                    while block := stream.read(1024 * 1024):
                        digest.update(block)
                        if output is not None:
                            output.write(block)
                if output is not None:
                    output.close()
                    output = None
                if digest.hexdigest() != record['sha256']:
                    raise RuntimeError('File checksum mismatch: ' + member.name)
                if not verify_only and not already_verified:
                    temporary.replace(destination)
            finally:
                if output is not None:
                    output.close()
            seen.add(member.name)
            if len(seen) % 100 == 0:
                print(f'Verified {len(seen)}/{len(expected)} files.', flush=True)
    if seen != set(expected):
        raise RuntimeError('The archive is missing input files')
    return len(seen)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, help='Use an already downloaded archive')
    parser.add_argument('--verify-only', action='store_true', help='Verify all archive files without extracting them')
    args = parser.parse_args()
    archive_path = args.archive if args.archive is not None else download_archive()
    record = MANIFEST['archives'][0]
    if archive_path.stat().st_size != record['bytes'] or checksum(archive_path) != record['sha256']:
        raise RuntimeError('Archive does not match the checksum manifest')
    count = restore_archive(archive_path, verify_only=args.verify_only)
    print(f'All {count} Monte Carlo files verified' + ('.' if args.verify_only else ' and restored.'), flush=True)

