export type ReactLiteStreamPhase = 'connecting' | 'first-token' | 'state' | 'app-shell' |
  'page-start' | 'page-complete' | 'stream-complete' | 'compiling' | 'validating' |
  'quality-gate' | 'repairing' | 'complete' | 'cancelled';

export interface ReactLiteStreamProgress {
  phase: ReactLiteStreamPhase;
  source: string;
  updatedAt: number;
}

export interface GlmStreamHandle {
  cancel(): void;
}

export function inferReactLiteStreamPhase(source: string, previous: ReactLiteStreamPhase = 'connecting'): ReactLiteStreamPhase {
  if (source.length === 0) { return previous; }
  if (source.indexOf('useState(') >= 0 && previous === 'first-token') { return 'state'; }
  if (source.indexOf('<AppShell') >= 0 && (previous === 'state' || previous === 'first-token')) { return 'app-shell'; }
  if (source.indexOf('<Page') >= 0 && previous === 'app-shell') { return 'page-start'; }
  return previous === 'connecting' ? 'first-token' : previous;
}
