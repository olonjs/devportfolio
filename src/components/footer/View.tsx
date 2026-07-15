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

