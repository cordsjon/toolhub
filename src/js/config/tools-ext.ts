// Extension registry (toolhub). Merged into the upstream registry by one spread in tools.ts.
// Field order href, name, … is load-bearing: scripts/generate-static-tool-links.mjs regex-matches href then name.
export type ExtCategoryName = 'Image' | 'Office & Data' | 'Text & Dev';

export interface ExtTool {
  href: string;
  name: string;
  icon: string;
  subtitle: string;
  i18nKey: string;
  category: ExtCategoryName;
}

export interface ExtCategory {
  name: ExtCategoryName;
  i18nKey: string;
  tools: ExtTool[];
}

export const extCategories: ExtCategory[] = [
  { name: 'Image', i18nKey: 'tools:ext.categories.image', tools: [] },
  {
    name: 'Office & Data',
    i18nKey: 'tools:ext.categories.officeData',
    tools: [],
  },
  { name: 'Text & Dev', i18nKey: 'tools:ext.categories.textDev', tools: [] },
];
