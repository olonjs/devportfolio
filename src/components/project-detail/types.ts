import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { ProjectDetailSchema } from './schema';

export type ProjectDetailData = z.infer<typeof ProjectDetailSchema>;
export type ProjectDetailSettings = z.infer<typeof BaseSectionSettingsSchema>;

