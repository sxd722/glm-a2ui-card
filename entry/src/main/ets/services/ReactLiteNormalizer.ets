export function normalizeReactLiteSource(raw: string): string {
  let normalized: string = raw.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  normalized = normalized.replace(/```(?:tsx|typescript|javascript|jsx)?/g, '').replace(/```/g, '');
  let start: number = normalized.indexOf('export default function App');
  if (start >= 0) { normalized = normalized.substring(start); }
  let end: number = normalized.lastIndexOf('}');
  if (end >= 0) { normalized = normalized.substring(0, end + 1); }
  let lines: string[] = normalized.split('\n');
  let output: string[] = [];
  for (let i: number = 0; i < lines.length; i++) {
    let line: string = lines[i].replace(/\s+$/g, '');
    if (line.trim().indexOf('//') === 0) { continue; }
    output.push(line);
  }
  return output.join('\n').trim();
}
