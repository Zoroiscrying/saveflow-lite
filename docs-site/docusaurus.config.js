const {themes} = require('prism-react-renderer');

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'SaveFlow Lite',
  tagline: 'Scene-authored save workflows for Godot 4',
  url: 'https://zoroiscrying.github.io',
  baseUrl: '/saveflow-lite/',
  organizationName: 'Zoroiscrying',
  projectName: 'saveflow-lite',
  trailingSlash: false,
  onBrokenLinks: 'throw',
  markdown: {
    hooks: {
      onBrokenMarkdownLinks: 'warn',
    },
  },
  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },
  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: require.resolve('./sidebars.js'),
          editUrl: 'https://github.com/Zoroiscrying/saveflow-lite/tree/main/docs-site/',
        },
        blog: false,
        theme: {
          customCss: require.resolve('./src/css/custom.css'),
        },
      },
    ],
  ],
  themeConfig: {
    navbar: {
      title: 'SaveFlow Lite',
      items: [
        {to: '/docs', label: 'Docs', position: 'left'},
        {to: '/docs/getting-started/install', label: 'Getting Started', position: 'left'},
        {to: '/docs/examples', label: 'Examples', position: 'left'},
        {to: '/docs/reference', label: 'Reference', position: 'left'},
        {
          href: 'https://github.com/Zoroiscrying/saveflow-lite',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Learn',
          items: [
            {label: 'Getting Started', to: '/docs/getting-started/install'},
            {label: 'Core Concepts', to: '/docs/concepts/ownership-model'},
            {label: 'C#', to: '/docs/csharp'},
            {label: 'Reference', to: '/docs/reference'},
          ],
        },
        {
          title: 'Workflow',
          items: [
            {label: 'Choose a Source', to: '/docs/workflows/choose-your-source'},
            {label: 'Save Slots', to: '/docs/workflows/project-save-slots'},
            {label: 'Troubleshooting', to: '/docs/troubleshooting'},
          ],
        },
        {
          title: 'Project',
          items: [
            {label: 'GitHub', href: 'https://github.com/Zoroiscrying/saveflow-lite'},
            {label: 'Roadmap', to: '/docs/roadmap'},
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} SaveFlow Lite.`,
    },
    prism: {
      theme: themes.github,
      darkTheme: themes.dracula,
      additionalLanguages: [
        'bash',
        'csharp',
        'gdscript',
        'json',
        'markdown',
        'powershell',
      ],
    },
  },
};

module.exports = config;
