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
  const paddingTop = PADDING_TOP[settings?.paddingTop ?? 'sm'];
  const paddingBottom = PADDING_BOTTOM[settings?.paddingBottom ?? 'sm'];
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
            <div className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4 pr-8" data-jp-field="label">
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
                className="rounded-[var(--local-radius-md)] px-7 py-5 bg-[var(--local-primary)] text-[var(--local-primary-foreground)]"
              >
                <a href={data.primaryCta.href}><strong>{data.primaryCta.label}</strong></a>
              </Button>
            )}
            {data.secondaryCta && (
              <Button
                asChild
                variant="outline"
                className="rounded-[var(--local-radius-md)] px-7 py-5 border-[var(--local-border)] bg-transparent text-[var(--local-text)]"
              >
                <a href={data.secondaryCta.href}><strong>{data.secondaryCta.label}</strong></a>
              </Button>
            )}
          </div>
        </div>
      </div>
    </section>
  );
};

