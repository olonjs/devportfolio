import { HeaderSchema } from '@/components/header';
import { FooterSchema } from '@/components/footer';
import { EditorialHeroSchema } from '@/components/editorial-hero';
import { PageHeroSchema } from '@/components/page-hero';
import { FeaturedProjectsSchema } from '@/components/featured-projects';
import { BlogRollupSchema } from '@/components/blog-rollup';
import { BioPanelSchema } from '@/components/bio-panel';
import { ContactCtaSchema } from '@/components/contact-cta';
import { TimelineSchema } from '@/components/timeline';
import { SkillsGridSchema } from '@/components/skills-grid';
import { PhilosophySchema } from '@/components/philosophy';
import { ContactFormSchema } from '@/components/contact-form';
import { ProjectDetailSchema } from '@/components/project-detail';
import { PostDetailSchema } from '@/components/post-detail';

export const SECTION_SCHEMAS = {
  header: HeaderSchema,
  footer: FooterSchema,
  'editorial-hero': EditorialHeroSchema,
  'page-hero': PageHeroSchema,
  'featured-projects': FeaturedProjectsSchema,
  'blog-rollup': BlogRollupSchema,
  'bio-panel': BioPanelSchema,
  'contact-cta': ContactCtaSchema,
  timeline: TimelineSchema,
  'skills-grid': SkillsGridSchema,
  philosophy: PhilosophySchema,
  'contact-form': ContactFormSchema,
  'project-detail': ProjectDetailSchema,
  'post-detail': PostDetailSchema,
} as const;

export const SECTION_SUBMISSION_SCHEMAS = {} as const;

export type SectionType = keyof typeof SECTION_SCHEMAS;

export {
  BaseSectionData,
  BaseArrayItem,
  BaseSectionSettingsSchema,
  CtaSchema,
  ImageSelectionSchema,
} from '@olonjs/core';
