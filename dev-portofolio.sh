#!/bin/bash
set -e

echo "=================================================="
echo "  Scaffolding Andrew Linh Portfolio & Blog Theme  "
echo "=================================================="

# -----------------------------------------------------------------------------
# 0. SHADCN/UI INIT
# -----------------------------------------------------------------------------
echo "-- Step 0: shadcn/ui init..."

npm install class-variance-authority clsx tailwind-merge lucide-react

npx shadcn@latest init --yes --style new-york --base-color slate 2>/dev/null || true

npx shadcn@latest add --yes --overwrite \
  button \
  card \
  badge \
  separator \
  avatar \
  table \
  tabs \
  accordion \
  dialog \
  sheet \
  tooltip \
  navigation-menu \
  dropdown-menu \
  hover-card \
  breadcrumb \
  skeleton \
  progress \
  input \
  label \
  textarea \
  select \
  checkbox \
  switch \
  toggle \
  toggle-group \
  scroll-area \
  aspect-ratio

echo "   shadcn/ui components installed"

mkdir -p \
  src/components/header \
  src/components/footer \
  src/components/editorial-hero \
  src/components/page-hero \
  src/components/featured-projects \
  src/components/blog-rollup \
  src/components/bio-panel \
  src/components/contact-cta \
  src/components/timeline \
  src/components/skills-grid \
  src/components/philosophy \
  src/components/contact-form \
  src/components/project-detail \
  src/components/post-detail \
  src/collections/projects \
  src/collections/posts \
  src/lib \
  src/data/config \
  src/data/pages \
  src/data/collections/projects \
  src/data/collections/posts

echo "-- Writing index.html..."
cat > index.html << 'EOF'
<!doctype html>
<html lang="en" data-theme="dark">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Andrew Linh — Systems Architect & Technical Writer</title>
    <meta
      name="description"
      content="Portfolio and editorial site of Andrew Linh, systems architect and technical writer focused on backend architecture, structured data systems, developer tooling, and AI-native infrastructure."
    />
    <meta name="theme-color" content="#0a0d0c" />
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF

echo "-- Writing src/index.css..."
cat > src/index.css << 'EOF'
@import url('');
@import "tailwindcss";
@source "./**/*.tsx";

@theme {
  --color-background:           var(--background);
  --color-foreground:           var(--foreground);
  --color-card:                 var(--card);
  --color-card-foreground:      var(--card-foreground);
  --color-primary:              var(--primary);
  --color-primary-foreground:   var(--primary-foreground);
  --color-secondary:            var(--secondary);
  --color-secondary-foreground: var(--secondary-foreground);
  --color-muted:                var(--muted);
  --color-muted-foreground:     var(--muted-foreground);
  --color-accent:               var(--accent);
  --color-border:               var(--border);
  --radius-lg:                  var(--theme-radius-lg);
  --radius-md:                  var(--theme-radius-md);
  --radius-sm:                  var(--theme-radius-sm);
  --font-primary: var(--theme-font-primary);
  --font-mono:    var(--theme-font-mono);
  --font-display: var(--theme-font-display);
}

:root {
  --background:           var(--theme-colors-background);
  --foreground:           var(--theme-colors-foreground);
  --card:                 var(--theme-colors-card);
  --card-foreground:      var(--theme-colors-card-foreground);
  --elevated:             var(--theme-colors-elevated);
  --overlay:              var(--theme-colors-overlay);
  --primary:              var(--theme-colors-primary);
  --primary-foreground:   var(--theme-colors-primary-foreground);
  --primary-light:        var(--theme-colors-primary-light);
  --primary-dark:         var(--theme-colors-primary-dark);
  --secondary:            var(--theme-colors-secondary);
  --secondary-foreground: var(--theme-colors-secondary-foreground);
  --muted:                var(--theme-colors-muted);
  --muted-foreground:     var(--theme-colors-muted-foreground);
  --accent:               var(--theme-colors-accent);
  --accent-foreground:    var(--theme-colors-accent-foreground);
  --border:               var(--theme-colors-border);
  --border-strong:        var(--theme-colors-border-strong);
  --input:                var(--theme-colors-input);
  --ring:                 var(--theme-colors-ring);
  --destructive:          var(--theme-colors-destructive);
  --destructive-foreground: var(--theme-colors-destructive-foreground);
  --success:              var(--theme-colors-success);
  --success-foreground:   var(--theme-colors-success-foreground);
  --warning:              var(--theme-colors-warning);
  --warning-foreground:   var(--theme-colors-warning-foreground);
  --info:                 var(--theme-colors-info);
  --info-foreground:      var(--theme-colors-info-foreground);
  --radius:               var(--theme-radius-lg);

  --demo-surface:         color-mix(in oklch, var(--card) 86%, var(--background));
  --demo-surface-soft:    color-mix(in oklch, var(--card) 72%, var(--background));
  --demo-surface-strong:  color-mix(in oklch, var(--background) 82%, black);
  --demo-surface-deep:    color-mix(in oklch, var(--background) 70%, black);
  --demo-border-soft:     color-mix(in oklch, var(--foreground) 8%, transparent);
  --demo-border-strong:   color-mix(in oklch, var(--primary) 24%, transparent);
  --demo-accent-soft:     color-mix(in oklch, var(--primary) 10%, transparent);
  --demo-accent-strong:   color-mix(in oklch, var(--primary) 18%, transparent);
  --demo-text-soft:       color-mix(in oklch, var(--foreground) 88%, var(--muted-foreground));
  --demo-text-faint:      color-mix(in oklch, var(--muted-foreground) 72%, transparent);
}

[data-theme="light"] {
  --background:           var(--theme-modes-light-colors-background);
  --foreground:           var(--theme-modes-light-colors-foreground);
  --card:                 var(--theme-modes-light-colors-card);
  --card-foreground:      var(--theme-modes-light-colors-card-foreground);
  --elevated:             var(--theme-modes-light-colors-elevated);
  --overlay:              var(--theme-modes-light-colors-overlay);
  --primary:              var(--theme-modes-light-colors-primary);
  --primary-foreground:   var(--theme-modes-light-colors-primary-foreground);
  --primary-light:        var(--theme-modes-light-colors-primary-light);
  --primary-dark:         var(--theme-modes-light-colors-primary-dark);
  --secondary:            var(--theme-modes-light-colors-secondary);
  --secondary-foreground: var(--theme-modes-light-colors-secondary-foreground);
  --muted:                var(--theme-modes-light-colors-muted);
  --muted-foreground:     var(--theme-modes-light-colors-muted-foreground);
  --accent:               var(--theme-modes-light-colors-accent);
  --accent-foreground:    var(--theme-modes-light-colors-accent-foreground);
  --border:               var(--theme-modes-light-colors-border);
  --border-strong:        var(--theme-modes-light-colors-border-strong);
  --input:                var(--theme-modes-light-colors-input);
  --ring:                 var(--theme-modes-light-colors-ring);
  --destructive:          var(--theme-modes-light-colors-destructive);
  --destructive-foreground: var(--theme-modes-light-colors-destructive-foreground);
  --success:              var(--theme-modes-light-colors-success);
  --success-foreground:   var(--theme-modes-light-colors-success-foreground);
  --warning:              var(--theme-modes-light-colors-warning);
  --warning-foreground:   var(--theme-modes-light-colors-warning-foreground);
  --info:                 var(--theme-modes-light-colors-info);
  --info-foreground:      var(--theme-modes-light-colors-info-foreground);
}

@layer base {
  * { border-color: var(--border); }
  html { scroll-behavior: smooth; }
  body {
    background-color: var(--background);
    color: var(--foreground);
    font-family: var(--font-primary);
    line-height: 1.7;
    overflow-x: hidden;
    @apply antialiased;
  }
  h1, h2, h3, h4, h5, h6 {
    font-family: var(--font-display, var(--font-primary));
    letter-spacing: -0.02em;
  }
  code, pre, kbd, samp {
    font-family: var(--font-mono);
  }
}

.font-display {
  font-family: var(--font-display, var(--font-primary));
}

.font-primary {
  font-family: var(--font-primary);
}

.font-mono {
  font-family: var(--font-mono);
}

.prose-terminal {
  color: var(--foreground);
}

.prose-terminal p {
  color: var(--demo-text-soft);
}

.prose-terminal strong {
  color: var(--foreground);
}

.prose-terminal a {
  color: var(--primary);
  text-decoration: underline;
  text-decoration-color: color-mix(in oklch, var(--primary) 40%, transparent);
  text-underline-offset: 0.2em;
}

.prose-terminal code {
  background: var(--demo-surface);
  border: 1px solid var(--demo-border-soft);
  border-radius: var(--theme-radius-sm);
  padding: 0.12rem 0.35rem;
}

.jp-chip {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  border: 1px solid var(--demo-border-soft);
  background: color-mix(in oklch, var(--card) 76%, transparent);
  border-radius: 9999px;
  padding: 0.45rem 0.85rem;
  font-family: var(--font-mono);
  font-size: 0.72rem;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--muted-foreground);
}

.jp-meta {
  font-family: var(--font-mono);
  font-size: 0.74rem;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--muted-foreground);
}

@keyframes jp-fadeUp {
  from { opacity: 0; transform: translateY(20px); }
  to   { opacity: 1; transform: translateY(0); }
}
.jp-animate-in { opacity: 0; animation: jp-fadeUp 0.7s ease forwards; }
.jp-d1 { animation-delay: 0.1s; }
.jp-d2 { animation-delay: 0.2s; }
.jp-d3 { animation-delay: 0.3s; }
.jp-d4 { animation-delay: 0.4s; }

@keyframes jp-pulseDot {
  0%, 100% { opacity: 1; transform: scale(1); }
  50% { opacity: 0.5; transform: scale(0.85); }
}
.jp-pulse-dot { animation: jp-pulseDot 2s ease infinite; }

[data-jp-section-overlay] {
  position: absolute; inset: 0; z-index: 9999;
  pointer-events: none; border: 2px solid transparent;
  transition: border-color 0.15s, background-color 0.15s;
}
[data-section-id]:hover [data-jp-section-overlay] {
  border: 2px dashed color-mix(in oklch, var(--primary) 50%, transparent);
  background-color: color-mix(in oklch, var(--primary) 6%, transparent);
}
[data-section-id][data-jp-selected] [data-jp-section-overlay] {
  border: 2px solid var(--primary);
  background-color: color-mix(in oklch, var(--primary) 10%, transparent);
}
[data-jp-section-overlay] > div {
  position: absolute; top: 0; right: 0;
  padding: 0.2rem 0.55rem;
  font-size: 9px; font-weight: 800;
  text-transform: uppercase; letter-spacing: 0.1em;
  background: var(--primary); color: #fff;
  opacity: 0; transition: opacity 0.15s;
}
[data-section-id]:hover [data-jp-section-overlay] > div,
[data-section-id][data-jp-selected] [data-jp-section-overlay] > div { opacity: 1; }
EOF

echo "-- Writing src/data/config/theme.json..."
cat > src/data/config/theme.json << 'EOF'
{
  "name": "Andrew Linh",
  "tokens": {
    "colors": {
      "background": "#0a0d0c",
      "foreground": "#eef2ef",
      "card": "#111514",
      "card-foreground": "#eef2ef",
      "elevated": "#171c1a",
      "overlay": "#0d110fff",
      "primary": "#5dd39e",
      "primary-foreground": "#07100b",
      "primary-light": "#8be6ba",
      "primary-dark": "#2e8f64",
      "accent": "#7ce3b0",
      "accent-foreground": "#07100b",
      "secondary": "#151a18",
      "secondary-foreground": "#d5ddd8",
      "muted": "#101413",
      "muted-foreground": "#95a29a",
      "border": "#202826",
      "border-strong": "#31403b",
      "input": "#151a18",
      "ring": "#5dd39e",
      "destructive": "#b84f5f",
      "destructive-foreground": "#fff3f5",
      "success": "#4bc289",
      "success-foreground": "#06110b",
      "warning": "#c9a35c",
      "warning-foreground": "#171108",
      "info": "#62b8a2",
      "info-foreground": "#06110d"
    },
    "typography": {
      "fontFamily": {
        "primary": "\"Instrument Sans\", ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif",
        "mono": "\"SFMono-Regular\", \"SF Mono\", Consolas, \"Liberation Mono\", Menlo, monospace",
        "display": "\"Instrument Serif\", ui-serif, Georgia, Cambria, \"Times New Roman\", Times, serif"
      },
      "wordmark": {
        "fontFamily": "\"Instrument Sans\", ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif",
        "weight": "600"
      }
    },
    "borderRadius": {
      "sm": "6px",
      "md": "10px",
      "lg": "14px",
      "xl": "18px",
      "full": "9999px"
    },
    "spacing": {
      "container-max": "1152px",
      "section-y": "104px",
      "header-h": "64px",
      "sidebar-w": "240px"
    },
    "zIndex": {
      "base": "0",
      "elevated": "10",
      "dropdown": "100",
      "sticky": "200",
      "overlay": "300",
      "modal": "400",
      "toast": "500"
    },
    "modes": {
      "light": {
        "colors": {
          "background": "#f7f8f7",
          "foreground": "#111614",
          "card": "#ffffff",
          "card-foreground": "#111614",
          "elevated": "#eef1ef",
          "overlay": "#f5f7f6ee",
          "primary": "#267a53",
          "primary-foreground": "#f7fff9",
          "primary-light": "#5cb98a",
          "primary-dark": "#1d6041",
          "accent": "#2f8d60",
          "accent-foreground": "#f7fff9",
          "secondary": "#eef1ef",
          "secondary-foreground": "#1b221f",
          "muted": "#f0f3f1",
          "muted-foreground": "#5b6861",
          "border": "#d9e1dd",
          "border-strong": "#bcc8c2",
          "input": "#ffffff",
          "ring": "#267a53",
          "destructive": "#b84f5f",
          "destructive-foreground": "#fff7f8",
          "success": "#2b8e61",
          "success-foreground": "#f6fffa",
          "warning": "#a7792a",
          "warning-foreground": "#fff8ec",
          "info": "#2f7e70",
          "info-foreground": "#f5fffd"
        }
      }
    }
  }
}
EOF

