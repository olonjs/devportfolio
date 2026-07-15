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

