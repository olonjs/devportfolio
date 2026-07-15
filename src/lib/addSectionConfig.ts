import type { AddSectionConfig } from '@olonjs/core';

const addableSectionTypes = [
  'editorial-hero',
  'page-hero',
  'featured-projects',
  'blog-rollup',
  'bio-panel',
  'contact-cta',
  'timeline',
  'skills-grid',
  'philosophy',
  'contact-form',
  'project-detail',
  'post-detail'
] as const;

const sectionTypeLabels: Record<string, string> = {
  'editorial-hero': 'Editorial Hero',
  'page-hero': 'Page Hero',
  'featured-projects': 'Featured Projects',
  'blog-rollup': 'Blog Rollup',
  'bio-panel': 'Bio Panel',
  'contact-cta': 'Contact CTA',
  'timeline': 'Timeline',
  'skills-grid': 'Skills Grid',
  'philosophy': 'Philosophy',
  'contact-form': 'Contact Form',
  'project-detail': 'Project Detail',
  'post-detail': 'Post Detail'
};

function getDefaultSectionData(type: string): Record<string, unknown> {
  switch (type) {
    case 'editorial-hero':
      return { title: 'Systems architecture with editorial clarity', description: 'I design backend platforms and write about structured data systems.', primaryCta: { id: 'cta-1', label: 'Get in touch', href: '/contact', variant: 'primary' } };
    case 'page-hero':
      return { title: 'Page title', description: 'Page introduction.' };
    case 'featured-projects':
      return { title: 'Selected work', items: {} };
    case 'blog-rollup':
      return { title: 'Latest writing', items: {} };
    case 'bio-panel':
      return { title: 'About Andrew', description: 'Short biography.' };
    case 'contact-cta':
      return { title: 'Start a conversation', description: 'Reach out for consulting or writing work.' };
    case 'timeline':
      return { title: 'Experience', items: [] };
    case 'skills-grid':
      return { title: 'Technical stack', items: [] };
    case 'philosophy':
      return { title: 'Design principles', items: [] };
    case 'contact-form':
      return { title: 'Contact', description: 'Send a note.', email: 'hello@andrewlinh.dev', links: [] };
    case 'project-detail':
      return {};
    case 'post-detail':
      return {};
    default:
      return {};
  }
}

export const addSectionConfig: AddSectionConfig = {
  addableSectionTypes: [...addableSectionTypes],
  sectionTypeLabels,
  getDefaultSectionData
};