echo "-- Writing capsule: header..."
cat > src/components/header/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';

const HeaderMenuItemSchema = z.object({
  id: z.string().optional(),
  label: z.string().describe('ui:text'),
  href: z.string().describe('ui:text'),
  isCta: z.boolean().optional().describe('ui:checkbox')
});

export const HeaderSchema = BaseSectionData.extend({
  announcement: z.string().optional().describe('ui:text'),
  logoText: z.string().describe('ui:text'),
  logoHighlight: z.string().optional().describe('ui:text'),
  menu: z.array(HeaderMenuItemSchema).optional().describe('ui:list')
});
EOF

cat > src/components/header/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { HeaderSchema } from './schema';

export type HeaderData = z.infer<typeof HeaderSchema>;
export type HeaderSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/header/View.tsx << 'EOF'
// Layout: Hero=F (MINIMAL HERO), Features=B (HORIZONTAL SCROLL)
import React from 'react';
import { Button } from '@/components/ui/button';
import {
  NavigationMenu,
  NavigationMenuItem,
  NavigationMenuLink,
  NavigationMenuList
} from '@/components/ui/navigation-menu';
import { Sheet, SheetClose, SheetContent, SheetHeader, SheetTitle, SheetTrigger } from '@/components/ui/sheet';
import { Menu, Moon, Sun } from 'lucide-react';
import { useTheme } from '@/components/ThemeProvider';
import type { HeaderData, HeaderSettings } from './types';

export const Header: React.FC<{ data: HeaderData; settings: HeaderSettings }> = ({ data }) => {
  const navItems = Array.isArray(data.menu) ? data.menu : [];
  const { theme, toggleTheme } = useTheme();

  return (
    <header
      style={{
        '--local-bg': 'color-mix(in oklch, var(--background) 94%, transparent)',
        '--local-text': 'var(--foreground)',
        '--local-border': 'var(--border)',
        '--local-surface': 'color-mix(in oklch, var(--card) 90%, transparent)',
        '--local-primary': 'var(--primary)',
        '--local-primary-foreground': 'var(--primary-foreground)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)'
      } as React.CSSProperties}
      className="sticky top-0 z-10 border-b border-[var(--local-border)] bg-[var(--local-bg)]/95 backdrop-blur-xl"
    >
      <div className="max-w-[1200px] mx-auto px-8">
        {data.announcement && (
          <div className="py-3 text-center jp-meta" data-jp-field="announcement">
            {data.announcement}
          </div>
        )}
        <div className="flex h-20 items-center justify-between gap-6">
          <a href="/" className="flex items-baseline gap-2">
            <span
              className="text-[1.05rem] font-semibold tracking-[-0.02em] text-[var(--local-text)]"
              style={{ fontFamily: 'var(--theme-wordmark-font-family, var(--font-primary))', fontWeight: '600' }}
              data-jp-field="logoText"
            >
              {data.logoText}
            </span>
            {data.logoHighlight && (
              <span className="jp-meta text-[var(--local-primary)]" data-jp-field="logoHighlight">
                {data.logoHighlight}
              </span>
            )}
          </a>

          <div className="hidden items-center gap-4 lg:flex">
            <NavigationMenu>
              <NavigationMenuList className="gap-1">
                {navItems.map((item, idx) => (
                  <NavigationMenuItem
                    key={item.id || item.href + '-' + idx}
                    data-jp-item-id={item.id || 'menu-' + idx}
                    data-jp-item-field="menu"
                  >
                    <NavigationMenuLink
                      href={item.href}
                      className={
                        item.isCta
                          ? 'inline-flex rounded-[var(--local-radius-md)] border border-[var(--local-border)] bg-[var(--local-surface)] px-4 py-2 text-sm font-medium text-[var(--local-text)] transition hover:border-[var(--local-primary)]'
                          : 'inline-flex rounded-[var(--local-radius-md)] px-4 py-2 text-sm font-medium text-[var(--local-text)] transition hover:bg-[var(--local-surface)]'
                      }
                    >
                      {item.label}
                    </NavigationMenuLink>
                  </NavigationMenuItem>
                ))}
              </NavigationMenuList>
            </NavigationMenu>
            <Button
              type="button"
              variant="outline"
              onClick={toggleTheme}
              className="rounded-[var(--local-radius-md)] border-[var(--local-border)] bg-[var(--local-surface)] text-[var(--local-text)]"
            >
              {theme === 'dark' ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
            </Button>
          </div>

          <div className="flex items-center gap-3 lg:hidden">
            <Button
              type="button"
              variant="outline"
              onClick={toggleTheme}
              className="rounded-[var(--local-radius-md)] border-[var(--local-border)] bg-[var(--local-surface)] text-[var(--local-text)]"
            >
              {theme === 'dark' ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
            </Button>
            <Sheet>
              <SheetTrigger asChild>
                <Button variant="outline" className="rounded-[var(--local-radius-md)] border-[var(--local-border)] bg-[var(--local-surface)] text-[var(--local-text)]">
                  <Menu className="h-4 w-4" />
                </Button>
              </SheetTrigger>
              <SheetContent className="flex flex-col gap-0 bg-card text-foreground">
                <SheetHeader className="border-b border-border px-6 py-5">
                  <SheetTitle className="font-display text-lg text-foreground">{data.logoText || 'Menu'}</SheetTitle>
                </SheetHeader>
                <nav className="flex flex-1 flex-col divide-y divide-border overflow-y-auto">
                  {navItems.map((item, idx) => (
                    <SheetClose asChild key={item.id || item.href + '-mobile-' + idx}>
                      <a
                        href={item.href}
                        className="flex items-center px-6 py-4 text-base font-medium text-foreground transition hover:bg-muted active:bg-muted"
                      >
                        {item.label}
                      </a>
                    </SheetClose>
                  ))}
                </nav>
              </SheetContent>
            </Sheet>
          </div>
        </div>
      </div>
    </header>
  );
};
EOF

cat > src/components/header/index.ts << 'EOF'
export { Header } from './View';
export { HeaderSchema } from './schema';
export type { HeaderData, HeaderSettings } from './types';
EOF

echo "-- Writing capsule: footer..."
cat > src/components/footer/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';

const FooterMenuItemSchema = z.object({
  id: z.string().optional(),
  label: z.string().describe('ui:text'),
  href: z.string().describe('ui:text'),
  icon: z.string().optional().describe('ui:icon-picker')
});

export const FooterSchema = BaseSectionData.extend({
  brandText: z.string().describe('ui:text'),
  brandHighlight: z.string().optional().describe('ui:text'),
  summary: z.string().optional().describe('ui:textarea'),
  email: z.string().optional().describe('ui:text'),
  copyright: z.string().describe('ui:text'),
  menu: z.array(FooterMenuItemSchema).optional().describe('ui:list')
});
EOF

cat > src/components/footer/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { FooterSchema } from './schema';

export type FooterData = z.infer<typeof FooterSchema>;
export type FooterSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/footer/View.tsx << 'EOF'
// Layout: Hero=F (MINIMAL HERO), Features=B (HORIZONTAL SCROLL)
import React from 'react';
import { Separator } from '@/components/ui/separator';
import { IconResolver } from '@/lib/IconResolver';
import type { FooterData, FooterSettings } from './types';

export const Footer: React.FC<{ data: FooterData; settings: FooterSettings }> = ({ data }) => {
  const navItems = Array.isArray(data.menu) ? data.menu : [];

  return (
    <footer
      style={{
        '--local-bg': 'var(--background)',
        '--local-text': 'var(--foreground)',
        '--local-text-muted': 'var(--muted-foreground)',
        '--local-border': 'var(--border)',
        '--local-primary': 'var(--primary)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)'
      } as React.CSSProperties}
      className="relative z-0 border-t bg-[var(--local-bg)] py-20"
    >
      <div className="max-w-[1200px] mx-auto px-8">
        <div className="grid gap-10 lg:grid-cols-[1.2fr_0.8fr]">
          <div className="space-y-5">
            <div className="flex items-baseline gap-2">
              <span
                className="text-xl font-semibold tracking-[-0.02em] text-[var(--local-text)]"
                style={{ fontFamily: 'var(--theme-wordmark-font-family, var(--font-primary))', fontWeight: '600' }}
                data-jp-field="brandText"
              >
                {data.brandText}
              </span>
              {data.brandHighlight && (
                <span className="jp-meta text-[var(--local-primary)]" data-jp-field="brandHighlight">
                  {data.brandHighlight}
                </span>
              )}
            </div>
            {data.summary && (
              <p className="max-w-xl text-sm text-[var(--local-text-muted)]" data-jp-field="summary">
                {data.summary}
              </p>
            )}
            {data.email && (
              <a href={'mailto:' + data.email} className="jp-meta text-[var(--local-text)]" data-jp-field="email">
                {data.email}
              </a>
            )}
          </div>

          <div className="grid gap-6 sm:grid-cols-2">
            <div>
              <h3 className="mb-4 font-display text-lg text-[var(--local-text)]">Links</h3>
              <div className="space-y-3">
                {navItems.map((item, idx) => {
                  const Icon = item.icon ? IconResolver[item.icon] : null;
                  return (
                    <a
                      key={item.id || item.href + '-' + idx}
                      href={item.href}
                      className="flex items-center gap-3 text-sm text-[var(--local-text-muted)] transition hover:text-[var(--local-text)]"
                      data-jp-item-id={item.id || 'menu-' + idx}
                      data-jp-item-field="menu"
                    >
                      {Icon ? <Icon className="h-4 w-4 text-[var(--local-primary)]" /> : null}
                      <span>{item.label}</span>
                    </a>
                  );
                })}
              </div>
            </div>
            <div>
              <h3 className="mb-4 font-display text-lg text-[var(--local-text)]">Elsewhere</h3>
              <p className="text-sm text-[var(--local-text-muted)]">
                Available for architecture consulting, writing commissions, and internal developer platform reviews.
              </p>
            </div>
          </div>
        </div>
        <Separator className="my-8 bg-border" />
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <p className="jp-meta" data-jp-field="copyright">{data.copyright}</p>
          <p className="jp-meta">Built for precise systems thinking.</p>
        </div>
      </div>
    </footer>
  );
};
EOF

cat > src/components/footer/index.ts << 'EOF'
export { Footer } from './View';
export { FooterSchema } from './schema';
export type { FooterData, FooterSettings } from './types';
EOF

echo "-- Writing capsule: editorial-hero..."
cat > src/components/editorial-hero/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData, CtaSchema } from '@olonjs/core';

export const EditorialHeroSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  titleHighlight: z.string().optional().describe('ui:text'),
  description: z.string().describe('ui:textarea'),
  primaryCta: CtaSchema.optional(),
  secondaryCta: CtaSchema.optional(),
  status: z.string().optional().describe('ui:text')
});
EOF

cat > src/components/editorial-hero/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { EditorialHeroSchema } from './schema';

export type EditorialHeroData = z.infer<typeof EditorialHeroSchema>;
export type EditorialHeroSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/editorial-hero/View.tsx << 'EOF'
// Layout: Hero=F (MINIMAL HERO), Features=A (BENTO)
import React from 'react';
import { Button } from '@/components/ui/button';
import type { EditorialHeroData, EditorialHeroSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40'
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40'
};

