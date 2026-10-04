# Records one cinematic shot: starts ffmpeg screen capture of the Studio viewport,
# then drives the client camera along a path (plot-local coordinates).
import subprocess, sys, time, json, os
args = json.loads(sys.argv[1])
name, dur = args['name'], args['dur']
tpl = open('scratch/cam_template.luau', encoding='utf-8').read()
v = lambda a: 'Vector3.new(%s, %s, %s)' % tuple(a)
code = (tpl.replace('__UI__', 'true' if args.get('ui') else 'false')
           .replace('__HIDECHAR__', '1' if not args.get('char') else '0')
           .replace('__PLOT__', str(args.get('plot', 1)))
           .replace('__FROM__', v(args['from'])).replace('__TO__', v(args['to']))
           .replace('__LOOK0__', v(args['look0'])).replace('__LOOK1__', v(args.get('look1', args['look0'])))
           .replace('__DUR__', str(dur)))
open('scratch/cam_run.luau', 'w', encoding='utf-8').write(code)
out = 'scratch/video/%s.mp4' % name
rec = subprocess.Popen(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-f', 'gdigrab', '-draw_mouse', '0', '-framerate', '30',
    '-offset_x', '4', '-offset_y', '212', '-video_size', '1688x718', '-i', 'desktop', '-t', str(dur + 3.5),
    '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '16', '-pix_fmt', 'yuv420p', out])
time.sleep(0.6)
t0 = time.time()
subprocess.run(['node', 'tools/run.mjs', 'scratch/cam_run.luau', 'Client'], capture_output=True)
lag = time.time() - t0
# optional timed server events during the shot: [[seconds, "/command"], ...]
for at, cmd in args.get('events', []):
    wait = at - (time.time() - t0)
    if wait > 0:
        time.sleep(wait)
    subprocess.run(['node', 'tools/run.mjs', '-e', 'local p = game.Players:GetPlayers()[1]; game.ServerStorage.DevHook:Invoke("AdminService","run",p,%s); return "ok"' % json.dumps(cmd), 'Server'], capture_output=True)
rec.wait()
print(name, 'recorded; camera script lag %.2fs' % lag)
