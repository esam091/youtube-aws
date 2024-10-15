"use client";

import React from 'react';
import Video from './Video';

interface WatchPageClientProps {
  videoId: string;
  processedBucketDomain: string;
}

const WatchPageClient: React.FC<WatchPageClientProps> = ({ videoId, processedBucketDomain }) => {
  const videoUrl = `https://${processedBucketDomain}/${videoId}/${videoId}.m3u8`;

  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold mb-4">Video: {videoId}</h1>
      <Video url={videoUrl} />
    </div>
  );
};

export default WatchPageClient;
