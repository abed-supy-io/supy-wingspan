// tools/generators/plopfile.js
//
// Scaffolds a new, correctly-layered + correctly-tagged domain under libs/<domain>/.
// Run via:  npm run g:domain <name>   (wired in package.json to `plop --plopfile tools/generators/plopfile.js domain`)
//
// Placeholders available in templates:
//   {{kebab name}}   stock-count
//   {{pascal name}}  StockCount
//   {{camel name}}   stockCount

module.exports = function (plop) {
  const L = 'templates/domain';

  // Register case helpers explicitly (built-in names differ across plop versions).
  const words = (s) =>
    String(s)
      .replace(/([a-z0-9])([A-Z])/g, '$1 $2')
      .replace(/[_-]+/g, ' ')
      .trim()
      .toLowerCase()
      .split(/\s+/)
      .filter(Boolean);
  plop.setHelper('kebab', (s) => words(s).join('-'));
  plop.setHelper('camel', (s) =>
    words(s)
      .map((w, i) => (i === 0 ? w : w[0].toUpperCase() + w.slice(1)))
      .join(''),
  );
  plop.setHelper('pascal', (s) => words(s).map((w) => w[0].toUpperCase() + w.slice(1)).join(''));

  plop.setGenerator('domain', {
    description: 'Scaffold a new bounded-context domain (api + logic + domain + data, tagged)',
    prompts: [
      {
        type: 'input',
        name: 'name',
        message: 'Domain name (kebab-case, e.g. stock-count):',
        validate: (v) => /^[a-z][a-z0-9-]*$/.test(v) || 'Use kebab-case: lowercase, digits, hyphens.',
      },
    ],
    actions: (data) => {
      // Anchor output to where the command was invoked (repo root via npm script),
      // not the plopfile's own directory. Plop still renders handlebars in the path.
      const base = `${process.cwd()}/libs/{{kebab name}}`;
      const t = (file) => `${L}/${file}.hbs`;
      const add = (path, template) => ({ type: 'add', path, templateFile: t(template) });

      return [
        // ── project.json files (carry the boundary tags) ──
        add(`${base}/api/project.json`, 'project.api'),
        add(`${base}/logic/project.json`, 'project.logic'),
        add(`${base}/domain/model/project.json`, 'project.domain-model'),
        add(`${base}/domain/service/project.json`, 'project.domain-service'),
        add(`${base}/data/project.json`, 'project.data'),

        // ── domain/model ──
        add(`${base}/domain/model/src/entities/{{kebab name}}.aggregate.ts`, 'aggregate'),
        add(`${base}/domain/model/src/value-objects/{{kebab name}}-id.vo.ts`, 'id.vo'),
        add(`${base}/domain/model/src/value-objects/{{kebab name}}-state.vo.ts`, 'state.vo'),
        add(`${base}/domain/model/src/events/{{kebab name}}-created.event.ts`, 'created.event'),
        add(`${base}/domain/model/src/factories/{{kebab name}}.factory.ts`, 'factory'),
        add(`${base}/domain/model/src/{{kebab name}}.repository.ts`, 'repository.interface'),
        add(`${base}/domain/model/src/index.ts`, 'index.domain-model'),

        // ── data ──
        add(`${base}/data/src/lib/schemas/{{kebab name}}.schema.ts`, 'schema'),
        add(`${base}/data/src/lib/transformers/{{kebab name}}-input.transformer.ts`, 'input.transformer'),
        add(`${base}/data/src/lib/transformers/{{kebab name}}-output.transformer.ts`, 'output.transformer'),
        add(`${base}/data/src/lib/repositories/{{kebab name}}.repository.ts`, 'repository.impl'),
        add(`${base}/data/src/lib/{{kebab name}}-data.module.ts`, 'data.module'),
        add(`${base}/data/src/index.ts`, 'index.data'),

        // ── logic ──
        add(`${base}/logic/src/lib/interactors/create-{{kebab name}}.interactor.ts`, 'interactor'),
        add(`${base}/logic/src/lib/{{kebab name}}-logic.module.ts`, 'logic.module'),
        add(`${base}/logic/src/index.ts`, 'index.logic'),

        // ── api ──
        add(`${base}/api/src/lib/exchanges/create-{{kebab name}}.payload.ts`, 'payload'),
        add(`${base}/api/src/lib/controllers/{{kebab name}}.rpc.controller.ts`, 'controller'),
        add(`${base}/api/src/lib/{{kebab name}}-api.module.ts`, 'api.module'),
        add(`${base}/api/src/index.ts`, 'index.api'),

        // ── reminder of the manual wiring steps the generator can't do for you ──
        () =>
          `\nNEXT STEPS (cannot be auto-wired safely):\n` +
          `  1. Add @supy/{{kebab name}}/* aliases to tsconfig.base.json\n` +
          `  2. Append to eslint.config.mjs depConstraints:\n` +
          `       { sourceTag: 'scope:{{kebab name}}', onlyDependOnLibsWithTags: ['scope:{{kebab name}}', 'scope:shared'] }\n` +
          `  3. Register {{pascal name}}ApiModule in apps/api/src/app/app.module.ts\n` +
          `  4. Register event discriminators in domain-events.discriminators.ts\n` +
          `  5. Run: npx nx lint {{kebab name}}-domain-model {{kebab name}}-logic {{kebab name}}-data {{kebab name}}-api\n`,
      ];
    },
  });
};