export const EditorialHero: React.FC<{ data: EditorialHeroData; settings: EditorialHeroSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'xl'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'xl'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      bg: 'var(--theme-colors-background)',
      text: 'var(--theme-colors-foreground)',
      muted: 'var(--theme-colors-muted-foreground)',
      surface: 'var(--theme-colors-card)',
      border: 'var(--theme-colors-border)'
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)'
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)'
    }
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-primary-foreground': 'var(--primary-foreground)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-sm': 'var(--theme-radius-sm)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)'
      } as React.CSSProperties}
      className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}
    >
      <div className={containerClass}>
        <div className="max-w-4xl space-y-8">
          {data.label && (
            <div className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4" data-jp-field="label">
              <span className="w-5 h-px bg-[var(--local-primary)]" />
              {data.label}
            </div>
          )}
          {data.status && (
            <div className="jp-chip" data-jp-field="status">
              <span className="w-1.5 h-1.5 rounded-full bg-[var(--local-primary)] jp-pulse-dot" />
              {data.status}
            </div>
          )}
          <h1 className="font-display font-black text-[clamp(3rem,6vw,5.5rem)] leading-[1.0] tracking-tight text-[var(--local-text)]" data-jp-field="title">
            {data.title}{' '}
            {data.titleHighlight && (
              <em className="not-italic text-[var(--local-primary)]" data-jp-field="titleHighlight">
                {data.titleHighlight}
              </em>
            )}
          </h1>
          <p className="max-w-2xl text-[1.05rem] text-[var(--local-text-muted)]" data-jp-field="description">
            {data.description}
          </p>
          <div className="flex flex-wrap gap-4">
            {data.primaryCta && (
              <Button
                asChild
                variant="default"
                className="rounded-[var(--local-radius-md)] bg-[var(--local-primary)] text-[var(--local-primary-foreground)]"
              >
                <a href={data.primaryCta.href}>{data.primaryCta.label}</a>
              </Button>
            )}
            {data.secondaryCta && (
              <Button
                asChild
                variant="outline"
                className="rounded-[var(--local-radius-md)] border-[var(--local-border)] bg-transparent text-[var(--local-text)]"
              >
                <a href={data.secondaryCta.href}>{data.secondaryCta.label}</a>
              </Button>
            )}
          </div>
        </div>
      </div>
    </section>
  );
};
EOF

cat > src/components/editorial-hero/index.ts << 'EOF'
export { EditorialHero } from './View';
export { EditorialHeroSchema } from './schema';
export type { EditorialHeroData, EditorialHeroSettings } from './types';
EOF

echo "-- Writing capsule: page-hero..."
cat > src/components/page-hero/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';

export const PageHeroSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().describe('ui:textarea')
});
EOF

cat > src/components/page-hero/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { PageHeroSchema } from './schema';

export type PageHeroData = z.infer<typeof PageHeroSchema>;
export type PageHeroSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/page-hero/View.tsx << 'EOF'
// Layout: Hero=E (MAGAZINE), Features=A (BENTO)
import React from 'react';
import type { PageHeroData, PageHeroSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40'
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40'
};

export const PageHero: React.FC<{ data: PageHeroData; settings: PageHeroSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'lg'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'lg'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      bg: 'var(--theme-colors-background)',
      text: 'var(--theme-colors-foreground)',
      muted: 'var(--theme-colors-muted-foreground)',
      surface: 'var(--theme-colors-card)',
      border: 'var(--theme-colors-border)'
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)'
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)'
    }
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-sm': 'var(--theme-radius-sm)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)'
      } as React.CSSProperties}
      className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}
    >
      <div className={containerClass}>
        <div className="grid gap-8 lg:grid-cols-[1.15fr_0.85fr] lg:items-end">
          <div className="space-y-5">
            {data.label && (
              <div className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4" data-jp-field="label">
                <span className="w-5 h-px bg-[var(--local-primary)]" />
                {data.label}
              </div>
            )}
            <h1 className="font-display font-black text-[clamp(2.7rem,5vw,4.8rem)] leading-[1.02] tracking-tight text-[var(--local-text)]" data-jp-field="title">
              {data.title}
            </h1>
          </div>
          <p className="max-w-xl text-[1rem] text-[var(--local-text-muted)] lg:justify-self-end" data-jp-field="description">
            {data.description}
          </p>
        </div>
      </div>
    </section>
  );
};
EOF

cat > src/components/page-hero/index.ts << 'EOF'
export { PageHero } from './View';
export { PageHeroSchema } from './schema';
export type { PageHeroData, PageHeroSettings } from './types';
EOF

echo "-- Writing capsule: featured-projects..."
cat > src/components/featured-projects/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { ProjectSchema } from '@/collections/projects';

export const FeaturedProjectsSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  items: z.record(z.string(), ProjectSchema).describe('ui:collection-ref')
});
EOF

cat > src/components/featured-projects/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { FeaturedProjectsSchema } from './schema';

export type FeaturedProjectsData = z.infer<typeof FeaturedProjectsSchema>;
export type FeaturedProjectsSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/featured-projects/View.tsx << 'EOF'
// Layout: Hero=B (BENTO GRID), Features=A (BENTO)
import React from 'react';
import { Card, CardContent } from '@/components/ui/card';
import type { FeaturedProjectsData, FeaturedProjectsSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40'
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40'
};

export const FeaturedProjects: React.FC<{ data: FeaturedProjectsData; settings: FeaturedProjectsSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      bg: 'var(--theme-colors-background)',
      text: 'var(--theme-colors-foreground)',
      muted: 'var(--theme-colors-muted-foreground)',
      surface: 'var(--theme-colors-card)',
      border: 'var(--theme-colors-border)'
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)'
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)'
    }
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;
  const projects = Object.values(data.items || {}).slice(0, 4);

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-sm': 'var(--theme-radius-sm)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)'
      } as React.CSSProperties}
      className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}
    >
      <div className={containerClass}>
        <div className="mb-10 flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <div className="max-w-2xl">
            {data.label && (
              <div className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4" data-jp-field="label">
                <span className="w-5 h-px bg-[var(--local-primary)]" />
                {data.label}
              </div>
            )}
            <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">
              {data.title}
            </h2>
          </div>
          {data.description && (
            <p className="max-w-xl text-sm text-[var(--local-text-muted)]" data-jp-field="description">
              {data.description}
            </p>
          )}
        </div>

        <div className="grid gap-6 md:grid-cols-2">
          {projects.map((item, idx) => (
            <Card
              key={item.id || 'legacy-' + idx}
              className={(idx === 0 ? 'md:col-span-2 ' : '') + 'rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] text-[var(--local-text)]'}
              data-jp-item-id={item.id || 'legacy-' + idx}
              data-jp-item-field="items"
            >
              <CardContent className="space-y-5 p-7">
                <div className="flex flex-wrap gap-2">
                  <span className="jp-chip">{item.year}</span>
                  <span className="jp-chip">{item.category}</span>
                </div>
                <div className="space-y-3">
                  <h3 className="font-display font-bold text-[1.35rem] leading-tight tracking-tight text-[var(--local-text)]">
                    {item.title}
                  </h3>
                  <p className="text-sm text-[var(--local-text-muted)]">{item.summary}</p>
                </div>
                <div className="grid gap-4 sm:grid-cols-3">
                  <div>
                    <div className="jp-meta">Problem</div>
                    <p className="mt-2 text-sm text-[var(--local-text)]">{item.problem}</p>
                  </div>
                  <div>
                    <div className="jp-meta">Architecture</div>
                    <p className="mt-2 text-sm text-[var(--local-text)]">{item.architecture}</p>
                  </div>
                  <div>
                    <div className="jp-meta">Outcome</div>
                    <p className="mt-2 text-sm text-[var(--local-text)]">{item.result}</p>
                  </div>
                </div>
                <a href={'/work/' + item.slug} className="inline-flex text-sm font-medium text-[var(--local-primary)]">
                  Read case study
                </a>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </section>
  );
};
EOF

cat > src/components/featured-projects/index.ts << 'EOF'
export { FeaturedProjects } from './View';
export { FeaturedProjectsSchema } from './schema';
export type { FeaturedProjectsData, FeaturedProjectsSettings } from './types';
EOF

echo "-- Writing capsule: blog-rollup..."
cat > src/components/blog-rollup/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core';
import { PostSchema } from '@/collections/posts';

export const BlogRollupSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  items: z.record(z.string(), PostSchema).describe('ui:collection-ref')
});
EOF

cat > src/components/blog-rollup/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { BlogRollupSchema } from './schema';

export type BlogRollupData = z.infer<typeof BlogRollupSchema>;
export type BlogRollupSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/blog-rollup/View.tsx << 'EOF'
// Layout: Hero=E (MAGAZINE), Features=B (HORIZONTAL SCROLL)
import React from 'react';
import { Card, CardContent } from '@/components/ui/card';
import type { BlogRollupData, BlogRollupSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40'
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40'
};

export const BlogRollup: React.FC<{ data: BlogRollupData; settings: BlogRollupSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      bg: 'var(--theme-colors-background)',
      text: 'var(--theme-colors-foreground)',
      muted: 'var(--theme-colors-muted-foreground)',
      surface: 'var(--theme-colors-card)',
      border: 'var(--theme-colors-border)'
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)'
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)'
    }
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;
  const posts = Object.values(data.items || {});

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-sm': 'var(--theme-radius-sm)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)'
      } as React.CSSProperties}
      className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}
    >
      <div className={containerClass}>
        <div className="mb-10 flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <div className="max-w-2xl">
            {data.label && (
              <div className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4" data-jp-field="label">
                <span className="w-5 h-px bg-[var(--local-primary)]" />
                {data.label}
              </div>
            )}
            <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">
              {data.title}
            </h2>
          </div>
          {data.description && (
            <p className="max-w-xl text-sm text-[var(--local-text-muted)]" data-jp-field="description">
              {data.description}
            </p>
          )}
        </div>

        <div className="grid gap-6 lg:grid-cols-3">
          {posts.map((item, idx) => (
            <Card
              key={item.id || 'legacy-' + idx}
              className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] text-[var(--local-text)]"
              data-jp-item-id={item.id || 'legacy-' + idx}
              data-jp-item-field="items"
            >
              <CardContent className="space-y-4 p-6">
                <div className="flex flex-wrap gap-2">
                  <span className="jp-meta">{item.date}</span>
                  <span className="jp-meta">{item.readingTime}</span>
                </div>
                <h3 className="font-display font-bold text-[1.2rem] leading-tight tracking-tight text-[var(--local-text)]">
                  {item.title}
                </h3>
                <p className="text-sm text-[var(--local-text-muted)]">{item.dek}</p>
                <div className="flex flex-wrap gap-2">
                  {item.tags.map((tag, tagIdx) => (
                    <span key={tag + '-' + tagIdx} className="jp-chip">{tag}</span>
                  ))}
                </div>
                <a href={'/blog/' + item.slug} className="inline-flex text-sm font-medium text-[var(--local-primary)]">
                  Read article
                </a>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </section>
  );
};
EOF

cat > src/components/blog-rollup/index.ts << 'EOF'
export { BlogRollup } from './View';
export { BlogRollupSchema } from './schema';
export type { BlogRollupData, BlogRollupSettings } from './types';
EOF

echo "-- Writing capsule: bio-panel..."
cat > src/components/bio-panel/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData, ImageSelectionSchema } from '@olonjs/core';

export const BioPanelSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().describe('ui:textarea'),
  image: ImageSelectionSchema.optional(),
  note: z.string().optional().describe('ui:textarea')
});
EOF

cat > src/components/bio-panel/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { BioPanelSchema } from './schema';

export type BioPanelData = z.infer<typeof BioPanelSchema>;
export type BioPanelSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/bio-panel/View.tsx << 'EOF'
// Layout: Hero=A (SPLIT 60/40), Features=A (BENTO)
import React from 'react';
import { AspectRatio } from '@/components/ui/aspect-ratio';
import type { BioPanelData, BioPanelSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40'
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40'
};

export const BioPanel: React.FC<{ data: BioPanelData; settings: BioPanelSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      bg: 'var(--theme-colors-background)',
      text: 'var(--theme-colors-foreground)',
      muted: 'var(--theme-colors-muted-foreground)',
      surface: 'var(--theme-colors-card)',
      border: 'var(--theme-colors-border)'
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)'
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)'
    }
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-sm': 'var(--theme-radius-sm)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)'
      } as React.CSSProperties}
      className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}
    >
      <div className={containerClass}>
        <div className="grid gap-8 lg:grid-cols-[0.85fr_1.15fr] lg:items-center">
          <div className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-3">
            <AspectRatio ratio={4 / 5}>
              {data.image?.url ? (
                <img
                  src={data.image?.url}
                  alt={data.image?.alt}
                  className="h-full w-full rounded-[var(--local-radius-md)] object-cover"
                />
              ) : null}
            </AspectRatio>
          </div>
          <div className="space-y-5">
            {data.label && (
              <div className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4" data-jp-field="label">
                <span className="w-5 h-px bg-[var(--local-primary)]" />
                {data.label}
              </div>
            )}
            <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">
              {data.title}
            </h2>
            <p className="text-[1rem] text-[var(--local-text-muted)]" data-jp-field="description">
              {data.description}
            </p>
            {data.note && (
              <p className="jp-meta max-w-xl text-[var(--local-primary)]" data-jp-field="note">
                {data.note}
              </p>
            )}
          </div>
        </div>
      </div>
    </section>
  );
};
EOF

cat > src/components/bio-panel/index.ts << 'EOF'
export { BioPanel } from './View';
export { BioPanelSchema } from './schema';
export type { BioPanelData, BioPanelSettings } from './types';
EOF

echo "-- Writing capsule: contact-cta..."
cat > src/components/contact-cta/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData, CtaSchema } from '@olonjs/core';

export const ContactCtaSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().describe('ui:textarea'),
  primaryCta: CtaSchema.optional(),
  secondaryCta: CtaSchema.optional()
});
EOF

cat > src/components/contact-cta/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { ContactCtaSchema } from './schema';

export type ContactCtaData = z.infer<typeof ContactCtaSchema>;
export type ContactCtaSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/contact-cta/View.tsx << 'EOF'
// Layout: Hero=F (MINIMAL HERO), Features=A (BENTO)
import React from 'react';
import { Button } from '@/components/ui/button';
import type { ContactCtaData, ContactCtaSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40'
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40'
};

