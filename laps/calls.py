import json, sys
# Prints the init event's model and plugins, then every tool call in order with its result's first line.
names = {}
for line in open(sys.argv[1]):
    try: e = json.loads(line)
    except Exception: continue
    if e.get('type') == 'system' and e.get('subtype') == 'init':
        print('MODEL', e.get('model'))
        print('PLUGINS', [p.get('name') + '|' + str(p.get('source', p.get('path', ''))) for p in e.get('plugins', [])])
        print('MCP-TOOLS', [t for t in e.get('tools', []) if t.startswith('mcp__') and ('skills' in t or 'writing' in t)])
    msg = e.get('message')
    if not isinstance(msg, dict): msg = {}
    sub = ' (sub)' if e.get('parent_tool_use_id') else ''
    for c in msg.get('content', []) if isinstance(msg.get('content'), list) else []:
        if c.get('type') == 'tool_use':
            names[c['id']] = c['name']
            print(f"CALL{sub} {c['name']} {json.dumps(c['input'])[:300]}")
        elif c.get('type') == 'tool_result':
            body = c.get('content')
            if isinstance(body, list): body = ' '.join(x.get('text', '') for x in body if isinstance(x, dict))
            print(f"  -> {'ERROR ' if c.get('is_error') else ''}{str(body)[:400]!r}")
        elif c.get('type') == 'text' and len(sys.argv) > 2:
            print(f"TEXT{sub} {c['text'][:1500]}")
    if e.get('type') == 'result':
        print('RESULT', e.get('subtype'), e.get('num_turns'), e.get('duration_ms'), list((e.get('modelUsage') or {}).keys()))
        print(e.get('result'))
