import json, os, shutil, subprocess, sys, time, re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GODOT = r"C:\Users\pjotr\Tools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
BASE_UD = os.path.join(os.environ["APPDATA"], "Godot", "app_userdata")
OUD = os.path.join(ROOT, "tools", "selftest", "results")
os.makedirs(OUD, exist_ok=True)
PROJECT = os.path.join(ROOT, "project.godot")


def _set_project_name(name):
    with open(PROJECT, encoding="utf-8") as f:
        src = f.read()
    with open(PROJECT, "w", encoding="utf-8") as f:
        f.write(re.sub(r'config/name="[^"]*"', f'config/name="{name}"', src, count=1))


def _user_dir(name):
    d = os.path.join(BASE_UD, name)
    os.makedirs(d, exist_ok=True)
    return d


def run_hero(hero):
    name = f"ST_{hero}"
    ud = _user_dir(name)
    req_out = os.path.join(ud, "selftest_request.json")
    rp_out = os.path.join(ud, "selftest_report.json")
    if os.path.exists(rp_out):
        os.remove(rp_out)
    shutil.copyfile(os.path.join(ROOT, "tools", "selftest", "requests", f"twostage_{hero}.json"), req_out)
    with open(PROJECT, encoding="utf-8") as f:
        original = f.read()
    _set_project_name(name)
    try:
        proc = subprocess.Popen([GODOT, "--path", ROOT, "res://scenes/main/main.tscn"],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            proc.wait(timeout=90)
        except subprocess.TimeoutExpired:
            proc.kill()
            return hero, "timeout"
    finally:
        with open(PROJECT, "w", encoding="utf-8") as f:
            f.write(original)
    rp = None
    for _ in range(50):
        if os.path.exists(rp_out):
            try:
                with open(rp_out) as f:
                    rp = json.load(f)
                if rp:
                    break
            except Exception:
                pass
        time.sleep(0.2)
    if not rp:
        return hero, "no_report"
    with open(os.path.join(OUD, f"{hero}.json"), "w") as f:
        json.dump(rp, f)
    # snapshots land under the per-name user dir
    return hero, "ok"


if __name__ == "__main__":
    for h in sys.argv[1:]:
        print(f"{h}: {run_hero(h)[1]}", flush=True)
