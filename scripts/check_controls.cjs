/** Static UI contract lint; this does not mount or run the application. */
const fs = require('node:fs');
const path = require('node:path');
const parser = require('@babel/parser');
const traverse = require('@babel/traverse').default;
const root = path.resolve(__dirname, '..');
const files = fs.readdirSync(path.join(root, 'web/src')).filter(name => name.endsWith('.tsx'));
let checked = 0;
const errors = [];
const actionWords = /^(Back|Close|Cancel|Done|Delete|More|Show|Share|Try again|Add comment|Save (?:note|moment|short|profile|draft)|View credits|View original|Choose (?:a|another)|Open Shorts|Get started)(?:\b|$)/;
for (const name of files) {
  const file = path.join(root, 'web/src', name);
  const source = fs.readFileSync(file, 'utf8');
  const ast = parser.parse(source, {sourceType:'module', plugins:['jsx','typescript']});
  traverse(ast, {JSXElement(p) {
    const n = p.node;
    const tag = n.openingElement.name.name;
    if (tag === 'main' && n.openingElement.attributes.some(a => a.name?.name === 'className' && a.value?.value === 'welcome')) {
      const buttons = n.children.flatMap(child => child.children || []).filter(child =>
        child.type === 'JSXElement' && ['button', 'ActionButton'].includes(child.openingElement.name.name)
      );
      const entry = buttons[0];
      const visibleLogin = entry?.children.some(child =>
        (child.type === 'JSXText' && child.value.trim() === 'Log in') ||
        (child.type === 'JSXExpressionContainer' && child.expression.alternate?.value === 'Log in')
      );
      if (buttons.length !== 1 || entry.openingElement.name.name !== 'button' || !visibleLogin)
        errors.push(`${name}: Welcome requires one visible Log in text button.`);
    }
    if (!['button','ActionButton','ReactionButton','IconButton','Glyph','Icon'].includes(tag)) return;
    checked++;
    if (tag === 'ActionButton') {
      const placement = n.openingElement.attributes.find(a => a.name?.name === 'labelPosition')?.value?.value;
      const menu = p.findParent(parent => parent.isJSXElement() && parent.node.openingElement.attributes.some(a =>
        a.name?.name === 'className' && a.value?.value === 'menu-actions'
      ));
      if (menu && placement !== 'below') errors.push(`${name}:${n.loc.start.line}: Menu actions require a visible label below the icon.`);
      if (placement === 'beside' && name !== 'MemberProfile.tsx') errors.push(`${name}:${n.loc.start.line}: Side-by-side labels are for member profiles.`);
    }
    const icon = n.openingElement.attributes.find(a => ['icon','name'].includes(a.name?.name) && a.value?.type === 'StringLiteral');
    if (icon && ['ActionButton','IconButton','Glyph','Icon'].includes(tag) && !fs.existsSync(path.join(root,'Assets/icons',icon.value.value+'.png'))) errors.push(`${name}:${n.loc.start.line}: Missing icon ${icon.value.value}.`);
    if (tag === 'button') {
      const literal = n.children.filter(c => c.type === 'JSXText').map(c => c.value).join(' ').replace(/\s+/g,' ').trim();
      if (actionWords.test(literal)) errors.push(`${name}:${n.loc.start.line}: Bare text action '${literal}'.`);
    }
  }});
  if (/route\.name === "search"|panel === "search"/.test(source)) errors.push(`${name}: Detached search destination is forbidden.`);
}
if(errors.length) {console.error(errors.join('\n'));process.exit(1);}
console.log(`${checked} JSX controls statically inspected: no bare text actions, no detached search destination, and referenced action glyphs exist.`);
