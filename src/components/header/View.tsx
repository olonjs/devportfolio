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
                    {item.isCta ? (
                      <Button
                        asChild
                        variant="ghost"
                        className="h-auto rounded-[var(--local-radius-md)] border-[var(--local-border)] bg-[var(--local-surface)] px-4 py-2 text-sm font-medium text-[var(--local-text)] hover:border-[var(--local-primary)]"
                      >
                        <a href={item.href}>{item.label}</a>
                      </Button>
                    ) : (
                      <NavigationMenuLink
                        href={item.href}
                        className="inline-flex rounded-[var(--local-radius-md)] px-4 py-2 text-sm font-medium text-[var(--local-text)] transition hover:bg-[var(--local-surface)]"
                      >
                        {item.label}
                      </NavigationMenuLink>
                    )}
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

