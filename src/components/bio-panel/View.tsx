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
              <div className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4 pr-8" data-jp-field="label">
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

