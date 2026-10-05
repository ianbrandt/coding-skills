// claude plugin test: gate.ts against a stand-in for gate.sh. What the script
// itself does under the module is in gate-test.sh.
import { expect, test } from 'claude-code/testing'

// script <runs>: answers each `$.process.run` in turn, and records the model
// request and the files written between runs.
function script(on: any, runs: { exitCode: number; stdout?: string; stderr?: string }[], base = '2.1.289') {
  on('session.version', () => ({ value: { version: base, base, builtAt: '' } }))
  on('session.id', () => ({ value: 's1' }))
  on('session.cwd', () => ({ value: '/proj' }))
  const seen = { runs: 0, env: '', stdin: '', model: '', system: '', written: [] as string[], removed: '' }
  on('process.run', (_$: any, e: any) => {
    if (e.argv[0] === 'rm') {
      seen.removed = e.argv[2]
      return { value: { exitCode: 0, stdout: '', stderr: '' } }
    }
    seen.env = e.init?.env?.WRITING_CONVENTIONS_MODULE
    seen.stdin = e.init?.stdin
    return { value: { stdout: '', stderr: '', ...runs[seen.runs++] } }
  })
  on('fs.read', (_$: any, e: any) => ({ value: `read ${e.path}` }))
  on('fs.write', (_$: any, e: any) => { seen.written.push(e.path); return { value: undefined } })
  on('model.complete', (_$: any, e: any) => {
    seen.model = e.model
    seen.system = e.system
    return {
      value: e.model === 'down'
        ? { isAnswered: false, reason: 'api-error', status: 529, usage: {} }
        : { isAnswered: true, text: 'PASS', usage: {} },
    }
  })
  on('tool.call', () => ({ result: { stdout: 'ran' } }))
  return seen
}

test('a finding denies the call after one model request', async ($: any, on: any) => {
  const seen = script(on, [
    { exitCode: 3, stdout: '1\nsonnet\n/tmp/claude-gate-ask-t\n' },
    { exitCode: 2, stderr: '"The report says so" -> x' },
  ])
  const ran = await $.tool.call({ tool: 'Bash', command: 'git commit -m "The report says so"' })
  expect(ran.deny).toBe('"The report says so" -> x')
  expect(seen.runs).toBe(2)
  expect(seen.env).toBe('1')
  expect(JSON.parse(seen.stdin)).toMatchObject({ tool_name: 'Bash', tool_input: { command: 'git commit -m "The report says so"' } })
  expect(seen.model).toBe('sonnet')
  expect(seen.system).toBe('read /tmp/claude-gate-ask-t/system.1')
  expect(seen.written).toEqual(['/tmp/claude-gate-ask-t/reply.1'])
  expect(seen.removed).toBe('')
})

test('a model call that failed is written as a failure, and the call runs', async ($: any, on: any) => {
  const seen = script(on, [
    { exitCode: 3, stdout: '1\ndown\n/tmp/asks\n' },
    { exitCode: 0, stdout: '{"systemMessage":"writing-conventions: model review is off"}' },
  ])
  const ran = await $.tool.call({ tool: 'Bash', command: 'git commit -m x' })
  expect(ran.result).toEqual({ stdout: 'ran' })
  expect(seen.written).toEqual(['/tmp/asks/fail.1'])
})

test('a note from the script reaches the model as context', async ($: any, on: any) => {
  script(on, [{ exitCode: 0, stdout: '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"The body in m.txt was not read."}}' }])
  const ran = await $.tool.call({ tool: 'Bash', command: 'git commit -F m.txt' })
  expect(ran.context).toEqual(['The body in m.txt was not read.'])
})

test('the command hook handles the call after three requests, and the requests are removed', async ($: any, on: any) => {
  const ask = { exitCode: 3, stdout: '1\nsonnet\n/tmp/claude-gate-ask-t\n' }
  const seen = script(on, [ask, ask, ask])
  const ran = await $.tool.call({ tool: 'Bash', command: 'git commit -m x' })
  expect(ran.result).toEqual({ stdout: 'ran' })
  expect(seen.runs).toBe(3)
  expect(seen.removed).toBe('/tmp/claude-gate-ask-t')
})

test('the command hook handles the call on any other exit', async ($: any, on: any) => {
  const seen = script(on, [{ exitCode: 4 }])
  const ran = await $.tool.call({ tool: 'Bash', command: 'git commit -m x' })
  expect(ran.result).toEqual({ stdout: 'ran' })
  expect(seen.runs).toBe(1)
})

test('the command hook handles the call when the CLI is older than the one checked', async ($: any, on: any) => {
  const seen = script(on, [], '2.1.288')
  await $.tool.call({ tool: 'Bash', command: 'git commit -m x' })
  expect(seen.runs).toBe(0)
})

test('a tool the gate does not read starts no script', async ($: any, on: any) => {
  const seen = script(on, [])
  await $.tool.call({ tool: 'Read', file_path: '/tmp/x' })
  expect(seen.runs).toBe(0)
})
