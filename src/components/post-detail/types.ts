import { z } from 'zod';
import { BaseSectionSettingsSchema } from '@olonjs/core';
import { PostDetailSchema } from './schema';

export type PostDetailData = z.infer<typeof PostDetailSchema>;
export type PostDetailSettings = z.infer<typeof BaseSectionSettingsSchema>;

