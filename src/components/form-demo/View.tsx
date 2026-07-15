import * as Icons from 'lucide-react';
import { useFormState } from '@olonjs/core';
import type { CSSProperties, ComponentType } from 'react';
import type { FormDemoData } from './types';

type FormDemoViewProps = {
  data: FormDemoData;
};

const missingEnv =
  !import.meta.env.VITE_JSONPAGES_CLOUD_URL &&
  !import.meta.env.VITE_OLONJS_CLOUD_URL;

function getIconComponent(iconName?: string): ComponentType<{ className?: string; 'aria-hidden'?: boolean }> | null {
  if (!iconName) return null;

  const candidate = (Icons as Record<string, unknown>)[iconName];
  return typeof candidate === 'function'
    ? (candidate as ComponentType<{ className?: string; 'aria-hidden'?: boolean }>)
    : null;
}

function SetupGuide({ recipientEmail }: { recipientEmail?: string }) {
  const steps = [
    {
      done: !!recipientEmail,
      label: 'recipientEmail nel JSON della sezione',
      code: '"recipientEmail": "tu@esempio.it"',
    },
    {
      done: !missingEnv,
      label: 'VITE_JSONPAGES_CLOUD_URL nel file .env',
      code: 'VITE_JSONPAGES_CLOUD_URL=https://cloud.olonjs.io',
    },
    {
      done:
        !!import.meta.env.VITE_JSONPAGES_API_KEY ||
        !!import.meta.env.VITE_OLONJS_API_KEY,
      label: 'VITE_JSONPAGES_API_KEY nel file .env',
      code: 'VITE_JSONPAGES_API_KEY=sk-...',
    },
  ];

  const allDone = steps.every((s) => s.done);
  if (allDone) return null;

  return (
    <div className="space-y-3 rounded-lg border border-border bg-muted/40 p-4 text-sm">
      <p className="font-medium text-foreground">Quasi pronto — completa questi passaggi</p>
      <ol className="space-y-2">
        {steps.map((step, i) => (
          <li key={step.label} className="flex items-start gap-2">
            <span className={step.done ? 'text-green-500' : 'text-muted-foreground'}>
              {step.done ? '✓' : `${i + 1}.`}
            </span>
            <span className={step.done ? 'text-muted-foreground line-through' : 'text-foreground'}>
              {step.label}
              {!step.done && (
                <code className="mt-0.5 block rounded border border-border bg-background px-1.5 py-0.5 font-mono text-xs text-muted-foreground">
                  {step.code}
                </code>
              )}
            </span>
          </li>
        ))}
      </ol>
    </div>
  );
}

export function FormDemoView({ data }: FormDemoViewProps) {
  const formId = data.anchorId?.trim() || 'form-demo';
  const { status, message } = useFormState(formId);
  const IconComponent = getIconComponent(data.icon);

  const sectionStyle = {
    '--local-bg': 'var(--card)',
    '--local-text': 'var(--card-foreground, var(--foreground))',
    '--local-border': 'var(--border)',
    '--local-input-bg': 'var(--background)',
    '--local-input-text': 'var(--foreground)',
    '--local-accent': 'var(--primary)',
    '--local-accent-foreground': 'var(--primary-foreground)',
    '--local-radius': 'var(--radius)',
  } as CSSProperties;

  return (
    <main
      style={
        {
          '--local-page-bg': 'var(--background)',
          '--local-page-text': 'var(--foreground)',
        } as CSSProperties
      }
      className="flex min-h-screen items-center justify-center bg-[var(--local-page-bg)] px-6 text-[var(--local-page-text)]"
    >
      <section
        style={sectionStyle}
        className="w-full max-w-xl space-y-6 rounded-[var(--local-radius)] border border-[var(--local-border)] bg-[var(--local-bg)] p-8 shadow-sm"
      >
        {IconComponent && (
          <div data-jp-field="icon" className="mb-2 text-[var(--local-text)]">
            <IconComponent className="h-6 w-6" aria-hidden />
          </div>
        )}

        {(data.title || data.description) && (
          <div>
            {data.title && (
              <h1
                data-jp-field="title"
                className="text-2xl font-semibold tracking-tight text-[var(--local-text)]"
              >
                {data.title}
              </h1>
            )}
            {data.description && (
              <p data-jp-field="description" className="mt-3 text-sm text-muted-foreground">
                {data.description}
              </p>
            )}
          </div>
        )}

        <SetupGuide recipientEmail={data.recipientEmail} />

        <form id={formId} data-olon-recipient={data.recipientEmail ?? ''} className="space-y-4">
          <div>
            <label className="mb-1 block text-xs font-medium text-muted-foreground">Nome</label>
            <input
              name="name"
              type="text"
              required
              className="w-full rounded-[var(--local-radius)] border border-[var(--local-border)] bg-[var(--local-input-bg)] px-3 py-2 text-sm text-[var(--local-input-text)] focus:outline-none focus:ring-1 focus:ring-[var(--local-accent)]"
            />
          </div>

          <div>
            <label className="mb-1 block text-xs font-medium text-muted-foreground">Email</label>
            <input
              name="email"
              type="email"
              required
              className="w-full rounded-[var(--local-radius)] border border-[var(--local-border)] bg-[var(--local-input-bg)] px-3 py-2 text-sm text-[var(--local-input-text)] focus:outline-none focus:ring-1 focus:ring-[var(--local-accent)]"
            />
          </div>

          <div>
            <label className="mb-1 block text-xs font-medium text-muted-foreground">
              Messaggio
            </label>
            <textarea
              name="message"
              required
              rows={4}
              className="w-full resize-none rounded-[var(--local-radius)] border border-[var(--local-border)] bg-[var(--local-input-bg)] px-3 py-2 text-sm text-[var(--local-input-text)] focus:outline-none focus:ring-1 focus:ring-[var(--local-accent)]"
            />
          </div>

          {status === 'error' && <p className="text-xs text-destructive">{message}</p>}
          {status === 'success' && (
            <p className="text-xs text-green-600 dark:text-green-400">
              {data.successMessage || message}
            </p>
          )}

          <button
            type="submit"
            disabled={status === 'submitting'}
            className="w-full rounded-[var(--local-radius)] bg-[var(--local-accent)] px-4 py-2 text-sm font-medium text-[var(--local-accent-foreground)] transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
          >
            {status === 'submitting' ? 'Invio...' : data.submitLabel || 'Invia'}
          </button>
        </form>
      </section>
    </main>
  );
}
