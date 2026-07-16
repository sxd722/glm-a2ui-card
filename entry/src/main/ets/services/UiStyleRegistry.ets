const COLORS: string[] = ['transparent', 'surface', 'card', 'primary', 'secondary', 'accent', 'ink', 'muted', 'white', 'black', 'danger', 'success', 'border'];
const SPACING: string[] = ['0', '1', '2', '3', '4', '5', '6', '8', '10', '12', '16', '20', '24', '32'];

export function isSupportedUtilityToken(token: string): boolean {
  if (['flex', 'flex-col', 'flex-row', 'relative', 'overflow-hidden', 'w-full', 'h-full', 'flex-1',
    'items-center', 'items-end', 'justify-center', 'justify-between', 'justify-end', 'text-center', 'text-right',
    'object-cover', 'object-contain', 'border', 'shadow-sm', 'shadow-md', 'shadow-lg', 'backdrop-blur-sm',
    'backdrop-blur-md'].indexOf(token) >= 0) { return true; }
  if (/^(p|px|py|pt|pr|pb|pl|m|mx|my|mt|mr|mb|ml|gap)-/.test(token)) {
    let value: string = token.substring(token.lastIndexOf('-') + 1); return SPACING.indexOf(value) >= 0;
  }
  if (token.indexOf('h-') === 0) { return SPACING.indexOf(token.substring(2)) >= 0; }
  if (token.indexOf('rounded') === 0) { return ['rounded', 'rounded-sm', 'rounded-md', 'rounded-lg', 'rounded-xl', 'rounded-2xl', 'rounded-3xl', 'rounded-full'].indexOf(token) >= 0; }
  if (token.indexOf('opacity-') === 0) { return ['0', '25', '50', '60', '70', '80', '90'].indexOf(token.substring(8)) >= 0; }
  if (token.indexOf('font-') === 0) { return ['font-medium', 'font-semibold', 'font-bold'].indexOf(token) >= 0; }
  if (token.indexOf('text-') === 0) {
    let textToken: string = token.substring(5);
    if (['xs', 'sm', 'base', 'lg', 'xl', '2xl', '3xl', '4xl'].indexOf(textToken) >= 0) { return true; }
    return COLORS.indexOf(textToken.split('/')[0]) >= 0;
  }
  if (token.indexOf('bg-') === 0) { return COLORS.indexOf(token.substring(3).split('/')[0]) >= 0; }
  if (token.indexOf('from-') === 0) { return COLORS.indexOf(token.substring(5).split('/')[0]) >= 0; }
  if (token.indexOf('to-') === 0) { return COLORS.indexOf(token.substring(3).split('/')[0]) >= 0; }
  if (token.indexOf('border-') === 0) { return COLORS.indexOf(token.substring(7).split('/')[0]) >= 0; }
  return token === 'bg-gradient-to-r' || token === 'bg-gradient-to-b' || token === 'bg-gradient-to-br';
}
