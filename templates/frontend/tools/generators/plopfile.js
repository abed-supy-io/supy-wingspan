// tools/generators/plopfile.js
//
// Scaffolds a new NGXS feature library under libs/<feature>/ — tagged, OnPush, signal-based,
// with models, actions, state, service, URI token, smart + dumb components, resolver, and routes.
// Run via:  npm run g:feature
//
// Prompts:
//   feature — plural kebab (e.g. orders)   → Orders (classes), orders (alias/scope)
//   entity  — singular Pascal (e.g. Order)  → Order (model), order (selectors)

module.exports = function (plop) {
  const L = 'templates/feature';

  const words = (s) =>
    String(s)
      .replace(/([a-z0-9])([A-Z])/g, '$1 $2')
      .replace(/[_-]+/g, ' ')
      .trim()
      .toLowerCase()
      .split(/\s+/)
      .filter(Boolean);
  plop.setHelper('kebab', (s) => words(s).join('-'));
  plop.setHelper('camel', (s) => words(s).map((w, i) => (i ? w[0].toUpperCase() + w.slice(1) : w)).join(''));
  plop.setHelper('pascal', (s) => words(s).map((w) => w[0].toUpperCase() + w.slice(1)).join(''));
  plop.setHelper('screaming', (s) => words(s).join('_').toUpperCase());

  plop.setGenerator('feature', {
    description: 'Scaffold a new NGXS feature library (state + service + components + routes, tagged)',
    prompts: [
      {
        type: 'input',
        name: 'feature',
        message: 'Feature name (plural, kebab-case, e.g. orders):',
        validate: (v) => /^[a-z][a-z0-9-]*$/.test(v) || 'Use kebab-case: lowercase, digits, hyphens.',
      },
      {
        type: 'input',
        name: 'entity',
        message: 'Entity name (singular, PascalCase, e.g. Order):',
        validate: (v) => /^[A-Z][A-Za-z0-9]*$/.test(v) || 'Use PascalCase, e.g. Order.',
      },
    ],
    actions: () => {
      // Anchor output to the invocation dir (repo root via npm script), not the plopfile dir.
      const base = `${process.cwd()}/libs/{{kebab feature}}`;
      const t = (file) => `${L}/${file}.hbs`;
      const add = (path, template) => ({ type: 'add', path, templateFile: t(template) });

      return [
        add(`${base}/project.json`, 'project'),
        add(`${base}/src/index.ts`, 'index'),
        add(`${base}/src/lib/models/{{kebab feature}}.model.ts`, 'model'),
        add(`${base}/src/lib/config/{{kebab feature}}.config.ts`, 'config'),
        add(`${base}/src/lib/store/actions/{{kebab feature}}.actions.ts`, 'actions'),
        add(`${base}/src/lib/store/state/{{kebab feature}}.state.ts`, 'state'),
        add(`${base}/src/lib/services/{{kebab feature}}.service.ts`, 'service'),
        add(`${base}/src/lib/resolvers/{{kebab feature}}.resolver.ts`, 'resolver'),
        add(`${base}/src/lib/components/{{kebab entity}}-list/{{kebab entity}}-list.component.ts`, 'list.component'),
        add(`${base}/src/lib/components/{{kebab entity}}-list/{{kebab entity}}-list.component.html`, 'list.component.html'),
        add(`${base}/src/lib/components/{{kebab entity}}-card/{{kebab entity}}-card.component.ts`, 'card.component'),
        add(`${base}/src/lib/components/{{kebab entity}}-card/{{kebab entity}}-card.component.html`, 'card.component.html'),
        add(`${base}/src/lib/{{kebab feature}}.routes.ts`, 'routes'),

        () =>
          `\nNEXT STEPS (cannot be auto-wired safely):\n` +
          `  1. Add "@supy/{{kebab feature}}": ["libs/{{kebab feature}}/src/index.ts"] to tsconfig.base.json paths\n` +
          `  2. Append to eslint.config.mjs depConstraints:\n` +
          `       { sourceTag: 'scope:{{kebab feature}}', onlyDependOnLibsWithTags: ['scope:{{kebab feature}}', 'scope:shared'] }\n` +
          `  3. Register the lazy route in the app routing:\n` +
          `       { path: '{{kebab feature}}', loadChildren: () => import('@supy/{{kebab feature}}').then(m => m.{{screaming feature}}_ROUTES) }\n` +
          `  4. Run: npx nx lint {{kebab feature}} && npx nx test {{kebab feature}}\n`,
      ];
    },
  });
};