export const ContactCta: React.FC<{ data: ContactCtaData; settings: ContactCtaSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'lg'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'lg'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const sectionTheme = settings?.theme ?? 'accent';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      bg: 'var(--theme-colors-background)',
      text: 'var(--theme-colors-foreground)',
      muted: 'var(--theme-colors-muted-foreground)',
      surface: 'var(--theme-colors-card)',
      border: 'var(--theme-colors-border)'
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)'
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)'
    }
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.accent;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-primary-foreground': 'var(--primary-foreground)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-sm': 'var(--theme-radius-sm)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)'
      } as React.CSSProperties}
      className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}
    >
      <div className={containerClass}>
        <div className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-bg)] px-8 py-10">
          {data.label && (
            <div className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-text)] mb-4" data-jp-field="label">
              <span className="w-5 h-px bg-[var(--local-text)]" />
              {data.label}
            </div>
          )}
          <div className="grid gap-6 lg:grid-cols-[1fr_auto] lg:items-end">
            <div className="space-y-4">
              <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">
                {data.title}
              </h2>
              <p className="max-w-2xl text-[var(--local-text-muted)]" data-jp-field="description">
                {data.description}
              </p>
            </div>
            <div className="flex flex-wrap gap-4">
              {data.primaryCta && (
                <Button asChild variant="default" className="rounded-[var(--local-radius-md)] bg-[var(--local-text)] text-[var(--local-bg)]">
                  <a href={data.primaryCta.href}>{data.primaryCta.label}</a>
                </Button>
              )}
              {data.secondaryCta && (
                <Button asChild variant="outline" className="rounded-[var(--local-radius-md)] border-[var(--local-text)] text-[var(--local-text)] bg-transparent">
                  <a href={data.secondaryCta.href}>{data.secondaryCta.label}</a>
                </Button>
              )}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
};
EOF

cat > src/components/contact-cta/index.ts << 'EOF'
export { ContactCta } from './View';
export { ContactCtaSchema } from './schema';
export type { ContactCtaData, ContactCtaSettings } from './types';
EOF

echo "-- Writing capsule: timeline..."
cat > src/components/timeline/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData, BaseArrayItem } from '@olonjs/core';

const TimelineItemSchema = BaseArrayItem.extend({
  period: z.string().describe('ui:text'),
  title: z.string().describe('ui:text'),
  organization: z.string().describe('ui:text'),
  body: z.string().describe('ui:textarea')
});

export const TimelineSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  items: z.array(TimelineItemSchema).describe('ui:list')
});
EOF

cat > src/components/timeline/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { TimelineSchema } from './schema';

export type TimelineData = z.infer<typeof TimelineSchema>;
export type TimelineSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/timeline/View.tsx << 'EOF'
// Layout: Hero=E (MAGAZINE), Features=C (TIMELINE)
import React from 'react';
import type { TimelineData, TimelineSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40'
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40'
};

export const Timeline: React.FC<{ data: TimelineData; settings: TimelineSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      bg: 'var(--theme-colors-background)',
      text: 'var(--theme-colors-foreground)',
      muted: 'var(--theme-colors-muted-foreground)',
      surface: 'var(--theme-colors-card)',
      border: 'var(--theme-colors-border)'
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)'
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)'
    }
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-sm': 'var(--theme-radius-sm)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)'
      } as React.CSSProperties}
      className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}
    >
      <div className={containerClass}>
        <div className="mb-12 max-w-2xl">
          {data.label && (
            <div className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4" data-jp-field="label">
              <span className="w-5 h-px bg-[var(--local-primary)]" />
              {data.label}
            </div>
          )}
          <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">
            {data.title}
          </h2>
        </div>
        <div className="relative space-y-8 before:absolute before:left-[8px] before:top-1 before:h-[calc(100%-2rem)] before:w-px before:bg-[var(--local-border)]">
          {data.items.map((item, idx) => (
            <div
              key={item.id || 'legacy-' + idx}
              className="relative pl-10"
              data-jp-item-id={item.id || 'legacy-' + idx}
              data-jp-item-field="items"
            >
              <span className="absolute left-0 top-1.5 h-4 w-4 rounded-full border border-[var(--local-border)] bg-[var(--local-primary)]" />
              <div className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-6">
                <div className="jp-meta">{item.period}</div>
                <h3 className="mt-3 font-display font-bold text-[1.2rem] leading-tight tracking-tight text-[var(--local-text)]">{item.title}</h3>
                <p className="mt-1 text-sm text-[var(--local-primary)]">{item.organization}</p>
                <p className="mt-3 text-sm text-[var(--local-text-muted)]">{item.body}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
};
EOF

cat > src/components/timeline/index.ts << 'EOF'
export { Timeline } from './View';
export { TimelineSchema } from './schema';
export type { TimelineData, TimelineSettings } from './types';
EOF

echo "-- Writing capsule: skills-grid..."
cat > src/components/skills-grid/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData, BaseArrayItem } from '@olonjs/core';

const SkillItemSchema = BaseArrayItem.extend({
  category: z.string().describe('ui:text'),
  label: z.string().describe('ui:text'),
  icon: z.string().describe('ui:icon-picker'),
  body: z.string().describe('ui:textarea')
});

export const SkillsGridSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  items: z.array(SkillItemSchema).describe('ui:list')
});
EOF

cat > src/components/skills-grid/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { SkillsGridSchema } from './schema';

export type SkillsGridData = z.infer<typeof SkillsGridSchema>;
export type SkillsGridSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/skills-grid/View.tsx << 'EOF'
// Layout: Hero=B (BENTO GRID), Features=A (BENTO)
import React from 'react';
import { Card, CardContent } from '@/components/ui/card';
import { IconResolver } from '@/lib/IconResolver';
import type { SkillsGridData, SkillsGridSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40'
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40'
};

export const SkillsGrid: React.FC<{ data: SkillsGridData; settings: SkillsGridSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      bg: 'var(--theme-colors-background)',
      text: 'var(--theme-colors-foreground)',
      muted: 'var(--theme-colors-muted-foreground)',
      surface: 'var(--theme-colors-card)',
      border: 'var(--theme-colors-border)'
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)'
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)'
    }
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-sm': 'var(--theme-radius-sm)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)'
      } as React.CSSProperties}
      className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}
    >
      <div className={containerClass}>
        <div className="mb-10 max-w-2xl">
          {data.label && (
            <div className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4" data-jp-field="label">
              <span className="w-5 h-px bg-[var(--local-primary)]" />
              {data.label}
            </div>
          )}
          <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">
            {data.title}
          </h2>
        </div>
        <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
          {data.items.map((item, idx) => {
            const Icon = IconResolver[item.icon];
            return (
              <Card
                key={item.id || 'legacy-' + idx}
                className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] text-[var(--local-text)]"
                data-jp-item-id={item.id || 'legacy-' + idx}
                data-jp-item-field="items"
              >
                <CardContent className="space-y-4 p-6">
                  <div className="flex items-center gap-3">
                    {Icon ? <Icon className="h-5 w-5 text-[var(--local-primary)]" /> : null}
                    <span className="jp-meta">{item.category}</span>
                  </div>
                  <h3 className="font-display font-bold text-[1.2rem] leading-tight tracking-tight text-[var(--local-text)]">{item.label}</h3>
                  <p className="text-sm text-[var(--local-text-muted)]">{item.body}</p>
                </CardContent>
              </Card>
            );
          })}
        </div>
      </div>
    </section>
  );
};
EOF

cat > src/components/skills-grid/index.ts << 'EOF'
export { SkillsGrid } from './View';
export { SkillsGridSchema } from './schema';
export type { SkillsGridData, SkillsGridSettings } from './types';
EOF

echo "-- Writing capsule: philosophy..."
cat > src/components/philosophy/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData, BaseArrayItem } from '@olonjs/core';

const PrincipleSchema = BaseArrayItem.extend({
  title: z.string().describe('ui:text'),
  body: z.string().describe('ui:textarea')
});

export const PhilosophySchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  items: z.array(PrincipleSchema).describe('ui:list')
});
EOF

cat > src/components/philosophy/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { PhilosophySchema } from './schema';

export type PhilosophyData = z.infer<typeof PhilosophySchema>;
export type PhilosophySettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/philosophy/View.tsx << 'EOF'
// Layout: Hero=E (MAGAZINE), Features=D (ACCORDION)
import React from 'react';
import { Accordion, AccordionContent, AccordionItem, AccordionTrigger } from '@/components/ui/accordion';
import type { PhilosophyData, PhilosophySettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40'
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40'
};

export const Philosophy: React.FC<{ data: PhilosophyData; settings: PhilosophySettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      bg: 'var(--theme-colors-background)',
      text: 'var(--theme-colors-foreground)',
      muted: 'var(--theme-colors-muted-foreground)',
      surface: 'var(--theme-colors-card)',
      border: 'var(--theme-colors-border)'
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)'
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)'
    }
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-sm': 'var(--theme-radius-sm)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)'
      } as React.CSSProperties}
      className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}
    >
      <div className={containerClass}>
        <div className="mb-10 max-w-2xl">
          {data.label && (
            <div className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4" data-jp-field="label">
              <span className="w-5 h-px bg-[var(--local-primary)]" />
              {data.label}
            </div>
          )}
          <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">
            {data.title}
          </h2>
          {data.description && (
            <p className="mt-4 text-[var(--local-text-muted)]" data-jp-field="description">
              {data.description}
            </p>
          )}
        </div>
        <Accordion type="single" collapsible className="w-full space-y-4">
          {data.items.map((item, idx) => (
            <AccordionItem
              key={item.id || 'legacy-' + idx}
              value={item.id || 'legacy-' + idx}
              className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] px-6"
              data-jp-item-id={item.id || 'legacy-' + idx}
              data-jp-item-field="items"
            >
              <AccordionTrigger className="text-left font-display text-[1.1rem] text-[var(--local-text)]">
                {item.title}
              </AccordionTrigger>
              <AccordionContent className="pb-5 text-sm text-[var(--local-text-muted)]">
                {item.body}
              </AccordionContent>
            </AccordionItem>
          ))}
        </Accordion>
      </div>
    </section>
  );
};
EOF

cat > src/components/philosophy/index.ts << 'EOF'
export { Philosophy } from './View';
export { PhilosophySchema } from './schema';
export type { PhilosophyData, PhilosophySettings } from './types';
EOF

echo "-- Writing capsule: contact-form..."
cat > src/components/contact-form/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionData, BaseArrayItem } from '@olonjs/core';

const ContactLinkSchema = BaseArrayItem.extend({
  label: z.string().describe('ui:text'),
  href: z.string().describe('ui:text'),
  icon: z.string().describe('ui:icon-picker')
});

export const ContactFormSchema = BaseSectionData.extend({
  label: z.string().optional().describe('ui:text'),
  title: z.string().describe('ui:text'),
  description: z.string().describe('ui:textarea'),
  email: z.string().describe('ui:text'),
  formNote: z.string().optional().describe('ui:textarea'),
  links: z.array(ContactLinkSchema).describe('ui:list')
});
EOF

cat > src/components/contact-form/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { ContactFormSchema } from './schema';

export type ContactFormData = z.infer<typeof ContactFormSchema>;
export type ContactFormSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/contact-form/View.tsx << 'EOF'
// Layout: Hero=A (SPLIT 60/40), Features=A (BENTO)
import React from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { IconResolver } from '@/lib/IconResolver';
import type { ContactFormData, ContactFormSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40'
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40'
};

export const ContactForm: React.FC<{ data: ContactFormData; settings: ContactFormSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'md'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'md'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      bg: 'var(--theme-colors-background)',
      text: 'var(--theme-colors-foreground)',
      muted: 'var(--theme-colors-muted-foreground)',
      surface: 'var(--theme-colors-card)',
      border: 'var(--theme-colors-border)'
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)'
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)'
    }
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-primary-foreground': 'var(--primary-foreground)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-sm': 'var(--theme-radius-sm)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)'
      } as React.CSSProperties}
      className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}
    >
      <div className={containerClass}>
        <div className="grid gap-8 lg:grid-cols-[0.85fr_1.15fr]">
          <div className="space-y-5">
            {data.label && (
              <div className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4" data-jp-field="label">
                <span className="w-5 h-px bg-[var(--local-primary)]" />
                {data.label}
              </div>
            )}
            <h2 className="font-display font-black text-[clamp(2rem,4.5vw,3.8rem)] leading-[1.05] tracking-tight text-[var(--local-text)]" data-jp-field="title">
              {data.title}
            </h2>
            <p className="text-[var(--local-text-muted)]" data-jp-field="description">
              {data.description}
            </p>
            <a href={'mailto:' + data.email} className="jp-meta text-[var(--local-primary)]" data-jp-field="email">
              {data.email}
            </a>
            {data.formNote && (
              <p className="text-sm text-[var(--local-text-muted)]" data-jp-field="formNote">
                {data.formNote}
              </p>
            )}
            <div className="flex flex-col gap-3">
              {data.links.map((item, idx) => {
                const Icon = IconResolver[item.icon];
                return (
                  <a
                    key={item.id || 'legacy-' + idx}
                    href={item.href}
                    className="flex items-center gap-3 text-sm text-[var(--local-text)]"
                    data-jp-item-id={item.id || 'legacy-' + idx}
                    data-jp-item-field="links"
                  >
                    {Icon ? <Icon className="h-4 w-4 text-[var(--local-primary)]" /> : null}
                    <span>{item.label}</span>
                  </a>
                );
              })}
            </div>
          </div>
          <form className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-6">
            <div className="grid gap-5">
              <div className="grid gap-2">
                <Label htmlFor="name">Name</Label>
                <Input id="name" placeholder="Your name" className="border-[var(--local-border)] bg-background text-foreground" />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="email">Email</Label>
                <Input id="email" type="email" placeholder="you@company.com" className="border-[var(--local-border)] bg-background text-foreground" />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="message">Message</Label>
                <Textarea id="message" rows={7} placeholder="Project scope, editorial brief, or architecture review request." className="border-[var(--local-border)] bg-background text-foreground" />
              </div>
              <Button type="submit" variant="default" className="rounded-[var(--local-radius-md)] bg-[var(--local-primary)] text-[var(--local-primary-foreground)]">
                Send inquiry
              </Button>
            </div>
          </form>
        </div>
      </div>
    </section>
  );
};
EOF

