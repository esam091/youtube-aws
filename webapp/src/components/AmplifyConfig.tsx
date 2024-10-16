'use client';

import { Amplify } from "aws-amplify";
import { useEffect } from "react";

export function AmplifyConfig() {
  useEffect(() => {
    Amplify.configure({
      Auth: {
        Cognito: {
          identityPoolId: 'asdfasdf',
          userPoolId: process.env.NEXT_PUBLIC_AWS_USER_POOL_ID!,
          userPoolClientId: process.env.NEXT_PUBLIC_AWS_USER_POOL_CLIENT_ID!, 
        },
      },
    }, {ssr: true});
  }, []);

  return null;
}
