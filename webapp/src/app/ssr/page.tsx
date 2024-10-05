import {cookies} from 'next/headers'
import { runWithAmplifyServerContext } from "@/amplifyServer";
import { getCurrentUser } from 'aws-amplify/auth/server';

export default async function Page() {
  const currentUser = await runWithAmplifyServerContext({
    nextServerContext: {cookies},
    operation: getCurrentUser
  })

  if (currentUser) {
    return <div>user id: {currentUser.userId}</div>
  }

  return <div>No user</div>
}