cat > src/components/contact-form/index.ts << 'EOF'
export { ContactForm } from './View';
export { ContactFormSchema } from './schema';
export type { ContactFormData, ContactFormSettings } from './types';
EOF

echo "-- Writing capsule: project-detail..."
cat > src/components/project-detail/schema.ts << 'EOF'
import { BaseSectionData } from '@olonjs/core';
import { ProjectSchema } from '@/collections/projects';

export const ProjectDetailSchema = BaseSectionData.extend({
  item: ProjectSchema.describe('ui:collection-ref')
});
EOF

cat > src/components/project-detail/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { ProjectDetailSchema } from './schema';

export type ProjectDetailData = z.infer<typeof ProjectDetailSchema>;
export type ProjectDetailSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/project-detail/View.tsx << 'EOF'
// Layout: Hero=E (MAGAZINE), Features=C (TIMELINE)
import React from 'react';
import type { ProjectDetailData, ProjectDetailSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40'
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40'
};

export const ProjectDetail: React.FC<{ data: ProjectDetailData; settings: ProjectDetailSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'lg'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'lg'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      bg: 'var(--theme-colors-background)',
      text: 'var(--theme-colors-foreground)',
      muted: 'var(--theme-colors-muted-foreground)',
      surface: 'var(--theme-colors-card)',
      border: 'var(--theme-colors-border)'
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)'
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)'
    }
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;
  const item = data.item;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-sm': 'var(--theme-radius-sm)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)'
      } as React.CSSProperties}
      className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}
    >
      <div className={containerClass}>
        <div className="max-w-4xl space-y-10">
          <div className="space-y-4">
            <div className="flex flex-wrap gap-2">
              <span className="jp-chip">{item.year}</span>
              <span className="jp-chip">{item.category}</span>
            </div>
            <h1 className="font-display font-black text-[clamp(2.7rem,5vw,4.8rem)] leading-[1.02] tracking-tight text-[var(--local-text)]">
              {item.title}
            </h1>
            <p className="max-w-3xl text-[1.05rem] text-[var(--local-text-muted)]">{item.summary}</p>
          </div>
          <div className="grid gap-6 md:grid-cols-3">
            <div className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-5">
              <div className="jp-meta">Context</div>
              <p className="mt-3 text-sm text-[var(--local-text)]">{item.context}</p>
            </div>
            <div className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-5">
              <div className="jp-meta">Problem</div>
              <p className="mt-3 text-sm text-[var(--local-text)]">{item.problem}</p>
            </div>
            <div className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-5">
              <div className="jp-meta">Result</div>
              <p className="mt-3 text-sm text-[var(--local-text)]">{item.result}</p>
            </div>
          </div>
          <div className="grid gap-6">
            <div className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-7">
              <h2 className="font-display text-2xl text-[var(--local-text)]">Architecture decision</h2>
              <p className="mt-4 text-[var(--local-text-muted)]">{item.architecture}</p>
            </div>
            <div className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-7">
              <h2 className="font-display text-2xl text-[var(--local-text)]">Stack used</h2>
              <div className="mt-4 flex flex-wrap gap-2">
                {item.stack.map((tech, idx) => (
                  <span key={tech + '-' + idx} className="jp-chip">{tech}</span>
                ))}
              </div>
            </div>
            <div className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-7">
              <h2 className="font-display text-2xl text-[var(--local-text)]">Outcome</h2>
              <p className="mt-4 text-[var(--local-text-muted)]">{item.outcomeLong}</p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
};
EOF

cat > src/components/project-detail/index.ts << 'EOF'
export { ProjectDetail } from './View';
export { ProjectDetailSchema } from './schema';
export type { ProjectDetailData, ProjectDetailSettings } from './types';
EOF

echo "-- Writing capsule: post-detail..."
cat > src/components/post-detail/schema.ts << 'EOF'
import { BaseSectionData } from '@olonjs/core';
import { PostSchema } from '@/collections/posts';

export const PostDetailSchema = BaseSectionData.extend({
  item: PostSchema.describe('ui:collection-ref')
});
EOF

cat > src/components/post-detail/types.ts << 'EOF'
import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { PostDetailSchema } from './schema';

export type PostDetailData = z.infer<typeof PostDetailSchema>;
export type PostDetailSettings = z.infer<typeof BaseSectionSettingsSchema>;
EOF

cat > src/components/post-detail/View.tsx << 'EOF'
// Layout: Hero=E (MAGAZINE), Features=B (HORIZONTAL SCROLL)
import React from 'react';
import type { PostDetailData, PostDetailSettings } from './types';

const PADDING_TOP: Record<string, string> = {
  none: 'pt-0', sm: 'pt-8', md: 'pt-16', lg: 'pt-24', xl: 'pt-32', '2xl': 'pt-40'
};
const PADDING_BOTTOM: Record<string, string> = {
  none: 'pb-0', sm: 'pb-8', md: 'pb-16', lg: 'pb-24', xl: 'pb-32', '2xl': 'pb-40'
};

export const PostDetail: React.FC<{ data: PostDetailData; settings: PostDetailSettings }> = ({ data, settings }) => {
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'lg'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'lg'];
  const containerClass = settings?.container === 'fluid' ? 'w-full px-8' : 'max-w-[1200px] mx-auto px-8';
  const sectionTheme = settings?.theme ?? 'dark';
  const SECTION_THEME_VARS: Record<string, { bg: string; text: string; muted: string; surface: string; border: string }> = {
    dark: {
      bg: 'var(--theme-colors-background)',
      text: 'var(--theme-colors-foreground)',
      muted: 'var(--theme-colors-muted-foreground)',
      surface: 'var(--theme-colors-card)',
      border: 'var(--theme-colors-border)'
    },
    light: {
      bg: 'var(--theme-modes-light-colors-background)',
      text: 'var(--theme-modes-light-colors-foreground)',
      muted: 'var(--theme-modes-light-colors-muted-foreground)',
      surface: 'var(--theme-modes-light-colors-card)',
      border: 'var(--theme-modes-light-colors-border)'
    },
    accent: {
      bg: 'var(--accent)',
      text: 'var(--accent-foreground)',
      muted: 'var(--accent-foreground)',
      surface: 'var(--accent)',
      border: 'var(--border)'
    }
  };
  const t = SECTION_THEME_VARS[sectionTheme] ?? SECTION_THEME_VARS.dark;
  const item = data.item;

  return (
    <section
      style={{
        '--local-bg': t.bg,
        '--local-text': t.text,
        '--local-text-muted': t.muted,
        '--local-primary': 'var(--primary)',
        '--local-accent': 'var(--accent)',
        '--local-border': t.border,
        '--local-surface': t.surface,
        '--local-radius-sm': 'var(--theme-radius-sm)',
        '--local-radius-md': 'var(--theme-radius-md)',
        '--local-radius-lg': 'var(--theme-radius-lg)'
      } as React.CSSProperties}
      className={'relative z-0 ' + paddingTop + ' ' + paddingBottom + ' bg-[var(--local-bg)]'}
    >
      <div className={containerClass}>
        <article className="max-w-3xl space-y-8">
          <header className="space-y-4">
            <div className="flex flex-wrap gap-3">
              <span className="jp-meta">{item.date}</span>
              <span className="jp-meta">{item.readingTime}</span>
            </div>
            <h1 className="font-display font-black text-[clamp(2.7rem,5vw,4.8rem)] leading-[1.02] tracking-tight text-[var(--local-text)]">
              {item.title}
            </h1>
            <p className="text-[1.05rem] text-[var(--local-text-muted)]">{item.dek}</p>
            <div className="flex flex-wrap gap-2">
              {item.tags.map((tag, idx) => (
                <span key={tag + '-' + idx} className="jp-chip">{tag}</span>
              ))}
            </div>
          </header>
          <div className="prose-terminal space-y-5">
            {item.content.map((paragraph, idx) => (
              <p key={paragraph.slice(0, 24) + '-' + idx}>{paragraph}</p>
            ))}
          </div>
          <div className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] p-6">
            <h2 className="font-display text-2xl text-[var(--local-text)]">Related topics</h2>
            <div className="mt-4 flex flex-wrap gap-2">
              {item.related.map((entry, idx) => (
                <span key={entry + '-' + idx} className="jp-chip">{entry}</span>
              ))}
            </div>
          </div>
        </article>
      </div>
    </section>
  );
};
EOF

cat > src/components/post-detail/index.ts << 'EOF'
export { PostDetail } from './View';
export { PostDetailSchema } from './schema';
export type { PostDetailData, PostDetailSettings } from './types';
EOF

echo "-- Writing collections..."
cat > src/collections/projects/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseCollectionItem } from '@olonjs/core';

export const ProjectSchema = BaseCollectionItem.extend({
  slug: z.string().describe('ui:text'),
  title: z.string().describe('ui:text'),
  category: z.string().describe('ui:text'),
  year: z.string().describe('ui:text'),
  summary: z.string().describe('ui:textarea'),
  context: z.string().describe('ui:textarea'),
  problem: z.string().describe('ui:textarea'),
  architecture: z.string().describe('ui:textarea'),
  result: z.string().describe('ui:textarea'),
  outcomeLong: z.string().describe('ui:textarea'),
  stack: z.array(z.string()).describe('ui:list')
});

export const ProjectsCollectionSchema = z.record(z.string(), ProjectSchema);
EOF

cat > src/collections/projects/types.ts << 'EOF'
import { z } from 'zod';
import { ProjectSchema, ProjectsCollectionSchema } from './schema';

export type Project = z.infer<typeof ProjectSchema>;
export type ProjectsCollection = z.infer<typeof ProjectsCollectionSchema>;
EOF

cat > src/collections/projects/index.ts << 'EOF'
export { ProjectSchema, ProjectsCollectionSchema } from './schema';
export type { Project, ProjectsCollection } from './types';
EOF

cat > src/collections/posts/schema.ts << 'EOF'
import { z } from 'zod';
import { BaseCollectionItem } from '@olonjs/core';

export const PostSchema = BaseCollectionItem.extend({
  slug: z.string().describe('ui:text'),
  title: z.string().describe('ui:text'),
  dek: z.string().describe('ui:textarea'),
  date: z.string().describe('ui:text'),
  readingTime: z.string().describe('ui:text'),
  tags: z.array(z.string()).describe('ui:list'),
  related: z.array(z.string()).describe('ui:list'),
  content: z.array(z.string()).describe('ui:list')
});

export const PostsCollectionSchema = z.record(z.string(), PostSchema);
EOF

cat > src/collections/posts/types.ts << 'EOF'
import { z } from 'zod';
import { PostSchema, PostsCollectionSchema } from './schema';

export type Post = z.infer<typeof PostSchema>;
export type PostsCollection = z.infer<typeof PostsCollectionSchema>;
EOF

cat > src/collections/posts/index.ts << 'EOF'
export { PostSchema, PostsCollectionSchema } from './schema';
export type { Post, PostsCollection } from './types';
EOF

cat > src/lib/CollectionRegistry.ts << 'EOF'
import { ProjectsCollectionSchema } from '@/collections/projects';
import { PostsCollectionSchema } from '@/collections/posts';

export const CollectionRegistry = {
  projects: ProjectsCollectionSchema,
  posts: PostsCollectionSchema
} as const;

export type CollectionType = keyof typeof CollectionRegistry;
EOF

echo "-- Writing icon resolver..."
cat > src/lib/IconResolver.tsx << 'EOF'
import type { LucideIcon } from 'lucide-react';
import {
  Braces,
  Database,
  Server,
  Cpu,
  Workflow,
  Github,
  Linkedin,
  Rss,
  Mail
} from 'lucide-react';

export const iconMap: Record<string, LucideIcon> = {
  braces: Braces,
  database: Database,
  server: Server,
  cpu: Cpu,
  workflow: Workflow,
  github: Github,
  linkedin: Linkedin,
  rss: Rss,
  mail: Mail
};

export const IconResolver = iconMap;
EOF

