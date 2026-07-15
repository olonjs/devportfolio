import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { FeaturedProjectsSchema } from './schema';

export type FeaturedProjectsData = z.infer<typeof FeaturedProjectsSchema>;
export type FeaturedProjectsSettings = z.infer<typeof BaseSectionSettingsSchema>;

