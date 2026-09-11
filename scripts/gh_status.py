import subprocess
import urllib.request
import json

def get_token():
    p = subprocess.Popen(['git', 'credential', 'fill'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    out, _ = p.communicate('protocol=https\nhost=github.com\n')
    creds = dict(line.split('=', 1) for line in out.splitlines() if '=' in line)
    return creds.get('password', '')

import sys

def main():
    token = get_token()
    headers = {'Authorization': f'token {token}', 'User-Agent': 'gh-status'} if token else {'User-Agent': 'gh-status'}
    if len(sys.argv) > 2 and sys.argv[1] == 'rerun':
        run_id = sys.argv[2]
        req = urllib.request.Request(f'https://api.github.com/repos/thunderkex/revancex/actions/runs/{run_id}/rerun', headers=headers, method='POST')
        with urllib.request.urlopen(req) as resp:
            print(f"Rerun triggered, status: {resp.status}")
        return

    if len(sys.argv) > 1:
        run_id = sys.argv[1]
        req = urllib.request.Request(f'https://api.github.com/repos/thunderkex/revancex/actions/runs/{run_id}/jobs', headers=headers)
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode())
        for j in data['jobs']:
            print(f"Job: {j['name']} ({j['status']} / {j['conclusion']})")
            for st in j.get('steps', []):
                print(f"  - {st['name']:<40} : {st['status']:<10} / {str(st['conclusion']):<10}")
        return

    req = urllib.request.Request('https://api.github.com/repos/thunderkex/revancex/actions/runs?per_page=10', headers=headers)
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode())
    for r in data['workflow_runs']:
        msg = r['head_commit']['message'].splitlines()[0] if r.get('head_commit') else ''
        print(f"{r['id']} | {r['name']:<22} | {r['status']:<11} | {str(r['conclusion']):<10} | {msg}")

if __name__ == '__main__':
    main()
