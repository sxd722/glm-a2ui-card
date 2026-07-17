export enum SemanticIconName {
  NONE = 'none',
  BACK = 'back',
  MORE = 'more',
  ADD = 'add',
  CHECK = 'check',
  CLOSE = 'close',
  SEARCH = 'search',
  FILTER = 'filter',
  CALENDAR = 'calendar',
  LOCATION = 'location',
  HEART = 'heart',
  PLAY = 'play',
  WARNING = 'warning',
  INFO = 'info',
  SPARKLE = 'sparkle',
  ARROW_RIGHT = 'arrow-right'
}

export function iconGlyph(icon: string): string {
  switch (icon) {
    case SemanticIconName.BACK: return '<';
    case SemanticIconName.ADD: return '+';
    case SemanticIconName.CHECK: return '✓';
    case SemanticIconName.CLOSE: return '×';
    case SemanticIconName.SEARCH: return '⌕';
    case SemanticIconName.FILTER: return '≡';
    case SemanticIconName.CALENDAR: return '□';
    case SemanticIconName.LOCATION: return '•';
    case SemanticIconName.HEART: return '♡';
    case SemanticIconName.PLAY: return '▶';
    case SemanticIconName.WARNING: return '!';
    case SemanticIconName.INFO: return 'i';
    case SemanticIconName.SPARKLE: return '✦';
    case SemanticIconName.ARROW_RIGHT: return '→';
    case SemanticIconName.MORE: return '…';
    default: return '';
  }
}
