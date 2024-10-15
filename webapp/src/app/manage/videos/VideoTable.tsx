'use client';

import React, { useState } from 'react';
import { Table, TableHeader, TableBody, TableHead, TableRow, TableCell } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { useToast } from "@/hooks/use-toast";
import  deleteVideo  from './deleteVideo';

type Video = {
  id: string;
  title: string;
  description: string;
  status: 'processing' | 'done' | 'failed';
  createdAt: Date;
};

interface VideoTableProps {
  videos: Video[];
}

const getStatusColor = (status: string) => {
  switch (status) {
    case 'done':
      return 'secondary';
    case 'failed':
      return 'destructive';
    default:
      return 'default';
  }
};

export function VideoTable({ videos: initialVideos }: VideoTableProps) {
  const [videos, setVideos] = useState(initialVideos);
  const [deletingIds, setDeletingIds] = useState<Set<string>>(new Set());
  const { toast } = useToast();

  const handleDelete = async (videoId: string) => {
    setDeletingIds(prev => new Set(prev).add(videoId));
    try {
      await deleteVideo(videoId);
      setVideos(prevVideos => prevVideos.filter(v => v.id !== videoId));
      toast({
        title: "Video deleted",
        description: "The video has been successfully deleted.",
      });
    } catch (error) {
      console.error('Failed to delete video:', error);
      toast({
        title: "Error",
        description: "Failed to delete the video. Please try again.",
        variant: "destructive",
      });
    } finally {
      setDeletingIds(prev => {
        const newSet = new Set(prev);
        newSet.delete(videoId);
        return newSet;
      });
    }
  };

  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>Title</TableHead>
          <TableHead>Description</TableHead>
          <TableHead>Status</TableHead>
          <TableHead>Created At</TableHead>
          <TableHead>Action</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {videos.map((video) => (
          <TableRow key={video.id}>
            <TableCell>{video.title}</TableCell>
            <TableCell>{video.description}</TableCell>
            <TableCell>
              <Badge variant={getStatusColor(video.status)}>
                {video.status}
              </Badge>
            </TableCell>
            <TableCell>{video.createdAt.toLocaleString()}</TableCell>
            <TableCell>
              <AlertDialog>
                <AlertDialogTrigger asChild>
                  <Button variant="outline" disabled={deletingIds.has(video.id)}>
                    {deletingIds.has(video.id) ? 'Deleting...' : 'Delete'}
                  </Button>
                </AlertDialogTrigger>
                <AlertDialogContent>
                  <AlertDialogHeader>
                    <AlertDialogTitle>Are you absolutely sure?</AlertDialogTitle>
                    <AlertDialogDescription>
                      This action cannot be undone. This will permanently delete your
                      video and remove the data from our servers.
                    </AlertDialogDescription>
                  </AlertDialogHeader>
                  <AlertDialogFooter>
                    <AlertDialogCancel>Cancel</AlertDialogCancel>
                    <AlertDialogAction onClick={() => handleDelete(video.id)}>
                      Delete
                    </AlertDialogAction>
                  </AlertDialogFooter>
                </AlertDialogContent>
              </AlertDialog>
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  );
}
