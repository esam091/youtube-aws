'use client';

import { useState } from 'react';
import { useForm } from 'react-hook-form';
import axios from 'axios';
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";
import { createSignedUrl } from './upload-utils';
import { useToast } from "@/hooks/use-toast";
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { submitUploadForm } from './submit';

const formSchema = z.object({
  title: z.string().min(1, 'Title is required').max(50, 'Title must be 50 characters or less'),
  description: z.string().min(1, 'Description is required').max(5000, 'Description must be 5000 characters or less'),
  videoFile: z.instanceof(FileList)
    .refine((files) => files.length === 1, 'Video is required')
    .refine(
      (files) => files[0] && files[0].type.startsWith('video/'),
      'File must be a video'
    )
});

type FormData = z.infer<typeof formSchema>;

export default function AddVideoPage() {
  const { register, handleSubmit, formState: { errors }, reset } = useForm<FormData>({
    resolver: zodResolver(formSchema)
  });
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [uploadProgress, setUploadProgress] = useState(0);
  const { toast } = useToast();

  const onSubmit = async (data: FormData) => {
    setIsSubmitting(true);
    setUploadProgress(0);

    try {
      const file = data.videoFile[0];
      const { url, fields, id } = await createSignedUrl();

      const formData = new FormData();
      Object.entries({ ...fields, file }).forEach(([key, value]) => {
        formData.append(key, value);
      });

      await axios.post(url, formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
        onUploadProgress: (progressEvent) => {
          const percentCompleted = Math.round((progressEvent.loaded * 100) / progressEvent.total!);
          setUploadProgress(percentCompleted);
        },
      });

      console.log('Upload successful');

      // Use submitUploadForm to save video metadata
      await submitUploadForm({
        title: data.title,
        description: data.description,
        id: id
      });

      toast({
        title: "Upload Successful",
        description: "Your video has been uploaded and saved successfully.",
        duration: 5000,
      });

      reset();

    } catch (error) {
      console.error('Error during upload or submission:', error);
      toast({
        title: "Upload Failed",
        description: "There was an error uploading or saving your video. Please try again.",
        variant: "destructive",
        duration: 5000,
      });
    } finally {
      setIsSubmitting(false);
      setUploadProgress(0);
    }
  };

  return (
    <div className="flex items-center justify-center min-h-screen">
      <Card className="w-full max-w-2xl">
        <CardHeader>
          <CardTitle>Add Video</CardTitle>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="title">Title</Label>
              <Input
                id="title"
                {...register('title')}
                disabled={isSubmitting}
              />
              {errors.title && <p className="text-sm text-destructive">{errors.title.message}</p>}
            </div>

            <div className="space-y-2">
              <Label htmlFor="description">Description</Label>
              <Textarea
                id="description"
                {...register('description')}
                rows={5}
                disabled={isSubmitting}
              />
              {errors.description && <p className="text-sm text-destructive">{errors.description.message}</p>}
            </div>

            <div className="space-y-2">
              <Label htmlFor="videoFile">Video File</Label>
              <Input
                id="videoFile"
                type="file"
                accept="video/*"
                {...register('videoFile')}
                disabled={isSubmitting}
              />
              {errors.videoFile && <p className="text-sm text-destructive">{errors.videoFile.message}</p>}
            </div>

            <Button type="submit" disabled={isSubmitting}>
              {isSubmitting ? 'Uploading...' : 'Submit'}
            </Button>

            {isSubmitting && (
              <div className="space-y-2">
                <Label>Upload Progress</Label>
                <Progress value={uploadProgress} className="w-full" />
              </div>
            )}
          </form>
        </CardContent>
      </Card>
    </div>
  );
}