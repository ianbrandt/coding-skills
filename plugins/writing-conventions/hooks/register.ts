// The plugin's one hooks module: hooks.json may list only one.
import type { Register } from 'claude-code'
import { register as dash } from './dash'
import { register as gate } from './gate'

export const register: Register = (on, options) => {
  gate(on, options)
  dash(on, options)
}
