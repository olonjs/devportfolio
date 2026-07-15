import { z } from 'zod';
import { ProjectSchema, ProjectsCollectionSchema } from './schema';

export type Project = z.infer<typeof ProjectSchema>;
export type ProjectsCollection = z.infer<typeof ProjectsCollectionSchema>;

