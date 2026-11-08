// Extract a self-contained subset of top-level declarations from the minified Spelunkr bundle.
// usage: node extract.mjs <bundle.js> <out.js> root1,root2,...   |  node extract.mjs <bundle.js> --show name1,name2
import fs from 'node:fs';
import * as acorn from 'acorn';
import * as escope from 'eslint-scope';

const [bundlePath, out, rootsArg] = process.argv.slice(2);
const src = fs.readFileSync(bundlePath, 'utf8');
const ast = acorn.parse(src, { ecmaVersion: 'latest', sourceType: 'module', ranges: true });
const sm = escope.analyze(ast, { ecmaVersion: 2022, sourceType: 'module' });
const modScope = sm.globalScope.childScopes.find(s => s.type === 'module');

// top-level units: each function/class decl, each variable declarator
const units = []; // {names:[], start, end, text, kind}
for (const st of ast.body) {
  if (st.type === 'FunctionDeclaration' || st.type === 'ClassDeclaration') {
    units.push({ names: [st.id.name], start: st.start, end: st.end, text: src.slice(st.start, st.end), kind: 'decl' });
  } else if (st.type === 'VariableDeclaration') {
    for (const d of st.declarations) {
      const names = [];
      (function collect(p) {
        if (!p) return;
        if (p.type === 'Identifier') names.push(p.name);
        else if (p.type === 'ObjectPattern') p.properties.forEach(q => collect(q.value || q.argument));
        else if (p.type === 'ArrayPattern') p.elements.forEach(collect);
        else if (p.type === 'AssignmentPattern') collect(p.left);
        else if (p.type === 'RestElement') collect(p.argument);
      })(d.id);
      units.push({ names, start: d.start, end: d.end, text: `${st.kind === 'const' ? 'let' : st.kind} ${src.slice(d.start, d.end)};`, kind: st.kind });
    }
  } else {
    units.push({ names: [], start: st.start, end: st.end, text: src.slice(st.start, st.end), kind: 'stmt', type: st.type });
  }
}
const byName = new Map();
units.forEach(u => u.names.forEach(n => byName.set(n, u)));
const unitAt = pos => units.find(u => pos >= u.start && pos < u.end);

// deps: for each module-scope variable, every reference -> containing unit depends on var's unit
const deps = new Map(units.map(u => [u, new Set()]));
const writers = new Map(); // var unit -> units that assign to it (top-level side effects)
for (const v of modScope.variables) {
  const target = byName.get(v.name);
  if (!target) continue;
  for (const ref of v.references) {
    const from = unitAt(ref.identifier.start);
    if (!from || from === target) continue;
    deps.get(from).add(target);
    if (ref.isWrite() && from.kind === 'stmt') { if (!writers.has(target)) writers.set(target, new Set()); writers.get(target).add(from); }
  }
}

if (out === '--show') {
  for (const n of rootsArg.split(',')) {
    const u = byName.get(n);
    console.log(`==== ${n}: ${u ? u.text.slice(0, 1500) : 'NOT FOUND'}`);
  }
  process.exit(0);
}

const roots = rootsArg.split(',').map(n => { const u = byName.get(n); if (!u) throw new Error('no root ' + n); return u; });
const seen = new Set();
(function visit(list) { for (const u of list) { if (seen.has(u)) continue; seen.add(u); visit(deps.get(u)); } })(roots);
const picked = units.filter(u => seen.has(u)); // keep original order
const total = picked.reduce((a, u) => a + u.text.length, 0);
console.error(`picked ${picked.length} units, ${total} chars`);
const exportsList = rootsArg.split(',');
fs.writeFileSync(out, `// AUTO-EXTRACTED from spelunkr.tv bundle — schedule engine (pure functions).\n${picked.map(u => u.text).join('\n')}\nexport { ${exportsList.join(', ')} };\n`);
// report suspicious units (big ones / DOM use)
for (const u of picked) if (u.text.length > 3000 || /document\.|window\.|localStorage/.test(u.text)) console.error('  check:', u.names.join(','), u.text.length, u.text.slice(0, 100).replace(/\n/g, ' '));
