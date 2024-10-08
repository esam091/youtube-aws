"use client";
import { Amplify } from "aws-amplify";
import { Authenticator } from "@aws-amplify/ui-react";
import '@aws-amplify/ui-react/styles.css';

Amplify.configure({
  Auth: {
    Cognito: {
      userPoolId: process.env.NEXT_PUBLIC_AWS_USER_POOL_ID!,
      userPoolClientId: process.env.NEXT_PUBLIC_AWS_USER_POOL_CLIENT_ID!,      
    },
  },
  Storage: {
    S3: {
      region: 'ap-southeast-1',
    }
  }
}, {ssr: true});

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>
        {children}
        {/* <Authenticator>
          {({ user, signOut }) => (
            <>
              <div>user id: {user?.userId}</div>
              <button onClick={signOut}>Sign out</button>
              {children}
            </>
          )}
        </Authenticator> */}
      </body>
    </html>
  );
}
