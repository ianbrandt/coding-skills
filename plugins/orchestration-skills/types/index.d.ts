// The values this plugin keeps in $.state: whether a classic event reached it
// in this session, and whether classic.SessionStart did.
declare module 'claude-code' {
  interface PluginState {
    'orchestration-skills': { classic: boolean; started: boolean }
  }
}
