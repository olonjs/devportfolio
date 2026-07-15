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
  const isAccentTheme = sectionTheme === 'accent';
  const t = isAccentTheme
    ? {
        bg: 'var(--accent)',
        text: 'var(--accent-foreground)',
        muted: 'var(--accent-foreground)',
        surface: 'var(--accent)',
        border: 'var(--border)'
      }
    : {
        bg: 'var(--background)',
        text: 'var(--foreground)',
        muted: 'var(--muted-foreground)',
        surface: 'var(--card)',
        border: 'var(--border)'
      };
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
              <div className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4 pr-8" data-jp-field="label">
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
            <a
              key={item.id || 'legacy-' + idx}
              href={'/work/' + item.slug}
              className={(idx === 0 ? 'md:col-span-2 ' : '') + 'group block'}
              data-jp-item-id={item.id || 'legacy-' + idx}
              data-jp-item-field="items"
            >
              <Card className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-surface)] text-[var(--local-text)] transition-colors group-hover:border-[var(--local-primary)]">
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
                </CardContent>
              </Card>
            </a>
          ))}
        </div>
      </div>
    </section>
  );
};

