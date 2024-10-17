"use client";

import { Amplify } from "aws-amplify";
import { useEffect } from "react";
import { cognitoUserPoolsTokenProvider } from "aws-amplify/auth/cognito";
import { CookieStorage } from "aws-amplify/utils";

export function AmplifyConfig() {
  useEffect(() => {
    Amplify.configure(
      {
        Auth: {
          Cognito: {
            userPoolId: process.env.NEXT_PUBLIC_AWS_USER_POOL_ID!,
            userPoolClientId: process.env.NEXT_PUBLIC_AWS_USER_POOL_CLIENT_ID!,
          },
        },
      },
      { ssr: true }
    );

    cognitoUserPoolsTokenProvider.setKeyValueStorage(
      new CookieStorage({
        secure: false, // not using https in deployed beanstalk
        domain: typeof window !== "undefined" ? window.location.hostname : "",
      })
    );
  }, []);

  return null;
}
