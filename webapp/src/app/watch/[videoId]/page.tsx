import WatchPageClient from "./WatchPageClient";

interface WatchPageProps {
  params: {
    videoId: string;
  };
}

export default function WatchPage({ params }: WatchPageProps) {
  const { videoId } = params;
  const processedBucketDomain = process.env.PROCESSED_BUCKET_DOMAIN;

  if (!processedBucketDomain) {
    throw new Error("PROCESSED_BUCKET_DOMAIN is not set");
  }

  return (
    <WatchPageClient
      videoId={videoId}
      processedBucketDomain={processedBucketDomain}
    />
  );
}
