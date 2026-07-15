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
  const item = data.item;
  if (!item || typeof item !== 'object' || Array.isArray(item) || !('title' in item) || !Array.isArray(item.stack)) {
    return null;
  }

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