echo "-- Writing wiring files..."
cat > src/types.ts << 'EOF'
import type { HeaderData, HeaderSettings } from '@/components/header';
import type { FooterData, FooterSettings } from '@/components/footer';
import type { EditorialHeroData, EditorialHeroSettings } from '@/components/editorial-hero';
import type { PageHeroData, PageHeroSettings } from '@/components/page-hero';
import type { FeaturedProjectsData, FeaturedProjectsSettings } from '@/components/featured-projects';
import type { BlogRollupData, BlogRollupSettings } from '@/components/blog-rollup';
import type { BioPanelData, BioPanelSettings } from '@/components/bio-panel';
import type { ContactCtaData, ContactCtaSettings } from '@/components/contact-cta';
import type { TimelineData, TimelineSettings } from '@/components/timeline';
import type { SkillsGridData, SkillsGridSettings } from '@/components/skills-grid';
import type { PhilosophyData, PhilosophySettings } from '@/components/philosophy';
import type { ContactFormData, ContactFormSettings } from '@/components/contact-form';
import type { ProjectDetailData, ProjectDetailSettings } from '@/components/project-detail';
import type { PostDetailData, PostDetailSettings } from '@/components/post-detail';

export type SectionComponentPropsMap = {
  'header': { data: HeaderData; settings: HeaderSettings };
  'footer': { data: FooterData; settings: FooterSettings };
  'editorial-hero': { data: EditorialHeroData; settings: EditorialHeroSettings };
  'page-hero': { data: PageHeroData; settings: PageHeroSettings };
  'featured-projects': { data: FeaturedProjectsData; settings: FeaturedProjectsSettings };
  'blog-rollup': { data: BlogRollupData; settings: BlogRollupSettings };
  'bio-panel': { data: BioPanelData; settings: BioPanelSettings };
  'contact-cta': { data: ContactCtaData; settings: ContactCtaSettings };
  'timeline': { data: TimelineData; settings: TimelineSettings };
  'skills-grid': { data: SkillsGridData; settings: SkillsGridSettings };
  'philosophy': { data: PhilosophyData; settings: PhilosophySettings };
  'contact-form': { data: ContactFormData; settings: ContactFormSettings };
  'project-detail': { data: ProjectDetailData; settings: ProjectDetailSettings };
  'post-detail': { data: PostDetailData; settings: PostDetailSettings };
};

declare module '@olonjs/core' {
  export interface SectionDataRegistry {
    'header': HeaderData;
    'footer': FooterData;
    'editorial-hero': EditorialHeroData;
    'page-hero': PageHeroData;
    'featured-projects': FeaturedProjectsData;
    'blog-rollup': BlogRollupData;
    'bio-panel': BioPanelData;
    'contact-cta': ContactCtaData;
    'timeline': TimelineData;
    'skills-grid': SkillsGridData;
    'philosophy': PhilosophyData;
    'contact-form': ContactFormData;
    'project-detail': ProjectDetailData;
    'post-detail': PostDetailData;
  }
  export interface SectionSettingsRegistry {
    'header': HeaderSettings;
    'footer': FooterSettings;
    'editorial-hero': EditorialHeroSettings;
    'page-hero': PageHeroSettings;
    'featured-projects': FeaturedProjectsSettings;
    'blog-rollup': BlogRollupSettings;
    'bio-panel': BioPanelSettings;
    'contact-cta': ContactCtaSettings;
    'timeline': TimelineSettings;
    'skills-grid': SkillsGridSettings;
    'philosophy': PhilosophySettings;
    'contact-form': ContactFormSettings;
    'project-detail': ProjectDetailSettings;
    'post-detail': PostDetailSettings;
  }
}

export * from '@olonjs/core';
EOF

cat > src/lib/ComponentRegistry.tsx << 'EOF'
import React from 'react';
import { Header } from '@/components/header';
import { Footer } from '@/components/footer';
import { EditorialHero } from '@/components/editorial-hero';
import { PageHero } from '@/components/page-hero';
import { FeaturedProjects } from '@/components/featured-projects';
import { BlogRollup } from '@/components/blog-rollup';
import { BioPanel } from '@/components/bio-panel';
import { ContactCta } from '@/components/contact-cta';
import { Timeline } from '@/components/timeline';
import { SkillsGrid } from '@/components/skills-grid';
import { Philosophy } from '@/components/philosophy';
import { ContactForm } from '@/components/contact-form';
import { ProjectDetail } from '@/components/project-detail';
import { PostDetail } from '@/components/post-detail';

import type { SectionType } from '@olonjs/core';
import type { SectionComponentPropsMap } from '@/types';

export const ComponentRegistry: {
  [K in SectionType]: React.FC<SectionComponentPropsMap[K]>;
} = {
  'header': Header,
  'footer': Footer,
  'editorial-hero': EditorialHero,
  'page-hero': PageHero,
  'featured-projects': FeaturedProjects,
  'blog-rollup': BlogRollup,
  'bio-panel': BioPanel,
  'contact-cta': ContactCta,
  'timeline': Timeline,
  'skills-grid': SkillsGrid,
  'philosophy': Philosophy,
  'contact-form': ContactForm,
  'project-detail': ProjectDetail,
  'post-detail': PostDetail
};
EOF

cat > src/lib/schemas.ts << 'EOF'
import { BaseArrayItem, BaseSectionData, BaseSectionSettingsSchema, CtaSchema, ImageSelectionSchema } from '@olonjs/core';
import { HeaderSchema } from '@/components/header';
import { FooterSchema } from '@/components/footer';
import { EditorialHeroSchema } from '@/components/editorial-hero';
import { PageHeroSchema } from '@/components/page-hero';
import { FeaturedProjectsSchema } from '@/components/featured-projects';
import { BlogRollupSchema } from '@/components/blog-rollup';
import { BioPanelSchema } from '@/components/bio-panel';
import { ContactCtaSchema } from '@/components/contact-cta';
import { TimelineSchema } from '@/components/timeline';
import { SkillsGridSchema } from '@/components/skills-grid';
import { PhilosophySchema } from '@/components/philosophy';
import { ContactFormSchema } from '@/components/contact-form';
import { ProjectDetailSchema } from '@/components/project-detail';
import { PostDetailSchema } from '@/components/post-detail';

export const SECTION_SCHEMAS = {
  'header': HeaderSchema,
  'footer': FooterSchema,
  'editorial-hero': EditorialHeroSchema,
  'page-hero': PageHeroSchema,
  'featured-projects': FeaturedProjectsSchema,
  'blog-rollup': BlogRollupSchema,
  'bio-panel': BioPanelSchema,
  'contact-cta': ContactCtaSchema,
  'timeline': TimelineSchema,
  'skills-grid': SkillsGridSchema,
  'philosophy': PhilosophySchema,
  'contact-form': ContactFormSchema,
  'project-detail': ProjectDetailSchema,
  'post-detail': PostDetailSchema
} as const;

export const SECTION_SUBMISSION_SCHEMAS = {
} as const;

export type SectionType = keyof typeof SECTION_SCHEMAS;

export {
  BaseSectionData,
  BaseArrayItem,
  BaseSectionSettingsSchema,
  CtaSchema,
  ImageSelectionSchema
} from '@olonjs/core';
EOF

cat > src/lib/addSectionConfig.ts << 'EOF'
import type { AddSectionConfig } from '@olonjs/core';

const addableSectionTypes = [
  'editorial-hero',
  'page-hero',
  'featured-projects',
  'blog-rollup',
  'bio-panel',
  'contact-cta',
  'timeline',
  'skills-grid',
  'philosophy',
  'contact-form',
  'project-detail',
  'post-detail'
] as const;

const sectionTypeLabels: Record<string, string> = {
  'editorial-hero': 'Editorial Hero',
  'page-hero': 'Page Hero',
  'featured-projects': 'Featured Projects',
  'blog-rollup': 'Blog Rollup',
  'bio-panel': 'Bio Panel',
  'contact-cta': 'Contact CTA',
  'timeline': 'Timeline',
  'skills-grid': 'Skills Grid',
  'philosophy': 'Philosophy',
  'contact-form': 'Contact Form',
  'project-detail': 'Project Detail',
  'post-detail': 'Post Detail'
};

function getDefaultSectionData(type: string): Record<string, unknown> {
  switch (type) {
    case 'editorial-hero':
      return { title: 'Systems architecture with editorial clarity', description: 'I design backend platforms and write about structured data systems.', primaryCta: { id: 'cta-1', label: 'Get in touch', href: '/contact', variant: 'primary' } };
    case 'page-hero':
      return { title: 'Page title', description: 'Page introduction.' };
    case 'featured-projects':
      return { title: 'Selected work', items: {} };
    case 'blog-rollup':
      return { title: 'Latest writing', items: {} };
    case 'bio-panel':
      return { title: 'About Andrew', description: 'Short biography.' };
    case 'contact-cta':
      return { title: 'Start a conversation', description: 'Reach out for consulting or writing work.' };
    case 'timeline':
      return { title: 'Experience', items: [] };
    case 'skills-grid':
      return { title: 'Technical stack', items: [] };
    case 'philosophy':
      return { title: 'Design principles', items: [] };
    case 'contact-form':
      return { title: 'Contact', description: 'Send a note.', email: 'hello@andrewlinh.dev', links: [] };
    case 'project-detail':
      return {};
    case 'post-detail':
      return {};
    default:
      return {};
  }
}

export const addSectionConfig: AddSectionConfig = {
  addableSectionTypes: [...addableSectionTypes],
  sectionTypeLabels,
  getDefaultSectionData
};
EOF

echo "-- Writing config data..."
cat > src/data/config/site.json << 'EOF'
{
  "header": {
    "id": "global-header",
    "type": "header",
    "data": {
      "announcement": "Systems architecture, structured data, and AI-native tooling.",
      "logoText": "Andrew Linh",
      "logoHighlight": "systems architect",
      "menu": { "$ref": "../config/menu.json#/main" }
    },
    "settings": { "sticky": true }
  },
  "footer": {
    "id": "global-footer",
    "type": "footer",
    "data": {
      "brandText": "Andrew Linh",
      "brandHighlight": "technical writing",
      "summary": "A personal portfolio and editorial home for backend architecture, developer tools, and calm, precise systems design.",
      "email": "hello@andrewlinh.dev",
      "copyright": "© 2026 Andrew Linh. All rights reserved.",
      "menu": { "$ref": "../config/menu.json#/footer" }
    },
    "settings": { "showLogo": true }
  },
  "identity": {
    "title": "Andrew Linh"
  }
}
EOF

cat > src/data/config/menu.json << 'EOF'
{
  "main": [
    { "id": "nav-about", "label": "About", "href": "/about" },
    { "id": "nav-work", "label": "Work", "href": "/work" },
    { "id": "nav-blog", "label": "Blog", "href": "/blog" },
    { "id": "nav-contact", "label": "Contact", "href": "/contact", "isCta": true }
  ],
  "footer": [
    { "id": "foot-github", "label": "GitHub", "href": "https://github.com/andrewlinh", "icon": "github" },
    { "id": "foot-linkedin", "label": "LinkedIn", "href": "https://www.linkedin.com/in/andrewlinh", "icon": "linkedin" },
    { "id": "foot-rss", "label": "RSS", "href": "/blog/rss.xml", "icon": "rss" },
    { "id": "foot-email", "label": "Email", "href": "mailto:hello@andrewlinh.dev", "icon": "mail" }
  ]
}
EOF

