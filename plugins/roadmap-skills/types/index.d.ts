// The value this plugin keeps in $.state: whether a classic event reached it
// in this session.
declare module 'claude-code' {
  interface PluginState {
    'roadmap-skills': { classic: boolean }
  }
}
