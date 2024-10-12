import React from 'react';

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
    <ul>
      {videos.map((video) => (
        <li key={video.id}>
          <h2>{video.title}</h2>
          <p>{video.description}</p>
          <p>Created at: {new Date(video.createdAt).toLocaleString()}</p>
        </li>
      ))}
    </ul>
  );
};

export default VideoList;
