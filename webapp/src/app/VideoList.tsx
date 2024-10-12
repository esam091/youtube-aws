import React from 'react';
import Link from 'next/link';

interface Video {
  id: string;
  title: string;
  description: string;
  createdAt: string;
}

interface VideoListProps {
  videos: Video[];
}

const VideoList: React.FC<VideoListProps> = ({ videos }) => {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      {videos.map((video) => (
        <div key={video.id} className="border rounded-lg overflow-hidden shadow-lg">
          <div className="p-4">
            <h3 className="text-xl font-semibold mb-2">{video.title}</h3>
            <p className="text-gray-600 mb-4">{video.description}</p>
            <p className="text-sm text-gray-500">
              Uploaded on: {new Date(video.createdAt).toLocaleDateString()}
            </p>
            <Link href={`/watch/${video.id}`} className="mt-4 inline-block bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded">
              Watch Video
            </Link>
          </div>
        </div>
      ))}
    </div>
  );
};

export default VideoList;
