import 'server-only';
import { cookies } from 'next/headers';
import { runWithAmplifyServerContext } from '@/amplifyServer';
import { getCurrentUser,  } from 'aws-amplify/auth/server';

export async function currentActiveUser() {
  return runWithAmplifyServerContext({
    nextServerContext: { cookies },
    operation: async (context) => {
      try {
        return await getCurrentUser(context);
      } catch {
        return null;
      }
    }
  });
}
