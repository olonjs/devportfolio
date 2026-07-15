import type { HeaderData, HeaderSettings } from '@/components/header';
import type { FooterData, FooterSettings } from '@/components/footer';
import type { EditorialHeroData, EditorialHeroSettings } from '@/components/editorial-hero';
import type { PageHeroData, PageHeroSettings } from '@/components/page-hero';
import type { FeaturedProjectsData, FeaturedProjectsSettings } from '@/components/featured-projects';
import type { BlogRollupData, BlogRollupSettings } from '@/components/blog-rollup';
import type { BioPanelData, BioPanelSettings } from '@/components/bio-panel';
import type { ContactCtaData, ContactCtaSettings } from '@/components/contact-cta';
import type { TimelineData, TimelineSettings } from '@/components/timeline';
import type { SkillsGridData, SkillsGridSettings } from '@/components/skills-grid';
import type { PhilosophyData, PhilosophySettings } from '@/components/philosophy';
import type { ContactFormData, ContactFormSettings } from '@/components/contact-form';
import type { ProjectDetailData, ProjectDetailSettings } from '@/components/project-detail';
import type { PostDetailData, PostDetailSettings } from '@/components/post-detail';

export type SectionComponentPropsMap = {
  'header': { data: HeaderData; settings: HeaderSettings };
  'footer': { data: FooterData; settings: FooterSettings };
  'editorial-hero': { data: EditorialHeroData; settings: EditorialHeroSettings };
  'page-hero': { data: PageHeroData; settings: PageHeroSettings };
  'featured-projects': { data: FeaturedProjectsData; settings: FeaturedProjectsSettings };
  'blog-rollup': { data: BlogRollupData; settings: BlogRollupSettings };
  'bio-panel': { data: BioPanelData; settings: BioPanelSettings };
  'contact-cta': { data: ContactCtaData; settings: ContactCtaSettings };
  'timeline': { data: TimelineData; settings: TimelineSettings };
  'skills-grid': { data: SkillsGridData; settings: SkillsGridSettings };
  'philosophy': { data: PhilosophyData; settings: PhilosophySettings };
  'contact-form': { data: ContactFormData; settings: ContactFormSettings };
  'project-detail': { data: ProjectDetailData; settings: ProjectDetailSettings };
  'post-detail': { data: PostDetailData; settings: PostDetailSettings };
};

declare module '@olonjs/core' {
  export interface SectionDataRegistry {
    'header': HeaderData;
    'footer': FooterData;
    'editorial-hero': EditorialHeroData;
    'page-hero': PageHeroData;
    'featured-projects': FeaturedProjectsData;
    'blog-rollup': BlogRollupData;
    'bio-panel': BioPanelData;
    'contact-cta': ContactCtaData;
    'timeline': TimelineData;
    'skills-grid': SkillsGridData;
    'philosophy': PhilosophyData;
    'contact-form': ContactFormData;
    'project-detail': ProjectDetailData;
    'post-detail': PostDetailData;
  }
  export interface SectionSettingsRegistry {
    'header': HeaderSettings;
    'footer': FooterSettings;
    'editorial-hero': EditorialHeroSettings;
    'page-hero': PageHeroSettings;
    'featured-projects': FeaturedProjectsSettings;
    'blog-rollup': BlogRollupSettings;
    'bio-panel': BioPanelSettings;
    'contact-cta': ContactCtaSettings;
    'timeline': TimelineSettings;
    'skills-grid': SkillsGridSettings;
    'philosophy': PhilosophySettings;
    'contact-form': ContactFormSettings;
    'project-detail': ProjectDetailSettings;
    'post-detail': PostDetailSettings;
  }
}

export * from '@olonjs/core';

