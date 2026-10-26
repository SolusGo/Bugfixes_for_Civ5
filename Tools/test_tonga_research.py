"""Exercise the research-index boundary and the optional installer's byte scope."""
from pathlib import Path
import argparse
import hashlib
import tempfile
import unittest
from unittest.mock import patch
from lupa.lua51 import LuaRuntime
import hotfix_tonga_research as fix


class TongaResearchTests(unittest.TestCase):
    def test_native_boundary(self):
        # Minimal original call site, with the DLL's independently enforced
        # negative-index precondition. No mocked fallback inside the native API.
        original = b'function Award(playerID,reward)\n local player=Players[playerID]\n '+fix.OLD+b'\nend\n'
        lua = LuaRuntime()
        lua.execute('''
            current=-1; research=0; overflow=0; nativeCalls=0
            Players={[20]={GetCurrentResearch=function() return current end,
              GetTeam=function() return 20 end,
              ChangeOverflowResearch=function(self,n) overflow=overflow+n end}}
            Teams={[20]={GetTeamTechs=function() return {
              ChangeResearchProgress=function(self,tech,amount,pid)
                assert(tech>=0,'eIndex is expected to be non-negative (invalid Index)')
                assert(pid==20);nativeCalls=nativeCalls+1;research=research+amount
              end} end}}
        ''')
        lua.execute(original.decode())
        self.assertFalse(lua.eval('function() return pcall(Award,20,30) end')()[0])
        lua.execute(fix.patch_source(original).decode())
        lua.execute('''
            Award(20,30);assert(overflow==30 and research==0 and nativeCalls==0)
            current=53;Award(20,30);assert(research==30 and overflow==30 and nativeCalls==1)
            current=-1;Award(20,15);Award(20,60)
            assert(overflow==105 and research==30 and nativeCalls==1)
            current=nil;Award(20,30);assert(overflow==135 and nativeCalls==1)
        ''')

    def test_byte_scope_and_unknown_rejection(self):
        for ending in (b'\n', b'\r\n'):
            original = b'-- untouched'+ending+b'    '+fix.OLD+ending+b'-- tail'+ending
            repaired = fix.patch_source(original)
            self.assertTrue(repaired.startswith(b'-- untouched'+ending))
            self.assertTrue(repaired.endswith(b'-- tail'+ending))
            self.assertNotIn(fix.OLD, repaired)
            with patch.object(fix,'ORIGINAL_SHA256',fix.sha256(original)):
                self.assertEqual(fix.original_source(repaired),(original,True))
                self.assertEqual(fix.original_source(original),(original,False))
                with self.assertRaises(ValueError):fix.original_source(original+b'-- unexpected')
        with self.assertRaises(ValueError):fix.patch_source(fix.OLD+b'\n'+fix.OLD)

    def test_install_scope_idempotence_and_rollback(self):
        original=b'-- fixture\r\n '+fix.OLD+b'\r\n'
        with tempfile.TemporaryDirectory(prefix='tonga-test-') as temp:
            root=Path(temp);mod=root/'mod';(mod/'Lua').mkdir(parents=True)
            source=mod/fix.RELATIVE;source.write_bytes(original)
            manifest=mod/'fixture.modinfo'
            text=('<Mod id="'+fix.MOD_ID+'" version="5"><Files><File md5="'+hashlib.md5(original).hexdigest().upper()+'" import="0">'+fix.RELATIVE+'</File></Files></Mod>')
            manifest.write_bytes(text.encode())
            untouched=mod/'untouched.txt';untouched.write_bytes(b'preserved')
            with patch.object(fix,'ORIGINAL_SHA256',fix.sha256(original)), patch.object(fix,'require_game_closed'):
                receipt=fix.install(mod,root/'backup')
                self.assertEqual(receipt['status'],'installed')
                self.assertEqual((root/'backup/MC_Tonga_Functions.lua.before').read_bytes(),original)
                self.assertEqual((root/'backup/manifest.modinfo.before').read_bytes(),text.encode())
                self.assertEqual(untouched.read_bytes(),b'preserved')
                expected_manifest=text.replace(hashlib.md5(original).hexdigest().upper(),hashlib.md5(fix.patch_source(original)).hexdigest().upper())
                self.assertEqual(manifest.read_bytes(),expected_manifest.encode())
                self.assertTrue(fix.prepare(mod)[-1])
                self.assertEqual(fix.install(mod,root/'second')['status'],'already installed')
                self.assertFalse((root/'second').exists())
                source.write_bytes(original);manifest.write_bytes(text.encode())
                normal_prepare=fix.prepare;calls=0
                def fail_verification(path):
                    nonlocal calls
                    calls+=1
                    if calls==2:raise RuntimeError('injected post-install failure')
                    return normal_prepare(path)
                with patch.object(fix,'prepare',side_effect=fail_verification):
                    with self.assertRaises(RuntimeError):fix.install(mod,root/'rollback')
                self.assertEqual(source.read_bytes(),original)
                self.assertEqual(manifest.read_bytes(),text.encode())
                manifest.write_bytes(text.replace('version="5"','version="6"').encode())
                with self.assertRaises(ValueError):fix.prepare(mod)
                manifest.write_bytes(text.replace(fix.MOD_ID,'unrelated-mod').encode())
                with self.assertRaises(ValueError):fix.prepare(mod)

    def test_running_game_refused_before_write(self):
        with patch.object(fix,'require_game_closed',side_effect=RuntimeError('game running')):
            with patch.object(fix,'prepare') as prepare:
                with self.assertRaises(RuntimeError):fix.install(Path('unused'),Path('unused-backup'))
                prepare.assert_not_called()


def installed_original(source):
    """Also run the complete external Lua file when its original is available."""
    lua=LuaRuntime()
    lua.execute('''
        GameInfoTypes={CIVILIZATION_MC_TONGA=20};DirectionTypes={}
        Game={Rand=function()return 2 end};Locale={ConvertTextKey=function()return '' end}
        Events={LoadScreenClose={Add=function()end},GameplayAlertMessage=function()end}
        GameEvents={TeamMeet={Add=function(f)Meet=f end},PlayerDoTurn={Add=function()end}}
        current=-1;overflow=0;research=0
        Players={[20]={GetCivilizationType=function()return 20 end,GetTeam=function()return 20 end,
          GetCurrentResearch=function()return current end,IsHuman=function()return false end,
          ChangeOverflowResearch=function(self,n)overflow=overflow+n end},
          [21]={GetTeam=function()return 21 end,IsMinorCiv=function()return false end}}
        Teams={[21]={GetHasMetCivCount=function()return 2 end},
          [20]={GetTeamTechs=function()return{ChangeResearchProgress=function(self,id,n,pid)
          assert(id>=0,'native negative technology index');assert(pid==20);research=research+n end}end}}
    ''')
    original,_=fix.original_source(source.read_bytes())
    lua.execute(original.decode('utf-8-sig'))
    assert not lua.eval('function()return pcall(Meet,21,20)end')()[0]
    lua.execute(fix.patch_source(original).decode('utf-8-sig'))
    lua.execute('Meet(21,20);assert(overflow==30 and research==0);current=53;Meet(21,20);assert(overflow==30 and research==30)')
    print('PASS complete installed Tonga v5: original reproduces negative-index call; repaired no-research/valid-research paths preserve 30 science')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path)
    args=parser.parse_args()
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(TongaResearchTests))
    if not result.wasSuccessful():raise SystemExit(1)
    if args.source:installed_original(args.source)
