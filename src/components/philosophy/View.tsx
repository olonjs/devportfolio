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
        <div className="mb-10 max-w-2xl">
          {data.label && (
            <div className="jp-section-label inline-flex items-center gap-2 text-[0.72rem] font-bold uppercase tracking-[0.12em] text-[var(--local-accent)] mb-4 pr-8" data-jp-field="label">
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

