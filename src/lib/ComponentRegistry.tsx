import React from 'react';
import { Header } from '@/components/header';
import { Footer } from '@/components/footer';
import { EditorialHero } from '@/components/editorial-hero';
import { PageHero } from '@/components/page-hero';
import { FeaturedProjects } from '@/components/featured-projects';
import { BlogRollup } from '@/components/blog-rollup';
import { BioPanel } from '@/components/bio-panel';
import { ContactCta } from '@/components/contact-cta';
import { Timeline } from '@/components/timeline';
import { SkillsGrid } from '@/components/skills-grid';
import { Philosophy } from '@/components/philosophy';
import { ContactForm } from '@/components/contact-form';
import { ProjectDetail } from '@/components/project-detail';
import { PostDetail } from '@/components/post-detail';

import type { SectionType } from '@olonjs/core';
import type { SectionComponentPropsMap } from '@/types';

export const ComponentRegistry: {
  [K in SectionType]: React.FC<SectionComponentPropsMap[K]>;
} = {
  'header': Header,
  'footer': Footer,
  'editorial-hero': EditorialHero,
  'page-hero': PageHero,
  'featured-projects': FeaturedProjects,
  'blog-rollup': BlogRollup,
  'bio-panel': BioPanel,
  'contact-cta': ContactCta,
  'timeline': Timeline,
  'skills-grid': SkillsGrid,
  'philosophy': Philosophy,
  'contact-form': ContactForm,
  'project-detail': ProjectDetail,
  'post-detail': PostDetail
};

