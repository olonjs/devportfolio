import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { BlogRollupSchema } from './schema';

export type BlogRollupData = z.infer<typeof BlogRollupSchema>;
export type BlogRollupSettings = z.infer<typeof BaseSectionSettingsSchema>;

