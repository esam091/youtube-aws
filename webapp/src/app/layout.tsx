import { Amplify } from "aws-amplify";
import '@aws-amplify/ui-react/styles.css';
import './globals.css';
import { Toaster } from "@/components/ui/toaster";
import NavBar from "@/components/NavBar";

Amplify.configure({
  Auth: {
    Cognito: {
      userPoolId: process.env.NEXT_PUBLIC_AWS_USER_POOL_ID!,
      userPoolClientId: process.env.NEXT_PUBLIC_AWS_USER_POOL_CLIENT_ID!,      
    },
  },
  Storage: {
    S3: {
      region: process.env.NEXT_PUBLIC_AWS_REGION!,
    }
  }
}, {ssr: true});

export default async function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className="h-screen flex flex-col">
        <NavBar />
        <main className="flex-grow">
          {children}
        </main>
        <Toaster />
      </body>
    </html>
  );
}
