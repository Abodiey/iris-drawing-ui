#!/usr/bin/env python3
"""Run bundle interactions using Lupa or a supplied native Luau executable."""
from pathlib import Path
import argparse, subprocess, tempfile
root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--luau', help='Path to a native Luau CLI executable')
args = parser.parse_args()
mock = (root / 'tests/Mock.lua').read_text(encoding='utf-8-sig')
bundle = (root / 'dist/Iris.lua').read_text(encoding='utf-8')
interactions = (root / 'tests/Interactions.lua').read_text(encoding='utf-8-sig')
example = (root / 'examples/Example.lua').read_text(encoding='utf-8-sig')
example_setup = '''
function game:HttpGet(url)
    assert(url == 'https://raw.githubusercontent.com/Abodiey/iris-drawing-ui/main/dist/Iris.lua?v=1.0.1')
    return Bundle
end
'''
example_cleanup = '''
Mock.tick(50)
assert(_G.IrisDrawingExample, 'Example did not create an instance')
_G.IrisDrawingExample:Destroy()
assert(Mock.liveConnections()==0 and Mock.visibleDrawings()==0, 'Example leaked resources')
print('PASS full example executes, reruns and cleans up')
'''
if args.luau:
    sources = '\n'.join('assert(loadstring([====[' + file.read_text(encoding='utf-8-sig') + ']====]))' for file in (root / 'src').rglob('*.lua'))
    setup = '''
local nativeLoadstring=loadstring
function loadstring(source)
    local fn,err=nativeLoadstring(source)
    if fn then setfenv(fn,getfenv()) end
    return fn,err
end
NewUI=function(source) return assert(loadstring(source))() end
'''
    script = mock+'\n'+setup+'\nBundle=[====[\n'+bundle+'\n]====]\n'+sources+'\n'+interactions+'\n'+example_setup+'\n'+example+'\n'+example+'\n'+example_cleanup
    with tempfile.TemporaryDirectory(prefix='iris-tests-') as directory:
        target = Path(directory)/'test.luau'
        target.write_text(script,encoding='utf-8')
        subprocess.run([str(Path(args.luau).resolve()),str(target)],check=True)
else:
    from lupa import LuaRuntime
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.execute(mock)
    for file in (root/'src').rglob('*.lua'):
        lua.execute('assert(load(...))',file.read_text(encoding='utf-8-sig'),str(file))
    lua.globals().NewUI=lua.eval('function(source) return assert(load(source))() end')
    lua.globals().Bundle=bundle
    lua.globals().loadstring=lua.eval('load')
    lua.execute(interactions)
    lua.execute(example_setup)
    lua.execute(example)
    lua.execute(example)
    lua.execute(example_cleanup)
print('Source parsing, bundled interactions, and full example passed')