echo "-- Writing collection data..."
cat > src/data/collections/projects/projects.json << 'EOF'
{
  "ledger-graph-migration": {
    "id": "ledger-graph-migration",
    "slug": "ledger-graph-migration",
    "title": "Ledger Graph Migration",
    "category": "Data Platform",
    "year": "2025",
    "summary": "Rebuilt a payment-ledger dependency service from ad-hoc SQL traversals into a graph-backed event pipeline that could explain settlement state in milliseconds instead of minutes.",
    "context": "A fintech platform had grown a reconciliation engine around recursive SQL and delayed batch jobs. Operators could not answer why a payout was blocked without running custom scripts.",
    "problem": "The system mixed transactional writes, lineage queries, and retry orchestration in one relational workflow, producing lock contention and opaque incident handling.",
    "architecture": "I separated the write path from the explanation path, emitting append-only ledger events into Kafka, materializing relationship edges into a graph projection, and exposing deterministic trace queries through a typed service boundary.",
    "result": "Median payout-trace latency dropped from 11.4 minutes to 420 milliseconds, and incident triage time during settlement windows fell by 68 percent.",
    "outcomeLong": "The biggest gain was not only latency but operator confidence. Support and finance teams could inspect state transitions without waking engineering, while platform teams gained a clean contract for downstream analytics and audit exports.",
    "stack": ["TypeScript", "Kafka", "PostgreSQL", "Neo4j", "OpenTelemetry"]
  },
  "docs-schema-pipeline": {
    "id": "docs-schema-pipeline",
    "slug": "docs-schema-pipeline",
    "title": "Docs Schema Pipeline",
    "category": "Developer Experience",
    "year": "2024",
    "summary": "Designed a schema-driven documentation pipeline for an internal platform so product docs, API references, and release notes could be authored once and published consistently across surfaces.",
    "context": "Teams maintained markdown fragments, API snippets, and changelog entries in separate systems, which caused drift between the product, docs site, and support tooling.",
    "problem": "Every team solved structured content differently, so navigation, metadata, and validation rules changed from one repository to the next.",
    "architecture": "I introduced a shared content schema package, JSON-authored publishing manifests, and TypeScript-generated render contracts that enforced field-level guarantees from authoring to delivery.",
    "result": "Documentation publishing time fell from two days of manual QA to a 20-minute automated pipeline, while support ticket deflection improved 24 percent after launch.",
    "outcomeLong": "The program created a repeatable way to evolve docs as a product surface. New documentation types no longer needed a custom renderer or manual governance process.",
    "stack": ["TypeScript", "Zod", "Node.js", "Vite", "GitHub Actions"]
  },
  "agent-tooling-control-plane": {
    "id": "agent-tooling-control-plane",
    "slug": "agent-tooling-control-plane",
    "title": "Agent Tooling Control Plane",
    "category": "AI Infrastructure",
    "year": "2025",
    "summary": "Built a control plane for tool-enabled AI agents that standardized tool registration, execution traces, and safety policies across multiple internal assistants.",
    "context": "Three teams were building AI copilots with duplicated wrappers around APIs, uneven telemetry, and no shared policy layer for rate limits or human escalation.",
    "problem": "Agents could call tools, but operations had no consistent record of which action happened, why it happened, or whether a fallback path was available.",
    "architecture": "I defined a typed tool registry, execution envelopes with structured inputs and outputs, and a policy runtime that could intercept calls for approval, retries, and observability before forwarding to the target system.",
    "result": "Time to add a new tool dropped from roughly 3 engineer-days to under 4 hours, and production debugging of failed agent actions improved because every step shipped with normalized traces.",
    "outcomeLong": "The control plane became a foundation for safer experimentation. Teams could ship domain-specific assistants without rewriting execution plumbing, while security retained central visibility into tool access patterns.",
    "stack": ["TypeScript", "Temporal", "Redis", "OpenTelemetry", "gRPC"]
  },
  "warehouse-query-gateway": {
    "id": "warehouse-query-gateway",
    "slug": "warehouse-query-gateway",
    "title": "Warehouse Query Gateway",
    "category": "Backend Architecture",
    "year": "2023",
    "summary": "Introduced a typed query gateway in front of a multi-tenant analytics warehouse to prevent unsafe workloads, normalize caching, and make query cost visible to product teams.",
    "context": "A SaaS analytics product allowed many internal services to hit the warehouse directly, leading to noisy-neighbor issues and expensive exploratory queries in production paths.",
    "problem": "There was no shared contract for query shape, access policy, or caching strategy, so every service optimized independently and often poorly.",
    "architecture": "I inserted a gateway that accepted only named, schema-validated query definitions, applied tenant-aware caching, and attached cost telemetry to every execution path before forwarding requests to the warehouse.",
    "result": "Warehouse spend dropped 31 percent quarter over quarter, p95 dashboard latency improved by 43 percent, and support incidents tied to runaway queries nearly disappeared.",
    "outcomeLong": "The gateway clarified ownership around analytics workloads and made performance decisions legible. Teams could reason about the cost of product features before launch instead of after billing surprises.",
    "stack": ["Go", "PostgreSQL", "BigQuery", "Redis", "Prometheus"]
  }
}
EOF

cat > src/data/collections/posts/posts.json << 'EOF'
{
  "schema-driven-content-without-regret": {
    "id": "schema-driven-content-without-regret",
    "slug": "schema-driven-content-without-regret",
    "title": "Schema-Driven Content Without Regret",
    "dek": "How to use strict content schemas to speed up publishing instead of trapping editors in brittle abstractions.",
    "date": "2026-01-14",
    "readingTime": "8 min read",
    "tags": ["content systems", "schemas", "cms"],
    "related": ["structured authoring", "editor UX", "validation"],
    "content": [
      "Schema-driven content is often sold as a governance tool, but the more interesting question is whether it improves editorial flow. In practice, teams only keep a structured system if it reduces ambiguity and removes repetitive review cycles.",
      "The most durable pattern I have seen is to encode the invariants that already matter in production: URL shape, required metadata, relation integrity, and render-safe field types. Everything else should remain flexible enough for editors to work at writing speed.",
      "A useful schema is narrow where breakage is expensive and permissive where exploration is editorial. That usually means strong contracts for taxonomy, embeds, and navigation, combined with lighter constraints for narrative structure.",
      "The implementation detail many teams miss is feedback timing. Validation at publish time is too late. Editors need field-level guidance, sensible defaults, and previews that reflect the same render path the site will use in production.",
      "If a schema makes authors feel policed instead of supported, it will be bypassed. Good systems make the correct shape the path of least resistance."
    ]
  },
  "end-to-end-type-safety-is-an-org-design-problem": {
    "id": "end-to-end-type-safety-is-an-org-design-problem",
    "slug": "end-to-end-type-safety-is-an-org-design-problem",
    "title": "End-to-End Type Safety Is an Org Design Problem",
    "dek": "Type safety fails less often because of missing tooling than because ownership boundaries are unclear between APIs, content, and frontend surfaces.",
    "date": "2026-02-03",
    "readingTime": "10 min read",
    "tags": ["type safety", "typescript", "platform"],
    "related": ["schema ownership", "api contracts", "frontend architecture"],
    "content": [
      "Teams like to frame end-to-end type safety as a language feature, but the harder part is deciding who owns the contract when multiple systems touch the same data. A generated client is only as trustworthy as the source of truth behind it.",
      "The best implementations start with a small number of canonical schemas and treat all renderers, APIs, and jobs as consumers of those schemas rather than parallel authors. That changes how work is divided across teams.",
      "One anti-pattern is allowing every boundary to reshape data independently while still claiming the system is typed. Types become decorative when transforms are untracked or conventions live in Slack threads.",
      "Type safety becomes real when schema changes are reviewable, migration paths are explicit, and runtime validation exists where trust actually breaks down. Compile-time guarantees are necessary, but they are not sufficient.",
      "In other words: if your organization cannot agree on ownership, TypeScript will not save you."
    ]
  },
  "tooling-for-ai-agents-needs-boring-infrastructure": {
    "id": "tooling-for-ai-agents-needs-boring-infrastructure",
    "slug": "tooling-for-ai-agents-needs-boring-infrastructure",
    "title": "Tooling for AI Agents Needs Boring Infrastructure",
    "dek": "Reliable agent systems depend less on model novelty and more on the operational discipline behind tool execution, tracing, and failure handling.",
    "date": "2026-02-22",
    "readingTime": "9 min read",
    "tags": ["ai agents", "tooling", "observability"],
    "related": ["workflow engines", "safety", "runtime policy"],
    "content": [
      "The most common mistake in agent platforms is treating tool invocation like a side feature. In reality, once an agent can act on external systems, execution plumbing becomes the product.",
      "You need structured envelopes for inputs and outputs, durable traces, retry semantics, and a policy layer that can stop or reroute risky actions. None of this is glamorous, which is exactly why it matters.",
      "Boring infrastructure wins because it creates predictable failure modes. When an agent call fails, operators should know whether the model selected the wrong tool, the tool returned invalid data, or a downstream dependency timed out.",
      "This is also where developer experience matters. If adding a new tool requires bespoke wrappers and custom telemetry, teams will duplicate logic and drift immediately.",
      "The organizations shipping credible agent systems are usually the ones that quietly solved execution discipline first."
    ]
  },
  "developer-experience-begins-with-system-legibility": {
    "id": "developer-experience-begins-with-system-legibility",
    "slug": "developer-experience-begins-with-system-legibility",
    "title": "Developer Experience Begins with System Legibility",
    "dek": "Fast onboarding and clean APIs matter, but DX improves most when engineers can explain what the system is doing and why.",
    "date": "2026-03-11",
    "readingTime": "7 min read",
    "tags": ["developer experience", "platform", "observability"],
    "related": ["internal tools", "docs", "operability"],
    "content": [
      "Developer experience is often reduced to ergonomics: better CLI design, cleaner SDKs, nicer templates. Those things help, but they do not compensate for a system that is hard to read.",
      "Legibility means an engineer can trace a request, inspect a configuration source, understand the active contract, and predict what a change will affect. It is the difference between confidence and cargo culting.",
      "In platform work, the highest leverage improvements are often explanatory rather than flashy. A good error message, visible ownership metadata, or a schema diff can save more time than a redesigned dashboard.",
      "This is one reason documentation should be treated as runtime support, not marketing exhaust. Engineers need systems that explain themselves while they are in motion.",
      "If a platform is elegant only when presented in architecture slides, the developer experience is not actually good."
    ]
  }
}
EOF

