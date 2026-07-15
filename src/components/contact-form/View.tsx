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
        <div className="grid gap-8 lg:grid-cols-[0.85fr_1.15fr]">
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

