/**
 * olon bake - production SSG
 *
 * 1) Build client bundle (dist/)
 * 2) Build SSR entry bundle (dist-ssr/)
 * 3) Discover all page slugs from JSON files under src/data/pages
 * 4) Render each slug via SSR and write dist/<slug>/index.html
 */

import { build } from 'vite';
import path from 'path';
import { fileURLToPath, pathToFileURL } from 'url';
import fs from 'fs/promises';
import { resolvePageMatchFromRegistry, resolvePublicPageDocument, webmcp } from '@olonjs/core';

const {
  buildPageContract,
  buildPageManifest,
  buildPageManifestHref,
  buildSiteManifest,
  buildLlmsTxt,
} = webmcp;

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const pagesDir = path.resolve(root, 'src/data/pages');
const collectionsDir = path.resolve(root, 'src/data/collections');
const publicDir = path.resolve(root, 'public');
const distDir = path.resolve(root, 'dist');
const distSsrDir = path.resolve(root, 'dist-ssr');

async function writeTargets(relativePath, content) {
  const targets = [
    path.resolve(publicDir, relativePath),
    path.resolve(distDir, relativePath),
  ];

  for (const targetPath of targets) {
    await fs.mkdir(path.dirname(targetPath), { recursive: true });
    await fs.writeFile(targetPath, content, 'utf-8');
  }
}

async function writeJsonTargets(relativePath, value) {
  await writeTargets(relativePath, `${JSON.stringify(value, null, 2)}\n`);
}

// Schemas go to dist-ssr ONLY: committed (dist-ssr is not gitignored) so provisioning can read
// them from the repo, but NOT served as static files — so /schemas/* falls through to the
// blob rewrite, and provision/hotSave own the served contract.
async function writeSsrJson(relativePath, value) {
  const target = path.resolve(distSsrDir, relativePath);
  await fs.mkdir(path.dirname(target), { recursive: true });
  await fs.writeFile(target, `${JSON.stringify(value, null, 2)}\n`, 'utf-8');
}

