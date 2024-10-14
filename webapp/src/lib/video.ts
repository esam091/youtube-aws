import { z } from 'zod';

export const videoSchema = z.object({
  id: z.string(),
  title: z.string(),
  description: z.string(),
  createdAt: z.string(),
  videoDuration: z.number(),
  userId: z.string(),
});

export type Video = z.infer<typeof videoSchema>;
