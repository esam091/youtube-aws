"use client";

import React from 'react';
import Video from './Video';

interface WatchPageClientProps {
  videoId: string;
  processedBucketDomain: string;
  videoData: {
    id: string;
    title: string;
    description: string;
  };
}

const WatchPageClient: React.FC<WatchPageClientProps> = ({ videoId, processedBucketDomain, videoData }) => {
  const videoUrl = `https://${processedBucketDomain}/${videoId}/${videoId}.m3u8`;

  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold mb-4">{videoData.title}</h1>
      <Video url={videoUrl} />
      <div className="mt-4">
        <h2 className="text-xl font-semibold mb-2">Description:</h2>
        <p className="text-gray-700">{videoData.description}</p>
      </div>
    </div>
  );
};

export default WatchPageClient;