function escapeHtmlAttribute(value) {
  return String(value).replace(/&/g, '&amp;').replace(/"/g, '&quot;');
}

function toCanonicalSlug(relativeJsonPath) {
  const normalized = relativeJsonPath.replace(/\\/g, '/');
  const slug = normalized.replace(/\.json$/i, '').replace(/^\/+|\/+$/g, '');
  if (!slug) throw new Error('[bake] Invalid page slug: empty path segment');
  return slug;
}

async function readJsonFile(filePath) {
  const raw = await fs.readFile(filePath, 'utf-8');
  return JSON.parse(raw);
}

async function expandCollectionTarget(slug, pageFilePath) {
  let pageConfig;
  try {
    pageConfig = await readJsonFile(pageFilePath);
  } catch {
    return [slug];
  }

  const binding = pageConfig?.collection;
  if (!binding || typeof binding.source !== 'string' || typeof binding.paramKey !== 'string') {
    return [slug];
  }

  const token = `[${binding.paramKey}]`;
  // Prefer authored route pattern (page.slug) when the file path is not parametric
  // (e.g. posts-detail.json with slug "blog/[slug]").
  const authoredSlug =
    typeof pageConfig.slug === 'string'
      ? pageConfig.slug.replace(/\\/g, '/').replace(/^\/+|\/+$/g, '')
      : '';
  const routePattern =
    authoredSlug.includes(token) ? authoredSlug : slug.includes(token) ? slug : '';
  if (!routePattern) return [slug];

  const collectionPath = path.resolve(collectionsDir, binding.source, `${binding.source}.json`);
  let collection;
  try {
    collection = await readJsonFile(collectionPath);
  } catch {
    return [slug];
  }

  if (!collection || typeof collection !== 'object' || Array.isArray(collection)) return [slug];
  const itemIds = Object.keys(collection).sort((a, b) => a.localeCompare(b));
  return itemIds.length > 0
    ? itemIds.map((itemId) => routePattern.replace(token, itemId))
    : [slug];
}

async function listJsonFilesRecursive(dir) {
  const items = await fs.readdir(dir, { withFileTypes: true });
  const files = [];
  for (const item of items) {
    const fullPath = path.join(dir, item.name);
    if (item.isDirectory()) {
      files.push(...(await listJsonFilesRecursive(fullPath)));
      continue;
    }
    if (item.isFile() && item.name.toLowerCase().endsWith('.json')) files.push(fullPath);
  }
  return files;
}

async function discoverTargets() {
  let files = [];
  try {
    files = await listJsonFilesRecursive(pagesDir);
  } catch {
    files = [];
  }

  const rawSlugs = (
    await Promise.all(
      files.map(async (fullPath) => {
        const slug = toCanonicalSlug(path.relative(pagesDir, fullPath));
        return expandCollectionTarget(slug, fullPath);
      })
    )
  ).flat();
  const slugs = Array.from(new Set(rawSlugs)).sort((a, b) => a.localeCompare(b));

  return slugs.map((slug) => {
    const depth = slug === 'home' ? 0 : slug.split('/').length;
    const out = slug === 'home' ? 'dist/index.html' : `dist/${slug}/index.html`;
    return { slug, out, depth };
  });
}

console.log('\n[bake] Building client...');
await build({ root, mode: 'production', logLevel: 'warn' });
console.log('[bake] Client build done.');

console.log('\n[bake] Building SSR bundle...');
await build({
  root,
  mode: 'production',
  logLevel: 'warn',
  build: {
    ssr: 'src/entry-ssg.tsx',
    outDir: 'dist-ssr',
    rollupOptions: {
      output: { format: 'esm' },
    },
  },
  ssr: {
    // SSG must be self-contained: the SSR artifact should not depend on
    // runtime resolution of app/framework packages at bake time.
    noExternal: true,
  },
});
console.log('[bake] SSR build done.');

const targets = await discoverTargets();
if (targets.length === 0) {
  throw new Error('[bake] No pages discovered under src/data/pages');
}
console.log(`[bake] Targets: ${targets.map((t) => t.slug).join(', ')}`);

const ssrEntryUrl = pathToFileURL(path.resolve(root, 'dist-ssr/entry-ssg.js')).href;
const { render, getCss, getRemoteStylesheets, getPageMeta, getWebMcpBuildState } = await import(ssrEntryUrl);

const template = await fs.readFile(path.resolve(root, 'dist/index.html'), 'utf-8');
const hasCommentMarker = template.includes('<!--app-html-->');
const hasRootDivMarker = template.includes('<div id="root"></div>');
if (!hasCommentMarker && !hasRootDivMarker) {
  throw new Error('[bake] Missing template marker. Expected <!--app-html--> or <div id="root"></div>.');
}

const inlinedCss = getCss();
const styleTag = `<style data-bake="inline">${inlinedCss}</style>`;
const remoteStylesheetTags = getRemoteStylesheets()
  .map((href) => `<link rel="stylesheet" href="${escapeHtmlAttribute(href)}">`)
  .join('\n  ');
const webMcpBuildState = getWebMcpBuildState();

for (const { slug } of targets) {
  const pageConfig = resolvePageMatchFromRegistry(webMcpBuildState.pages, slug)?.page;
  if (!pageConfig) continue;
  const resolvedPageDocument = resolvePublicPageDocument({
    slug,
    pages: webMcpBuildState.pages,
    siteConfig: webMcpBuildState.siteConfig,
    themeConfig: webMcpBuildState.themeConfig,
    menuConfig: webMcpBuildState.menuConfig,
    collections: webMcpBuildState.collections,
    collectionSchemas: webMcpBuildState.collectionSchemas,
    refDocuments: webMcpBuildState.refDocuments,
  });
  const publicPageConfig = resolvedPageDocument?.page ?? pageConfig;
  
  // Export the resolved public JSON data for the agentic web (so readResource matches runtime).
  await writeJsonTargets(`pages/${slug}.json`, publicPageConfig);

  const contract = buildPageContract({
    slug,
    pageConfig: publicPageConfig,
    schemas: webMcpBuildState.schemas,
    submissionSchemas: webMcpBuildState.submissionSchemas,
    siteConfig: webMcpBuildState.siteConfig,
  });
  await writeSsrJson(`schemas/${slug}.schema.json`, contract);
  const pageManifest = buildPageManifest({
    slug,
    pageConfig: publicPageConfig,
    schemas: webMcpBuildState.schemas,
    siteConfig: webMcpBuildState.siteConfig,
  });
  await writeJsonTargets(buildPageManifestHref(slug).replace(/^\//, ''), pageManifest);
}

// Export the site config for the agentic web
await writeJsonTargets('config/site.json', webMcpBuildState.siteConfig);

const mcpManifest = buildSiteManifest({
  pages: webMcpBuildState.pages,
  schemas: webMcpBuildState.schemas,
  siteConfig: webMcpBuildState.siteConfig,
});
await writeJsonTargets('mcp-manifest.json', mcpManifest);

const llmsTxtContent = buildLlmsTxt({
  pages: webMcpBuildState.pages,
  schemas: webMcpBuildState.schemas,
  siteConfig: webMcpBuildState.siteConfig,
});
await writeTargets('llms.txt', `${llmsTxtContent}\n`);

for (const { slug, out, depth } of targets) {
  console.log(`\n[bake] Rendering /${slug === 'home' ? '' : slug}...`);

  const appHtml = render(slug);
  const { title, description } = getPageMeta(slug);
  const safeTitle = String(title).replace(/"/g, '&quot;');
  const safeDescription = String(description).replace(/"/g, '&quot;');
  const metaTags = [
    `<meta name="description" content="${safeDescription}">`,
    `<meta property="og:title" content="${safeTitle}">`,
    `<meta property="og:description" content="${safeDescription}">`,
  ].join('\n    ');
  const jsonLd = JSON.stringify({
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    name: title,
    description,
    url: slug === 'home' ? '/' : `/${slug}`,
  });

  const prefix = depth > 0 ? '../'.repeat(depth) : './';
  const fixedTemplate = depth > 0 ? template.replace(/(['"])\.\//g, `$1${prefix}`) : template;
  const mcpManifestHref = `${prefix}${buildPageManifestHref(slug).replace(/^\//, '')}`;
  const contractHref = `${prefix}schemas/${slug}.schema.json`;
  const contractLinks = [
    `<link rel="mcp-manifest" href="${escapeHtmlAttribute(mcpManifestHref)}">`,
    `<link rel="olon-contract" href="${escapeHtmlAttribute(contractHref)}">`,
    `<script type="application/ld+json">${jsonLd}</script>`,
  ].join('\n  ');

  let bakedHtml = fixedTemplate
    .replace('</head>', `  ${remoteStylesheetTags ? `${remoteStylesheetTags}\n  ` : ''}${styleTag}\n  ${contractLinks}\n</head>`)
    .replace(/<title>.*?<\/title>/, `<title>${safeTitle}</title>\n    ${metaTags}`);

  if (hasCommentMarker) {
    bakedHtml = bakedHtml.replace('<!--app-html-->', appHtml);
  } else {
    bakedHtml = bakedHtml.replace('<div id="root"></div>', `<div id="root">${appHtml}</div>`);
  }

  const outPath = path.resolve(root, out);
  await fs.mkdir(path.dirname(outPath), { recursive: true });
  await fs.writeFile(outPath, bakedHtml, 'utf-8');
  console.log(`[bake] Written -> ${out} [title: "${safeTitle}"]`);
}

console.log('\n[bake] All pages baked. OK\n');
