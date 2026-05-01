/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  docsSidebar: [
    'intro',
    {
      type: 'category',
      label: 'Getting Started',
      collapsed: false,
      items: [
        'getting-started/install',
        'getting-started/first-save-graph',
        'getting-started/common-api-calls',
      ],
    },
    {
      type: 'category',
      label: 'Core Concepts',
      collapsed: false,
      items: [
        'concepts/save-graph',
        'concepts/ownership-model',
      ],
    },
    {
      type: 'category',
      label: 'Godot Workflows',
      collapsed: false,
      items: [
        'workflows/choose-your-source',
        'workflows/project-save-slots',
      ],
    },
    {
      type: 'category',
      label: 'Components',
      collapsed: false,
      items: [
        'components/index',
        'components/node-source',
        'components/typed-data',
        'components/entity-collections',
        'components/scopes',
        'components/slot-workflow',
        'components/pipeline-signals',
        'components/editor-tools',
      ],
    },
    {
      type: 'category',
      label: 'C#',
      collapsed: false,
      items: [
        'csharp/index',
      ],
    },
    {
      type: 'category',
      label: 'Reference',
      collapsed: false,
      items: [
        'reference/index',
        'reference/gdscript-runtime',
        'reference/source-contracts',
        'reference/component-properties',
        'reference/slot-metadata',
        'reference/pipeline-events',
        'reference/csharp-api',
      ],
    },
    {
      type: 'category',
      label: 'Examples',
      collapsed: false,
      items: [
        'examples/index',
        'examples/one-page-starter',
      ],
    },
    {
      type: 'category',
      label: 'Troubleshooting',
      collapsed: false,
      items: [
        'troubleshooting/index',
      ],
    },
    {
      type: 'category',
      label: 'Roadmap',
      collapsed: false,
      items: [
        'roadmap/index',
        'roadmap/release-checklist',
      ],
    },
  ],
};

module.exports = sidebars;
