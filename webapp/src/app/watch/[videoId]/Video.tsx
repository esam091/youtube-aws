import React, { useEffect, useRef, useState } from 'react';
import Hls from 'hls.js';
import { Play, Pause, Volume2, VolumeX, Settings, Loader } from 'lucide-react';

interface VideoProps {
  url: string;
}

const Video: React.FC<VideoProps> = ({ url }) => {
  const videoRef = useRef<HTMLVideoElement>(null);
  const hlsRef = useRef<Hls | null>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [isMuted, setIsMuted] = useState(false);
  const [currentBitrate, setCurrentBitrate] = useState(0);
  const [qualities, setQualities] = useState<{ bitrate: number; height: number; }[]>([]);
  const [showQualityMenu, setShowQualityMenu] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const lastPlaybackTimeRef = useRef(0);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;

    if (Hls.isSupported()) {
      const hls = new Hls();
      hlsRef.current = hls;
      hls.loadSource(url);
      hls.attachMedia(video);

      hls.on(Hls.Events.MANIFEST_PARSED, (event, data) => {
        console.log('HLS manifest loaded', data);
        setQualities(data.levels);
      });

      hls.on(Hls.Events.LEVEL_SWITCHED, (event, data) => {
        const bitrate = hls.levels[data.level].bitrate;
        console.log('Level switched', { level: data.level, bitrate });
        setCurrentBitrate(bitrate);
      });

      hls.on(Hls.Events.LEVEL_LOADING, () => {
        console.log('Level loading');
        setIsLoading(true);
        lastPlaybackTimeRef.current = video.currentTime;
      });

      hls.on(Hls.Events.LEVEL_LOADED, () => {
        console.log('Level loaded');
        setIsLoading(false);
        video.currentTime = lastPlaybackTimeRef.current;
        if (isPlaying) {
          video.play().catch(error => {
            console.error('Error playing video after level loaded:', error);
            setError('Failed to resume playback');
          });
        }
      });

      hls.on(Hls.Events.ERROR, (event, data) => {
        console.error('HLS error', data);
        if (data.fatal) {
          switch (data.type) {
            case Hls.ErrorTypes.NETWORK_ERROR:
              hls.startLoad();
              break;
            case Hls.ErrorTypes.MEDIA_ERROR:
              hls.recoverMediaError();
              break;
            default:
              hls.destroy();
              setError('Fatal error: ' + data.details);
              break;
          }
        }
      });
    } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
      video.src = url;
    }

    return () => {
      if (hlsRef.current) {
        hlsRef.current.destroy();
      }
    };
  }, [url]);

  const togglePlay = () => {
    const video = videoRef.current;
    if (!video) return;

    if (isPlaying) {
      video.pause();
    } else {
      video.play();
    }
    setIsPlaying(!isPlaying);
  };

  const toggleMute = () => {
    const video = videoRef.current;
    if (!video) return;

    video.muted = !video.muted;
    setIsMuted(!isMuted);
  };

  const changeQuality = (index: number) => {
    if (hlsRef.current) {
      const video = videoRef.current;
      if (video) {
        lastPlaybackTimeRef.current = video.currentTime;
        console.log('Changing quality', { index, currentTime: lastPlaybackTimeRef.current });
        hlsRef.current.currentLevel = index;
        
        // Force a reload of the current fragment
        hlsRef.current.loadLevel = index;
      }
    }
    setShowQualityMenu(false);
  };

  return (
    <div className="w-full max-w-3xl">
      <div className="relative">
        <video
          ref={videoRef}
          className="w-full rounded-lg shadow-lg"
          playsInline
          controls={false}
        />
        {isLoading && (
          <div className="absolute inset-0 flex items-center justify-center bg-black bg-opacity-50">
            <Loader className="animate-spin text-white" size={48} />
          </div>
        )}
        {error && (
          <div className="absolute inset-0 flex items-center justify-center bg-black bg-opacity-50">
            <p className="text-white text-lg">{error}</p>
          </div>
        )}
        <div className="absolute bottom-0 left-0 right-0 bg-black bg-opacity-50 p-4 flex items-center justify-between">
          <div className="flex items-center space-x-4">
            <button
              onClick={togglePlay}
              className="text-white hover:text-gray-300 focus:outline-none"
            >
              {isPlaying ? <Pause size={24} /> : <Play size={24} />}
            </button>
            <button
              onClick={toggleMute}
              className="text-white hover:text-gray-300 focus:outline-none"
            >
              {isMuted ? <VolumeX size={24} /> : <Volume2 size={24} />}
            </button>
          </div>
          <div className="flex items-center space-x-4">
            <span className="text-white text-sm">
              {(currentBitrate / 1000000).toFixed(2)} Mbps
            </span>
            <div className="relative">
              <button
                onClick={() => setShowQualityMenu(!showQualityMenu)}
                className="text-white hover:text-gray-300 focus:outline-none"
              >
                <Settings size={24} />
              </button>
              {showQualityMenu && (
                <div className="absolute bottom-full right-0 mb-2 bg-black bg-opacity-75 rounded-lg p-2">
                  {qualities.map((quality, index) => (
                    <button
                      key={index}
                      onClick={() => changeQuality(index)}
                      className="block w-full text-left text-white hover:bg-gray-700 px-2 py-1 rounded"
                    >
                      {quality.height}p ({(quality.bitrate / 1000000).toFixed(2)} Mbps)
                    </button>
                  ))}
                  <button
                    onClick={() => changeQuality(-1)}
                    className="block w-full text-left text-white hover:bg-gray-700 px-2 py-1 rounded"
                  >
                    Auto
                  </button>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Video;