echo "-- Writing page data..."
cat > src/data/pages/home.json << 'EOF'
{
  "id": "home-page",
  "slug": "home",
  "meta": {
    "title": "Andrew Linh — Systems Architect and Technical Writer",
    "description": "Explore the portfolio and writing of Andrew Linh, a systems architect focused on backend platforms, structured data systems, developer tools, and AI-native infrastructure."
  },
  "sections": [
    {
      "id": "home-editorial-hero",
      "type": "editorial-hero",
      "data": {
        "label": "Andrew Linh",
        "title": "Systems architecture for products that need",
        "titleHighlight": "clarity under load.",
        "description": "I design backend platforms, structured data systems, and AI-native tooling with an emphasis on legibility, type safety, and operational calm.",
        "status": "Available for consulting in Q2",
        "primaryCta": { "id": "home-hero-cta-1", "label": "Start a conversation", "href": "/contact", "variant": "primary" },
        "secondaryCta": { "id": "home-hero-cta-2", "label": "See selected work", "href": "/work", "variant": "secondary" }
      },
      "settings": { "paddingTop": "xl", "paddingBottom": "lg", "theme": "dark" }
    },
    {
      "id": "home-featured-projects",
      "type": "featured-projects",
      "data": {
        "label": "Selected work",
        "title": "Case studies in backend architecture and system design",
        "description": "A small set of projects where the technical problem was clear, the architectural trade-offs mattered, and the outcome was measurable.",
        "items": { "$ref": "../collections/projects/projects.json" }
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "home-blog-rollup",
      "type": "blog-rollup",
      "data": {
        "label": "Latest writing",
        "title": "Notes on content systems, type contracts, and AI tooling",
        "description": "Recent essays from the editorial side of the practice.",
        "items": { "$ref": "../collections/posts/posts.json" }
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "home-bio-panel",
      "type": "bio-panel",
      "data": {
        "label": "Short bio",
        "title": "Technical depth, editorial discipline, and a bias toward calm systems",
        "description": "I work at the intersection of architecture and explanation. My background spans backend platform design, data contracts, and internal developer tooling. I care about making systems easier to reason about, not only faster to ship.",
        "image": {
          "url": "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=900&q=80",
          "alt": "Portrait of a technical professional in a dark studio setting"
        },
        "note": "Based in Europe, working globally across product, platform, and editorial teams."
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "home-contact-cta",
      "type": "contact-cta",
      "data": {
        "label": "Contact",
        "title": "Need an architect who can also write the system down clearly?",
        "description": "I help teams design backend platforms, developer-facing infrastructure, and structured content systems that remain understandable after launch.",
        "primaryCta": { "id": "home-contact-cta-1", "label": "Contact Andrew", "href": "/contact", "variant": "primary" },
        "secondaryCta": { "id": "home-contact-cta-2", "label": "Read the blog", "href": "/blog", "variant": "secondary" }
      },
      "settings": { "theme": "accent" }
    }
  ]
}
EOF

cat > src/data/pages/about.json << 'EOF'
{
  "id": "about-page",
  "slug": "about",
  "meta": {
    "title": "About Andrew Linh — Architecture, Writing, and Systems Thinking",
    "description": "Learn about Andrew Linh’s professional path, technical stack, and design philosophy across backend systems, developer tooling, structured content, and AI-native infrastructure."
  },
  "sections": [
    {
      "id": "about-page-hero",
      "type": "page-hero",
      "data": {
        "label": "About",
        "title": "A systems architect who writes to make architecture legible",
        "description": "My work sits between implementation detail and organizational clarity: platform strategy, typed interfaces, infrastructure decisions, and the narratives teams need in order to operate them well."
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "about-bio-panel",
      "type": "bio-panel",
      "data": {
        "label": "Background",
        "title": "From backend delivery to platform-level system design",
        "description": "I began in application engineering, moved into data-heavy backend systems, and gradually specialized in the layer where product requirements meet platform constraints. Over time that expanded into technical writing: design docs, schema governance, internal documentation, and public essays about reliable systems.",
        "image": {
          "url": "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=900&q=80",
          "alt": "Close portrait of a thoughtful engineer seated near a window"
        },
        "note": "I prefer simple interfaces, explicit contracts, and infrastructure that explains itself."
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "about-timeline",
      "type": "timeline",
      "data": {
        "label": "Path",
        "title": "Professional trajectory",
        "items": [
          {
            "id": "timeline-1",
            "period": "2017–2019",
            "title": "Backend Engineer",
            "organization": "Product engineering teams",
            "body": "Built API services and operational tooling for SaaS products, with a focus on data integrity, deployment safety, and incident response."
          },
          {
            "id": "timeline-2",
            "period": "2019–2022",
            "title": "Senior Systems Engineer",
            "organization": "Platform and data organizations",
            "body": "Led architecture work around event pipelines, typed service boundaries, and warehouse-facing backend systems with multi-team dependencies."
          },
          {
            "id": "timeline-3",
            "period": "2022–2024",
            "title": "Staff Architect",
            "organization": "Developer platform initiatives",
            "body": "Designed internal tooling and contract layers that improved reliability, reduced duplicated infra work, and made system behavior easier to reason about."
          },
          {
            "id": "timeline-4",
            "period": "2024–Present",
            "title": "Independent Architect and Writer",
            "organization": "Consulting and editorial practice",
            "body": "Advising teams on backend architecture, structured content systems, AI-native tooling, and technical communication that survives implementation."
          }
        ]
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "about-skills-grid",
      "type": "skills-grid",
      "data": {
        "label": "Stack",
        "title": "Tools and systems I reach for often",
        "items": [
          {
            "id": "skill-1",
            "category": "Language",
            "label": "TypeScript",
            "icon": "braces",
            "body": "My default choice for end-to-end contracts across API design, content systems, and internal platforms."
          },
          {
            "id": "skill-2",
            "category": "Infrastructure",
            "label": "Distributed services",
            "icon": "server",
            "body": "Service boundaries, queue-backed workflows, event processing, and operationally legible runtime patterns."
          },
          {
            "id": "skill-3",
            "category": "Data",
            "label": "Relational and analytical stores",
            "icon": "database",
            "body": "PostgreSQL, warehouse query governance, lineage-aware data design, and schema lifecycle management."
          },
          {
            "id": "skill-4",
            "category": "AI systems",
            "label": "Agent tooling and policy layers",
            "icon": "cpu",
            "body": "Tool registries, execution envelopes, observability, and runtime controls for AI-native products."
          },
          {
            "id": "skill-5",
            "category": "Platform",
            "label": "Workflow orchestration",
            "icon": "workflow",
            "body": "Designing deterministic workflow surfaces that coordinate retries, approvals, and long-running jobs safely."
          }
        ]
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "about-philosophy",
      "type": "philosophy",
      "data": {
        "label": "Philosophy",
        "title": "How I think about architecture work",
        "description": "The goal is rarely maximal complexity. It is usually the smallest durable system that can explain itself.",
        "items": [
          {
            "id": "principle-1",
            "title": "Legibility is a feature",
            "body": "Systems should make it easy to understand ownership, active configuration, and the consequences of change. If only the original author can explain the architecture, the system is underdesigned."
          },
          {
            "id": "principle-2",
            "title": "Contracts beat conventions",
            "body": "Important boundaries deserve typed, reviewable contracts with runtime validation in the places trust actually breaks down."
          },
          {
            "id": "principle-3",
            "title": "Operational calm matters",
            "body": "A design that performs well on happy paths but generates confusing incidents is not complete. Failure modes must be boring and diagnosable."
          }
        ]
      },
      "settings": { "theme": "dark" }
    }
  ]
}
EOF

cat > src/data/pages/work.json << 'EOF'
{
  "id": "work-page",
  "slug": "work",
  "meta": {
    "title": "Work — Case Studies in Backend and Data Architecture",
    "description": "Browse detailed project case studies by Andrew Linh covering backend platforms, data systems, AI tooling, and developer experience architecture."
  },
  "sections": [
    {
      "id": "work-page-hero",
      "type": "page-hero",
      "data": {
        "label": "Work",
        "title": "Project case studies with context, trade-offs, and measurable outcomes",
        "description": "Each project page documents the technical problem, the architecture decision, the stack involved, and the concrete business or operational result."
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "work-featured-projects",
      "type": "featured-projects",
      "data": {
        "label": "Case studies",
        "title": "Recent architecture engagements",
        "description": "Representative projects across data platforms, AI infrastructure, and developer-facing backend systems.",
        "items": { "$ref": "../collections/projects/projects.json" }
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "work-bio-panel",
      "type": "bio-panel",
      "data": {
        "label": "Approach",
        "title": "I document the architecture, not only the implementation",
        "description": "Good case studies should show why a system changed, which trade-offs were accepted, and how the outcome was measured. That same discipline improves delivery work itself.",
        "image": {
          "url": "https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=900&q=80",
          "alt": "Laptop and notebook on a minimalist desk in a dark office"
        },
        "note": "Available for architecture reviews, design systems for internal platforms, and technical writing around complex software."
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "work-contact-cta",
      "type": "contact-cta",
      "data": {
        "label": "Discuss a project",
        "title": "Have a platform problem that needs both architecture and explanation?",
        "description": "I work best on systems that are already important to the business and need to become more reliable, more legible, or easier for multiple teams to evolve.",
        "primaryCta": { "id": "work-contact-cta-1", "label": "Book an intro call", "href": "/contact", "variant": "primary" },
        "secondaryCta": { "id": "work-contact-cta-2", "label": "Read the blog", "href": "/blog", "variant": "secondary" }
      },
      "settings": { "theme": "accent" }
    }
  ]
}
EOF

cat > src/data/pages/blog.json << 'EOF'
{
  "id": "blog-page",
  "slug": "blog",
  "meta": {
    "title": "Blog — Writing on Structured Systems and Developer Tooling",
    "description": "Read essays by Andrew Linh on schema-driven content, end-to-end type safety, AI agent tooling, developer experience, and practical backend architecture."
  },
  "sections": [
    {
      "id": "blog-page-hero",
      "type": "page-hero",
      "data": {
        "label": "Blog",
        "title": "Essays on structured systems, developer tooling, and architectural clarity",
        "description": "Writing here focuses on the contracts, runtime behaviors, and organizational choices that make software easier to build and operate."
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "blog-rollup-main",
      "type": "blog-rollup",
      "data": {
        "label": "All posts",
        "title": "Recent articles",
        "description": "Long-form notes drawn from consulting work, platform design, and technical editorial practice.",
        "items": { "$ref": "../collections/posts/posts.json" }
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "blog-philosophy-panel",
      "type": "philosophy",
      "data": {
        "label": "Editorial stance",
        "title": "What the blog tries to do",
        "description": "I prefer writing that turns architecture into practical decision-making rather than abstract inspiration.",
        "items": [
          {
            "id": "blog-principle-1",
            "title": "Specific over vague",
            "body": "Concrete examples, explicit trade-offs, and operational consequences matter more than broad best-practice slogans."
          },
          {
            "id": "blog-principle-2",
            "title": "Systems over tools",
            "body": "I care less about novelty than about how a tool changes ownership, failure modes, and maintenance burden."
          },
          {
            "id": "blog-principle-3",
            "title": "Writing as infrastructure",
            "body": "Good technical writing reduces ambiguity in exactly the same way good interfaces do."
          }
        ]
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "blog-contact-cta",
      "type": "contact-cta",
      "data": {
        "label": "Commissioned writing",
        "title": "Need a technical article, architecture memo, or internal platform narrative?",
        "description": "I also work with teams on developer-facing documentation, system explainers, and editorial framing for technically complex products.",
        "primaryCta": { "id": "blog-contact-cta-1", "label": "Get in touch", "href": "/contact", "variant": "primary" },
        "secondaryCta": { "id": "blog-contact-cta-2", "label": "See work", "href": "/work", "variant": "secondary" }
      },
      "settings": { "theme": "accent" }
    }
  ]
}
EOF

cat > src/data/pages/contact.json << 'EOF'
{
  "id": "contact-page",
  "slug": "contact",
  "meta": {
    "title": "Contact Andrew Linh — Consulting and Technical Writing",
    "description": "Contact Andrew Linh for consulting on backend architecture, structured data systems, AI-native tooling, developer platforms, or technical writing engagements."
  },
  "sections": [
    {
      "id": "contact-page-hero",
      "type": "page-hero",
      "data": {
        "label": "Contact",
        "title": "Let’s talk about architecture, tooling, or writing",
        "description": "If you are working on a backend platform, a structured content system, or internal tooling that needs sharper contracts and clearer operational behavior, I would be glad to hear more."
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "contact-form-section",
      "type": "contact-form",
      "data": {
        "label": "Reach out",
        "title": "Project inquiries and editorial work",
        "description": "Share the problem space, current team shape, and what success would look like. Short notes are fine.",
        "email": "hello@andrewlinh.dev",
        "formNote": "Typical topics: architecture reviews, platform strategy, structured content modeling, AI agent tooling, and technical writing retainers.",
        "links": [
          { "id": "contact-link-1", "label": "GitHub", "href": "https://github.com/andrewlinh", "icon": "github" },
          { "id": "contact-link-2", "label": "LinkedIn", "href": "https://www.linkedin.com/in/andrewlinh", "icon": "linkedin" },
          { "id": "contact-link-3", "label": "RSS", "href": "/blog/rss.xml", "icon": "rss" }
        ]
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "contact-bio-panel",
      "type": "bio-panel",
      "data": {
        "label": "Working style",
        "title": "Calm collaboration, explicit decisions, written follow-through",
        "description": "I like engagements where architecture is discussed in enough detail to make trade-offs visible. That often means short discovery conversations, a clear document trail, and simple communication rhythms.",
        "image": {
          "url": "https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&w=900&q=80",
          "alt": "Minimal meeting space with laptop and notebook on a table"
        },
        "note": "Remote-friendly, async-friendly, and comfortable working with product, platform, and leadership stakeholders."
      },
      "settings": { "theme": "dark" }
    },
    {
      "id": "contact-final-cta",
      "type": "contact-cta",
      "data": {
        "label": "Availability",
        "title": "Open to focused consulting engagements and writing commissions",
        "description": "The best fit is usually a well-scoped systems problem with real business stakes and a team that values technical clarity.",
        "primaryCta": { "id": "contact-final-cta-1", "label": "Email Andrew", "href": "mailto:hello@andrewlinh.dev", "variant": "primary" },
        "secondaryCta": { "id": "contact-final-cta-2", "label": "Browse case studies", "href": "/work", "variant": "secondary" }
      },
      "settings": { "theme": "accent" }
    }
  ]
}
EOF

cat > src/data/pages/projects-detail.json << 'EOF'
{
  "id": "projects-detail-page",
  "slug": "work/[slug]",
  "collection": { "source": "projects", "paramKey": "slug" },
  "meta": {
    "title": "Project case study detail page for Andrew Linh portfolio",
    "description": "Detailed case study page for Andrew Linh’s architecture portfolio, including context, technical problem, architectural decision, delivery stack, and measurable outcomes."
  },
  "sections": [
    {
      "id": "project-detail-section",
      "type": "project-detail",
      "data": { "item": { "$ref": "collection:current" } },
      "settings": { "theme": "dark" }
    }
  ]
}
EOF

cat > src/data/pages/posts-detail.json << 'EOF'
{
  "id": "posts-detail-page",
  "slug": "blog/[slug]",
  "collection": { "source": "posts", "paramKey": "slug" },
  "meta": {
    "title": "Article detail page for Andrew Linh technical writing",
    "description": "Long-form article detail page for Andrew Linh’s blog, with publication metadata, topic tags, related themes, and structured editorial content."
  },
  "sections": [
    {
      "id": "post-detail-section",
      "type": "post-detail",
      "data": { "item": { "$ref": "collection:current" } },
      "settings": { "theme": "dark" }
    }
  ]
}
EOF

echo "-- Patching src/App.tsx for icon and collection registries..."
if grep -q "JsonPagesEngine" src/App.tsx; then
  if ! grep -q "iconMap" src/App.tsx; then
    perl -0pi -e "s|(from ['\"][^'\"]*JsonPagesEngine[^'\"]*['\"];)|\$1\nimport { iconMap } from '@/lib/IconResolver';\nimport { CollectionRegistry } from '@/lib/CollectionRegistry';\nimport projectsData from '@/data/collections/projects/projects.json';\nimport postsData from '@/data/collections/posts/posts.json';|s" src/App.tsx
  fi
  if ! grep -q "iconRegistry: iconMap" src/App.tsx; then
    perl -0pi -e "s|(config=\{\{)|config={{\n        iconRegistry: iconMap,\n        collections: { projects: projectsData, posts: postsData },\n        collectionSchemas: CollectionRegistry,|s" src/App.tsx
  fi
else
  echo "Could not confidently locate JsonPagesEngine in src/App.tsx"
  exit 1
fi

echo "-- Running build..."
npm run build

echo "--------------------------------------------------"
echo "Spec compliance checklist:"
echo "[x] Step 0 shadcn init executed first"
echo "[x] index.html written"
echo "[x] src/index.css written with first-line Google Fonts import and [data-theme=\"light\"] override"
echo "[x] src/types.ts written"
echo "[x] src/lib/ComponentRegistry.tsx written"
echo "[x] src/lib/schemas.ts written"
echo "[x] src/lib/addSectionConfig.ts written"
echo "[x] 12 capsule directories written with schema.ts, types.ts, View.tsx, index.ts"
echo "[x] theme.json, site.json, menu.json written"
echo "[x] 5 core pages plus 2 dynamic detail pages written"
echo "[x] collections generated for projects and posts"
echo "[x] CollectionRegistry generated"
echo "[x] IconResolver generated and App.tsx patched"
echo "[x] npm run build completed"