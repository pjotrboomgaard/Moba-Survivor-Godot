import json, os, shutil, subprocess, sys, time, glob

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GODOT = r"C:\Users\pjotr\Tools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
USERDATA = os.path.join(os.environ["APPDATA"], "Godot", "app_userdata", "Rift Survivors")
REQ_OUT = os.path.join(USERDATA, "selftest_request.json")
RP_OUT = os.path.join(USERDATA, "selftest_report.json")
OUT = os.path.join(ROOT, "tools", "selftest", "results")
os.makedirs(OUT, exist_ok=True)

def run_hero(hero):
    req = os.path.join(ROOT, "tools", "selftest", "requests", f"twostage_{hero}.json")
    if os.path.exists(RP_OUT):
        os.remove(RP_OUT)
    shutil.copyfile(req, REQ_OUT)
    before = time.time()
    proc = subprocess.Popen([GODOT, "--path", ROOT, "res://scenes/main/main.tscn"],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        proc.wait(timeout=90)
    except subprocess.TimeoutExpired:
        proc.kill()
        return hero, None, "timeout"
    # flush-wait for the report to land
    rp = None
    for _ in range(40):
        if os.path.exists(RP_OUT):
            try:
                with open(RP_OUT) as f:
                    rp = json.load(f)
                if rp:
                    break
            except Exception:
                pass
        time.sleep(0.2)
    if not rp:
        return hero, None, "no_report"
    frozen = os.path.join(OUT, f"{hero}.json")
    with open(frozen, "w") as f:
        json.dump(rp, f)
    return hero, rp, "ok"

if __name__ == "__main__":
    heroes = sys.argv[1:]
    for h in heroes:
        name, rp, status = run_hero(h)
        print(f"{h}: {status}", flush=True)
