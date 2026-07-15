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
        <div className="rounded-[var(--local-radius-lg)] border border-[var(--local-border)] bg-[var(--local-bg)] px-8 py-10">
          {data.label && (
            <div className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-text)] mb-4 pr-8" data-jp-field="label">
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

