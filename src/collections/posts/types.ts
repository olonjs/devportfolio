import { z } from 'zod';
import { PostSchema, PostsCollectionSchema } from './schema';

export type Post = z.infer<typeof PostSchema>;
export type PostsCollection = z.infer<typeof PostsCollectionSchema>;

