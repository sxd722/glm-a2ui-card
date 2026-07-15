export type ReactLiteTokenKind = 'identifier' | 'string' | 'number' | 'jsxText' | 'operator' |
  'punctuation' | 'comment' | 'eof';

export interface ReactLiteToken {
  kind: ReactLiteTokenKind;
  value: string;
  offset: number;
  line: number;
  column: number;
}

export type ReactLiteExpressionKind = 'literal' | 'path' | 'unary' | 'binary' | 'conditional' |
  'array' | 'object' | 'call';

export interface ReactLiteExpressionProperty {
  key: string;
  value: ReactLiteExpression;
}

export interface ReactLiteExpression {
  kind: ReactLiteExpressionKind;
  value: string;
  operator: string;
  path: string[];
  left?: ReactLiteExpression;
  right?: ReactLiteExpression;
  test?: ReactLiteExpression;
  consequent?: ReactLiteExpression;
  alternate?: ReactLiteExpression;
  items: ReactLiteExpression[];
  properties: ReactLiteExpressionProperty[];
  callee: string;
  args: ReactLiteExpression[];
  line: number;
  column: number;
}

export type ReactLiteAstNodeKind = 'element' | 'if' | 'forEach' | 'text';

export interface ReactLiteAstAttribute {
  name: string;
  value?: ReactLiteExpression;
  stringValue: string;
  booleanValue: boolean;
  line: number;
  column: number;
}

export interface ReactLiteAstNode {
  kind: ReactLiteAstNodeKind;
  component: string;
  attributes: ReactLiteAstAttribute[];
  children: ReactLiteAstNode[];
  line: number;
  column: number;
}

export interface ReactLiteAst {
  initialState: ReactLiteExpression;
  computed: Record<string, ReactLiteExpression>;
  root: ReactLiteAstNode | undefined;
}

export interface ReactLiteDiagnostic {
  code: string;
  severity: 'error' | 'warning';
  message: string;
  line: number;
  column: number;
  length: number;
  suggestion: string;
}

export interface ReactLiteParseResult {
  ok: boolean;
  ast: ReactLiteAst | undefined;
  diagnostics: ReactLiteDiagnostic[];
}
