import React from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { Video } from '@/lib/video';

interface VideoListProps {
  videos: Video[];
  processedBucketDomain: string;
}

const formatDuration = (seconds: number): string => {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const remainingSeconds = seconds % 60;

  if (hours > 0) {
    return `${hours}:${minutes.toString().padStart(2, '0')}:${remainingSeconds.toString().padStart(2, '0')}`;
  } else {
    return `${minutes}:${remainingSeconds.toString().padStart(2, '0')}`;
  }
};

const VideoList: React.FC<VideoListProps> = ({ videos, processedBucketDomain }) => {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      {videos.map((video) => (
        <Link href={`/watch/${video.id}`} key={video.id} className="border rounded-lg overflow-hidden shadow-lg hover:shadow-xl transition-shadow duration-300">
          <div className="aspect-video relative">
            <Image
              src={`https://${processedBucketDomain}/${video.id}/${video.id}_thumbnail.0000000.jpg`}
              alt={video.title}
              layout="fill"
              objectFit="cover"
            />
            <div className="absolute bottom-2 right-2 bg-black bg-opacity-70 text-white text-sm px-2 py-1 rounded">
              {formatDuration(video.videoDuration)}
            </div>
          </div>
          <div className="p-4">
            <h3 className="text-xl font-semibold mb-2 truncate">{video.title}</h3>
            <p className="text-sm text-gray-500">
              Uploaded on: {new Date(video.createdAt).toLocaleDateString()}
            </p>
          </div>
        </Link>
      ))}
    </div>
  );
};

export default VideoList;
