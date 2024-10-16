'use client';

import { Authenticator } from '@aws-amplify/ui-react';
import '@aws-amplify/ui-react/styles.css';
import { useRouter } from 'next/navigation';
import { useEffect } from 'react';
import { AuthEventData } from '@aws-amplify/ui';

type AuthComponentProps = {
  signOut?: (data?: AuthEventData) => void;
  user?: unknown; 
};

function AuthComponent({ user }: AuthComponentProps) {
  const router = useRouter();

  useEffect(() => {
    if (user) {
      router.push('/');
    }
  }, [user, router]);

  if (user) {
    return <div>Sign in successful, redirecting...</div>; 
  }

  return (
    null
  );
}

export default function Page() {
  return (
    <div className="flex justify-center items-center min-h-screen">
      <Authenticator initialState='signUp' loginMechanisms={['username', 'email']}>
        {(props) => <AuthComponent {...props} />}
      </Authenticator>
    </div>
  );
}