#!/usr/bin/env bash
# check-doc-sync.sh — keep the skill indexes in sync with skills/.
#
# Checks:
#   1. every directory in skills/ has SKILL.md, and its frontmatter `name` equals the directory name
#   2. README.md and README.zh.md index tables list exactly those skills, with matching versions
#   3. (optional) a published Feishu/Lark document's index table covers exactly those skills
#
# Usage:
#   tools/check-doc-sync.sh                                  # repository checks only
#   DOC_ID=<docx obj_token> tools/check-doc-sync.sh           # also check a published document
#                                                             # (needs FEISHU_APP_ID / FEISHU_APP_SECRET,
#                                                              #  from the environment or ~/.hermes/.env)
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
exec python3 - "$@" <<'PYEOF'
import io, json, os, re, sys, urllib.request

fail = []
S = 'skills'
skills = {}
for d in sorted(os.listdir(S)):
    p = os.path.join(S, d, 'SKILL.md')
    if not os.path.isfile(p):
        fail.append('%s: missing SKILL.md' % d)
        continue
    t = io.open(p, encoding='utf-8').read()
    name = (re.search(r'^name:\s*(\S+)', t, re.M) or [None, ''])[1]
    ver = (re.search(r'^version:\s*(\S+)', t, re.M) or [None, ''])[1]
    skills[d] = (name, ver)
    if name != d:
        fail.append('%s: frontmatter name is %r' % (d, name))
    if not os.path.isfile(os.path.join(S, d, 'SKILL.zh.md')):
        fail.append('%s: missing SKILL.zh.md' % d)

for rm in ('README.md', 'README.zh.md'):
    if not os.path.exists(rm):
        fail.append('%s: missing' % rm)
        continue
    t = io.open(rm, encoding='utf-8').read()
    rows = dict(re.findall(r'`([a-z0-9][a-z0-9-]*)`<br>`v([0-9][0-9.]*)`', t))
    if set(rows) != set(skills):
        fail.append('%s: index rows %s != skills/ %s' % (rm, sorted(set(rows)), sorted(skills)))
    for d, v in rows.items():
        if d in skills and skills[d][1] != v:
            fail.append('%s: %s version %s != SKILL.md %s' % (rm, d, v, skills[d][1]))
    if len(rows) != len(skills):
        fail.append('%s: %d index rows for %d skills' % (rm, len(rows), len(skills)))

print('repo: %d skills in skills/; README indexes %s' % (
    len(skills), 'match' if not any('index rows' in f or 'index rows for' in f for f in fail) else 'MISMATCH'))

doc = os.environ.get('DOC_ID')
if not doc:
    print('feishu: skipped (pass DOC_ID=<obj_token> to check a published document)')
else:
    env = {}
    envf = os.path.expanduser('~/.hermes/.env')
    if os.path.exists(envf):
        for ln in io.open(envf, encoding='utf-8'):
            if '=' in ln and not ln.strip().startswith('#'):
                k, _, v = ln.strip().partition('=')
                env[k] = v
    aid = os.environ.get('FEISHU_APP_ID') or env.get('FEISHU_APP_ID')
    sec = os.environ.get('FEISHU_APP_SECRET') or env.get('FEISHU_APP_SECRET')
    if not (aid and sec):
        print('feishu: skipped (set FEISHU_APP_ID / FEISHU_APP_SECRET)')
    else:
        def api(path, body=None, method=None, tok=None):
            data = json.dumps(body).encode() if body is not None else None
            req = urllib.request.Request('https://open.feishu.cn/open-apis' + path, data=data,
                                         method=method or ('POST' if data else 'GET'))
            req.add_header('Content-Type', 'application/json; charset=utf-8')
            if tok:
                req.add_header('Authorization', 'Bearer ' + tok)
            return json.loads(urllib.request.urlopen(req, timeout=60).read().decode('utf-8'))

        tok = api('/auth/v3/tenant_access_token/internal', {'app_id': aid, 'app_secret': sec})['tenant_access_token']
        blocks, pt = [], None
        while True:
            q = '/docx/v1/documents/%s/blocks?page_size=500&document_revision_id=-1' % doc
            if pt:
                q += '&page_token=' + pt
            d = api(q, tok=tok)['data']
            blocks += d.get('items', [])
            pt = d.get('page_token')
            if not d.get('has_more'):
                break
        byid = {b['block_id']: b for b in blocks}

        def btext(b):
            for k in ('text', 'heading1', 'heading2', 'heading3', 'heading4', 'heading5',
                      'bullet', 'ordered', 'quote', 'todo'):
                if isinstance(b.get(k), dict):
                    return ''.join(e.get('text_run', {}).get('content', '') for e in b[k].get('elements', []))
            return ''

        found = set()
        for b in blocks:
            if b.get('block_type') != 31:
                continue
            for cid in (b.get('children') or []):
                cb = byid.get(cid)
                if not cb:
                    continue
                inner = (cb.get('children') or [None])[0]
                # cell text may be plain, backticked or wrapped in a link — normalise before matching
                txt = btext(byid[inner]).strip().strip('`').strip() if inner in byid else ''
                m = re.match(r'^([a-z0-9][a-z0-9-]*)\b', txt)
                if m and m.group(1) in skills:
                    found.add(m.group(1))
        missing = sorted(set(skills) - found)
        extra = sorted(found - set(skills))
        if missing or extra:
            fail.append('feishu: index out of sync (missing: %s; unknown: %s)' % (missing or '-', extra or '-'))
        print('feishu: document index covers %d/%d skills%s' % (
            len(found & set(skills)), len(skills),
            '' if not (missing or extra) else ' | missing: %s | unknown: %s' % (missing or '-', extra or '-')))

if fail:
    print('\nFAIL (%d):' % len(fail))
    for f in fail:
        print('  -', f)
    sys.exit(1)
print('\nOK: indexes in sync')
PYEOF
