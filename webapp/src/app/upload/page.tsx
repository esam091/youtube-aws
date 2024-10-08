import Content from "./content";

export default function Page() {
  return (
    <div>
      <div>s3 url: {process.env.S3_BUCKET_NAME}</div>
      <Content />
    </div>
  );
}
