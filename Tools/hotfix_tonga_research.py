"""Inspect/apply the optional MC Tonga v5 no-selected-research compatibility fix.

Part of SolusGo's Compatibility Fixes; repairs the separate Polynesian pack.
The default operation is read-only. --apply requires Civ V to be closed.
"""
from pathlib import Path
from xml.etree import ElementTree as ET
import argparse
import hashlib
import json
import re
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[1]
MOD_ID = '7287f9db-78cb-40c3-bf8a-cf8ebc18a565'
RELATIVE = 'Lua/MC_Tonga_Functions.lua'
ORIGINAL_SHA256 = '16cc0405489a3ae49ac0109ee629d89e0b210b5a1651892ef70131ae9fdeee1f'
OLD = b'Teams[player:GetTeam()]:GetTeamTechs():ChangeResearchProgress(player:GetCurrentResearch(), reward, playerID)'
NEW = (
    b'local researchID = player:GetCurrentResearch()',
    b'if researchID and researchID >= 0 then',
    b'    Teams[player:GetTeam()]:GetTeamTechs():ChangeResearchProgress(researchID, reward, playerID)',
    b'else',
    b'    player:ChangeOverflowResearch(reward)',
    b'end',
)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def patch_source(data):
    """Replace exactly one original call; keep all surrounding bytes/newlines."""
    if data.count(OLD) != 1:
        raise ValueError('Expected exactly one original Tonga science call')
    ending = b'\r\n' if b'\r\n' in data else b'\n'
    lines = data.splitlines(keepends=True)
    for index, line in enumerate(lines):
        if OLD in line:
            indent = line[:len(line)-len(line.lstrip(b' \t'))]
            if line.strip() != OLD:
                raise ValueError('Unexpected text on Tonga science-call line')
            terminator = ending if line.endswith(b'\n') else b''
            lines[index] = ending.join(indent+part for part in NEW)+terminator
            return b''.join(lines)
    raise ValueError('Original call not found')


def original_source(data):
    """Recognize only the reviewed source or the exact installed repair."""
    if sha256(data) == ORIGINAL_SHA256:
        return data, False
    ending = b'\r\n' if b'\r\n' in data else b'\n'
    for line in data.splitlines():
        if line.strip() == NEW[0]:
            indent = line[:len(line)-len(line.lstrip(b' \t'))]
            block = ending.join(indent+part for part in NEW)
            if data.count(block) == 1:
                original = data.replace(block, indent+OLD, 1)
                if sha256(original) == ORIGINAL_SHA256:
                    return original, True
    raise ValueError('Tonga source differs from reviewed v5; no file was changed')


def prepare(mod_dir):
    matches = []
    for path in mod_dir.glob('*.modinfo'):
        root = ET.parse(path).getroot()
        if root.get('id', '').lower() == MOD_ID:
            matches.append((path, root))
    if len(matches) != 1 or matches[0][1].get('version') != '5':
        raise ValueError('Expected exactly one MC Polynesian pack v5 manifest')
    manifest, root = matches[0]
    source = mod_dir/RELATIVE
    if source.resolve().parent != (mod_dir/'Lua').resolve():
        raise ValueError('Unexpected source location')
    before = source.read_bytes()
    original, already = original_source(before)
    after = patch_source(original)
    entries = [e for e in root.findall('Files/File') if e.text == RELATIVE]
    if len(entries) != 1 or entries[0].get('md5', '').upper() != hashlib.md5(before).hexdigest().upper():
        raise ValueError('Installed Tonga manifest/source checksum mismatch')
    manifest_before = manifest.read_bytes()
    pattern = rb'(<File\b[^>]*\bmd5=")[0-9A-Fa-f]{32}("[^>]*>Lua/MC_Tonga_Functions\.lua</File>)'
    digest = hashlib.md5(after).hexdigest().upper().encode('ascii')
    manifest_after, count = re.subn(pattern, lambda m:m[1]+digest+m[2], manifest_before)
    if count != 1:
        raise ValueError('Expected one Tonga manifest checksum attribute')
    return source, before, after, manifest, manifest_before, manifest_after, already


def require_game_closed():
    command = "@(Get-Process -ErrorAction Stop | Where-Object ProcessName -Like 'CivilizationV*' | Select-Object Id,ProcessName) | ConvertTo-Json -Compress"
    result = subprocess.run(['powershell.exe', '-NoProfile', '-NonInteractive', '-Command', command],
                            capture_output=True, text=True, check=True,
                            creationflags=subprocess.CREATE_NO_WINDOW)
    if result.stderr.strip():
        raise RuntimeError('Could not verify game state: '+result.stderr.strip())
    running = json.loads(result.stdout.strip() or '[]')
    if running:
        raise RuntimeError('Fully exit Civilization V before applying the Tonga hotfix')


def install(mod_dir, backup_dir):
    require_game_closed()
    source, before, after, manifest, manifest_before, manifest_after, already = prepare(mod_dir)
    if already:
        return {'status':'already installed', 'source':str(source), 'sha256':sha256(after)}
    if mod_dir == backup_dir or mod_dir in backup_dir.parents:
        raise ValueError('Keep backups outside the installed mod directory')
    backup_dir.mkdir(parents=True, exist_ok=False)
    (backup_dir/'MC_Tonga_Functions.lua.before').write_bytes(before)
    (backup_dir/'manifest.modinfo.before').write_bytes(manifest_before)
    require_game_closed()
    if source.read_bytes() != before or manifest.read_bytes() != manifest_before:
        raise RuntimeError('Installed files changed during preflight; no patch applied')
    try:
        source.write_bytes(after)
        manifest.write_bytes(manifest_after)
        assert source.read_bytes() == after and manifest.read_bytes() == manifest_after
        assert prepare(mod_dir)[-1], 'Post-install verification failed'
    except BaseException:
        source.write_bytes(before)
        manifest.write_bytes(manifest_before)
        raise
    receipt = {'status':'installed', 'source':str(source), 'manifest':str(manifest),
               'before_sha256':sha256(before), 'after_sha256':sha256(after),
               'backup':str(backup_dir), 'changed_files':[RELATIVE,manifest.name]}
    (backup_dir/'receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mod-dir', type=Path, default=Path.home()/"Documents/My Games/Sid Meier's Civilization 5/MODS/MC's Polynesian Civilisation Pack (v 5)")
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--backup-dir', type=Path)
    args = parser.parse_args()
    mod_dir = args.mod_dir.resolve(strict=True)
    if args.apply:
        backup = (args.backup_dir or ROOT/'dist/tonga-research-backups'/str(uuid.uuid4())).resolve()
        report = install(mod_dir, backup)
    else:
        source, before, after, manifest, _, _, already = prepare(mod_dir)
        report = {'status':'already installed' if already else 'ready; pass --apply to install',
                  'source':str(source), 'manifest':str(manifest),
                  'before_sha256':sha256(before), 'after_sha256':sha256(after)}
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
